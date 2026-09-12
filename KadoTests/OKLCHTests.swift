import Testing
import UIKit
@testable import Kado
import KadoCore

/// The colour math the habit palette is authored in. Expected values
/// come from an independent reference implementation of Björn
/// Ottosson's published matrices (a Python script, not this code), so
/// a transcription slip in one matrix cell fails here rather than
/// shipping as a slightly wrong hue.
@Suite("OKLCH")
struct OKLCHTests {

    /// The page ground the tints are mixed over — `kadoPaper50`.
    private let pageLight = Oklab(srgbRed: 0.984, green: 0.973, blue: 0.949)
    private let pageDark = Oklab(srgbRed: 0.078, green: 0.075, blue: 0.059)

    // MARK: - OKLCH → sRGB

    @Test("The handoff's bases convert to the expected sRGB", arguments: [
        (OKLCH(l: 0.58, c: 0.14, h: 305), "#8E62BC"),   // purple
        (OKLCH(l: 0.58, c: 0.105, h: 180), "#018E7D"),  // teal
        (OKLCH(l: 0.60, c: 0.14, h: 30), "#C65B4C"),    // red
        (OKLCH(l: 0.58, c: 0.12, h: 250), "#3C7EBE"),   // blue
        (OKLCH(l: 0.64, c: 0.12, h: 65), "#BE7B32"),    // orange
        (OKLCH(l: 0.64, c: 0.12, h: 95), "#A38B23"),    // yellow
        (OKLCH(l: 0.70, c: 0.12, h: 95), "#B69D3A"),    // yellow, lifted further
        (OKLCH(l: 0.60, c: 0.12, h: 145), "#4D9351"),   // green
        (OKLCH(l: 0.60, c: 0.11, h: 165), "#2D9570"),   // mint
    ])
    func oklchToSRGB(input: OKLCH, expected: String) {
        #expect(input.oklab.srgb.isWithinOneStep(of: expected), "\(input.oklab.srgb.hex) != \(expected)")
    }

    @Test("Polar and rectangular forms agree")
    func oklchToOklab() {
        let purple = OKLCH(l: 0.58, c: 0.14, h: 305).oklab
        #expect(abs(purple.l - 0.58) < 1e-9)
        #expect(abs(purple.a - 0.08030) < 1e-4)
        #expect(abs(purple.b - -0.11468) < 1e-4)

        let back = purple.oklch
        #expect(abs(back.c - 0.14) < 1e-9)
        #expect(abs(back.h - 305) < 1e-6)
    }

    // MARK: - sRGB → Oklab

    @Test("sRGB decodes to the expected Oklab")
    func srgbToOklab() {
        let purple = Oklab(srgbRed: 0x8E / 255, green: 0x62 / 255, blue: 0xBC / 255)
        #expect(abs(purple.l - 0.58052) < 1e-3)
        #expect(abs(purple.a - 0.08021) < 1e-3)
        #expect(abs(purple.b - -0.11448) < 1e-3)

        let blue = Oklab(srgbRed: 0x3C / 255, green: 0x7E / 255, blue: 0xBE / 255)
        #expect(abs(blue.l - 0.57995) < 1e-3)
        #expect(abs(blue.a - -0.04087) < 1e-3)
        #expect(abs(blue.b - -0.11245) < 1e-3)
    }

    @Test("sRGB → Oklab → sRGB round-trips within one step", arguments: [
        "#8E62BC", "#018E7D", "#C65B4C", "#FBF8F2", "#14130F", "#FFFFFF", "#000000", "#7F7F7F",
    ])
    func roundTrip(hex: String) {
        let (r, g, b) = SRGB.channels(of: hex)
        let back = Oklab(srgbRed: r, green: g, blue: b).srgb
        #expect(back.isWithinOneStep(of: hex), "\(back.hex) != \(hex)")
    }

    // MARK: - Mixing

    @Test("Mixing at 0 is the ground and at 1 is the base")
    func mixEndpoints() {
        let base = OKLCH(l: 0.58, c: 0.14, h: 305).oklab
        #expect(base.mixed(over: pageLight, amount: 0) == pageLight)
        #expect(base.mixed(over: pageLight, amount: 1) == base)
    }

    /// The README's "X% over page" is `color-mix(in oklab, base X%,
    /// page)`; these are what that produces for the same inputs.
    @Test("Mixing over the page matches color-mix in Oklab", arguments: [
        (OKLCH(l: 0.58, c: 0.14, h: 305), 0.16, "#E9E0EB"),
        (OKLCH(l: 0.58, c: 0.14, h: 305), 0.45, "#C8B4DC"),
        (OKLCH(l: 0.60, c: 0.14, h: 30), 0.16, "#F5DFD6"),
        (OKLCH(l: 0.60, c: 0.14, h: 30), 0.45, "#E8B2A5"),
        (OKLCH(l: 0.58, c: 0.12, h: 250), 0.16, "#DCE4EB"),
        (OKLCH(l: 0.64, c: 0.12, h: 65), 0.45, "#E1C09F"),
    ])
    func mixOverLightPage(input: OKLCH, amount: Double, expected: String) {
        let mixed = input.oklab.mixed(over: pageLight, amount: amount).srgb
        #expect(mixed.isWithinOneStep(of: expected), "\(mixed.hex) != \(expected)")
    }

