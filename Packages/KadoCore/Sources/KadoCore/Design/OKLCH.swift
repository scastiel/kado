import Foundation
import SwiftUI
import UIKit

/// A colour in OKLCH — the polar form of Oklab, and the space the habit
/// palette is authored in. `l` is perceptual lightness (0…1), `c`
/// chroma (0 at grey, ~0.4 at the loudest displayable), `h` hue in
/// degrees.
///
/// The palette is defined here rather than in sRGB because equal `l`
/// and `c` across hues is what makes eight habits read at the same
/// weight: system hues at "the same" sRGB brightness range from
/// shouting to vanishing. Tints are then derived by mixing in Oklab
/// (`Oklab.mixed(over:amount:)`), which is what CSS `color-mix(in
/// oklab, …)` does and what the design handoff specifies; mixing with
/// `Color.opacity` composites in gamma-encoded sRGB and muddies the
/// mid tints.
nonisolated public struct OKLCH: Hashable, Sendable {
    public var l: Double
    public var c: Double
    public var h: Double

    public init(l: Double, c: Double, h: Double) {
        self.l = l
        self.c = c
        self.h = h
    }

    public var oklab: Oklab {
        let radians = h * .pi / 180
        return Oklab(l: l, a: c * cos(radians), b: c * sin(radians))
    }
}

/// Oklab — Björn Ottosson's perceptual space. Rectangular, so mixing
/// is a plain lerp on the three components.
nonisolated public struct Oklab: Hashable, Sendable {
    public var l: Double
    public var a: Double
    public var b: Double

    public init(l: Double, a: Double, b: Double) {
        self.l = l
        self.a = a
        self.b = b
    }

    /// From gamma-encoded sRGB channels in 0…1 — the numbers in a hex
    /// colour or in `UIColor(red:green:blue:alpha:)`.
    public init(srgbRed red: Double, green: Double, blue: Double) {
        let r = Self.linear(red), g = Self.linear(green), bl = Self.linear(blue)
        let l = cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * bl)
        let m = cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * bl)
        let s = cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * bl)
        self.init(
            l: 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
            a: 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
            b: 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
        )
    }

    public var oklch: OKLCH {
        var degrees = atan2(b, a) * 180 / .pi
        if degrees < 0 { degrees += 360 }
        return OKLCH(l: l, c: (a * a + b * b).squareRoot(), h: degrees)
    }

    /// `amount` of this colour over `ground` — the handoff's "base at
    /// 16% over page" is `base.mixed(over: page, amount: 0.16)`.
    /// Clamped so an out-of-range ramp value can't leave the segment.
    public func mixed(over ground: Oklab, amount: Double) -> Oklab {
        let t = max(0, min(1, amount))
        return Oklab(
            l: l * t + ground.l * (1 - t),
            a: a * t + ground.a * (1 - t),
            b: b * t + ground.b * (1 - t)
        )
    }

    // MARK: - sRGB

    /// Linear-light sRGB, unclipped. Negative or >1 channels mean the
    /// colour is outside the display gamut.
    private var linearSRGB: (r: Double, g: Double, b: Double) {
        let l_ = l + 0.3963377774 * a + 0.2158037573 * b
        let m_ = l - 0.1055613458 * a - 0.0638541728 * b
        let s_ = l - 0.0894841775 * a - 1.2914855480 * b
        let l3 = l_ * l_ * l_, m3 = m_ * m_ * m_, s3 = s_ * s_ * s_
        return (
            r: +4.0767416621 * l3 - 3.3077115913 * m3 + 0.2309699292 * s3,
            g: -1.2684380046 * l3 + 2.6097574011 * m3 - 0.3413193965 * s3,
            b: -0.0041960863 * l3 - 0.7034186147 * m3 + 1.7076147010 * s3
        )
    }

    /// `true` when every channel lands inside 0…1 (to within a
    /// quarter of an 8-bit step). A palette entry that fails this
    /// renders clipped — still a colour, but not the one that was
    /// authored.
    public var isInSRGBGamut: Bool {
        let (r, g, b) = linearSRGB
        let slack = 0.25 / 255
        return [r, g, b].allSatisfy { $0 >= -slack && $0 <= 1 + slack }
    }

    /// Gamma-encoded sRGB, each channel clipped to 0…1. Clipping is
    /// per channel — the same thing `color-mix` does for a result it
    /// cannot display — so keep authored colours inside the gamut
    /// (`isInSRGBGamut`) and let this only ever trim rounding.
    public var srgb: SRGB {
        let (r, g, b) = linearSRGB
        return SRGB(red: Self.encoded(r), green: Self.encoded(g), blue: Self.encoded(b))
    }

    /// Opaque `UIColor` in the sRGB colour space.
    public var uiColor: UIColor {
        let c = srgb
        return UIColor(red: c.red, green: c.green, blue: c.blue, alpha: 1)
    }

    private static func linear(_ c: Double) -> Double {
        c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }

    private static func encoded(_ c: Double) -> Double {
        let clipped = max(0, min(1, c))
        return clipped <= 0.0031308 ? 12.92 * clipped : 1.055 * pow(clipped, 1 / 2.4) - 0.055
    }
}

/// Gamma-encoded sRGB channels in 0…1, as they appear in a hex colour.
nonisolated public struct SRGB: Hashable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// `#RRGGBB`, for debugging and test output.
    public var hex: String {
        func byte(_ c: Double) -> Int { Int((max(0, min(1, c)) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", byte(red), byte(green), byte(blue))
    }
}
