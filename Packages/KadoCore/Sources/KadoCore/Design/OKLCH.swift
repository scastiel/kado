import Foundation

/// A color in OKLCH — perceptual lightness, chroma, hue.
///
/// The habit palette is declared in this space rather than in hex so
/// that every habit sits at the *same* perceived lightness and chroma
/// and only the hue changes. Full-chroma system colors (`.red`,
/// `.blue`, …) don't share a lightness at all: system yellow is far
/// lighter than system purple, so a row of habit marks drawn from them
/// reads as a set of unrelated intensities rather than one palette.
///
/// It also makes the design's derivations expressible as arithmetic
/// instead of a second table of hand-picked hexes. "Icon color is the
/// habit hue at L 0.46" is `base.lightness(0.46)`, and the dark-mode
/// lift is `base.lightness(0.72)` — same chroma, same hue, by
/// construction.
///
/// Conversion follows Björn Ottosson's published OKLab matrices.
/// Out-of-gamut results are clamped per channel after gamma encoding,
/// which is fine at the chroma levels this palette uses (≤ 0.14) but
/// would visibly distort a fully saturated hue.
nonisolated public struct OKLCH: Equatable, Sendable {
    /// Perceptual lightness, 0 (black) to 1 (white).
    public var lightness: Double
    /// Chroma. 0 is grey; this palette stays at 0.10–0.14.
    public var chroma: Double
    /// Hue angle in degrees.
    public var hue: Double

    public init(_ lightness: Double, _ chroma: Double, _ hue: Double) {
        self.lightness = lightness
        self.chroma = chroma
        self.hue = hue
    }

    /// The same hue and chroma at a different lightness — the one
    /// operation the palette's derivations need.
    public func lightness(_ newValue: Double) -> OKLCH {
        OKLCH(newValue, chroma, hue)
    }

    /// Gamma-encoded sRGB components in `0...1`.
    public var sRGB: (red: Double, green: Double, blue: Double) {
        let radians = hue * .pi / 180
        let a = chroma * cos(radians)
        let b = chroma * sin(radians)

        // OKLab -> LMS (cube roots), then cube back to linear LMS.
        let l = lightness + 0.3963377774 * a + 0.2158037573 * b
        let m = lightness - 0.1055613458 * a - 0.0638541728 * b
        let s = lightness - 0.0894841775 * a - 1.2914855480 * b

        let l3 = l * l * l
        let m3 = m * m * m
        let s3 = s * s * s

        // Linear LMS -> linear sRGB.
        let red = 4.0767416621 * l3 - 3.3077115913 * m3 + 0.2309699292 * s3
        let green = -1.2684380046 * l3 + 2.6097574011 * m3 - 0.3413193965 * s3
        let blue = -0.0041960863 * l3 - 0.7034186147 * m3 + 1.7076147010 * s3

        return (Self.encodeGamma(red), Self.encodeGamma(green), Self.encodeGamma(blue))
    }

    /// Linear-light channel to gamma-encoded sRGB, clamped to `0...1`.
    private static func encodeGamma(_ channel: Double) -> Double {
        let encoded = channel <= 0.0031308
            ? 12.92 * channel
            : 1.055 * pow(channel, 1 / 2.4) - 0.055
        return min(max(encoded, 0), 1)
    }
}