    @Test("Mixing over the dark ground", arguments: [
        (OKLCH(l: 0.70, c: 0.14, h: 305), "#29242C"),
        (OKLCH(l: 0.70, c: 0.14, h: 30), "#31221C"),
        (OKLCH(l: 0.70, c: 0.12, h: 250), "#20272C"),
    ])
    func mixOverDarkPage(input: OKLCH, expected: String) {
        let mixed = input.oklab.mixed(over: pageDark, amount: 0.16).srgb
        #expect(mixed.isWithinOneStep(of: expected), "\(mixed.hex) != \(expected)")
    }

    @Test("Mixing is clamped to 0...1")
    func mixIsClamped() {
        let base = OKLCH(l: 0.58, c: 0.14, h: 305).oklab
        #expect(base.mixed(over: pageLight, amount: -2) == pageLight)
        #expect(base.mixed(over: pageLight, amount: 7) == base)
    }

    // MARK: - Gamut

    @Test("Out-of-gamut colours clip per channel and say so")
    func gamutClipping() {
        let loud = OKLCH(l: 0.60, c: 0.30, h: 30).oklab
        #expect(loud.isInSRGBGamut == false)
        #expect(loud.srgb.isWithinOneStep(of: "#FF0000"), "\(loud.srgb.hex)")
        #expect(loud.srgb.red <= 1 && loud.srgb.green >= 0 && loud.srgb.blue >= 0)

        #expect(OKLCH(l: 0.58, c: 0.14, h: 305).oklab.isInSRGBGamut)
        #expect(OKLCH(l: 0.58, c: 0.105, h: 180).oklab.isInSRGBGamut)
        // The README's teal chroma is a hair outside — the reason the
        // palette uses 0.105.
        #expect(OKLCH(l: 0.58, c: 0.11, h: 180).oklab.isInSRGBGamut == false)
    }

    /// The slack is a quarter of an 8-bit step in the *encoded*
    /// channel, so it means the same near white as in the shadows.
    @Test("The gamut check measures its slack in encoded units")
    func gamutSlackIsEncoded() {
        #expect(Oklab(l: 1.0005, a: 0, b: 0).isInSRGBGamut)      // ≈ 0.17/255 over white
        #expect(Oklab(l: 1.003, a: 0, b: 0).isInSRGBGamut == false) // ≈ 0.95/255 over
    }

    @Test("Fitting to the gamut lowers chroma and keeps lightness and hue")
    func gamutFitting() {
        let teal = OKLCH(l: 0.58, c: 0.11, h: 180)
        let fitted = teal.fittedToSRGBGamut()
        #expect(fitted.oklab.isInSRGBGamut)
        #expect(fitted.l == teal.l)
        #expect(fitted.h == teal.h)
        #expect(fitted.c < teal.c && fitted.c > 0.10, "\(fitted.c)")

        let purple = OKLCH(l: 0.58, c: 0.14, h: 305)
        #expect(purple.fittedToSRGBGamut() == purple)
    }

    @Test("White and black are the ends of the L axis")
    func extremes() {
        #expect(Oklab(l: 1, a: 0, b: 0).srgb.isWithinOneStep(of: "#FFFFFF"))
        #expect(Oklab(l: 0, a: 0, b: 0).srgb.isWithinOneStep(of: "#000000"))
    }

    // MARK: - Contrast

    @Test("Contrast ratio follows WCAG")
    func contrast() {
        let white = SRGB(red: 1, green: 1, blue: 1)
        let black = SRGB(red: 0, green: 0, blue: 0)
        #expect(abs(white.contrastRatio(with: black) - 21) < 1e-9)
        #expect(abs(black.contrastRatio(with: white) - 21) < 1e-9)
        #expect(white.contrastRatio(with: white) == 1)
        // The paper secondary ink on the page: the number the handoff
        // is asking every text colour to clear.
        let (r, g, b) = SRGB.channels(of: "#605B51")
        let (pr, pg, pb) = SRGB.channels(of: "#FBF8F2")
        let ratio = SRGB(red: r, green: g, blue: b).contrastRatio(with: SRGB(red: pr, green: pg, blue: pb))
        #expect(abs(ratio - 6.36) < 0.01, "\(ratio)")
    }

    // MARK: - UIKit bridge

    @Test("The UIColor carries the same channels, opaque")
    func uiColorBridge() {
        let color = OKLCH(l: 0.58, c: 0.14, h: 305).oklab.uiColor
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        #expect(color.getRed(&r, green: &g, blue: &b, alpha: &a))
        #expect(a == 1)
        #expect(abs(r - 0x8E / 255) < 1.5 / 255)
        #expect(abs(g - 0x62 / 255) < 1.5 / 255)
        #expect(abs(b - 0xBC / 255) < 1.5 / 255)
    }
}

// MARK: - Helpers

private extension SRGB {
    static func channels(of hex: String) -> (Double, Double, Double) {
        let digits = Array(hex.dropFirst())
        func channel(_ i: Int) -> Double {
            Double(Int(String(digits[i..<i + 2]), radix: 16)!) / 255
        }
        return (channel(0), channel(2), channel(4))
    }

    /// Reference values are rounded to 8-bit; allow one step per
    /// channel for the rounding on either side.
    func isWithinOneStep(of hex: String) -> Bool {
        let (r, g, b) = Self.channels(of: hex)
        return abs(red - r) <= 1.01 / 255
            && abs(green - g) <= 1.01 / 255
            && abs(blue - b) <= 1.01 / 255
    }
}
