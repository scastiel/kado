import SwiftUI
import Testing
import UIKit
@testable import Kado
import KadoCore

/// The habit palette: eight hues authored in OKLCH at matched lightness
/// and chroma, every tint derived from the base by mixing in Oklab over
/// the page ground. The assertions are the design handoff's
/// verification list, stated as invariants over all eight hues in both
/// colour schemes rather than as examples in one.
@Suite("HabitColor palette")
struct HabitColorTests {

    private let schemes: [UIUserInterfaceStyle] = [.light, .dark]

    // MARK: - Shape

    @Test("Palette exposes eight distinct cases")
    func paletteSize() {
        #expect(HabitColor.allCases.count == 8)
        #expect(Set(HabitColor.allCases).count == 8)
    }

    @Test("Raw values match case names (stable for migration)")
    func rawValuesStable() {
        let expected: [(HabitColor, String)] = [
            (.red, "red"),
            (.orange, "orange"),
            (.yellow, "yellow"),
            (.green, "green"),
            (.mint, "mint"),
            (.teal, "teal"),
            (.blue, "blue"),
            (.purple, "purple"),
        ]
        for (value, raw) in expected {
            #expect(value.rawValue == raw)
        }
    }

    // MARK: - The bases

    @Test("Every base is inside the sRGB gamut, light and dark")
    func basesAreDisplayable() {
        for color in HabitColor.allCases {
            #expect(color.base.oklab.isInSRGBGamut, "\(color) light clips")
            #expect(color.darkBase.oklab.isInSRGBGamut, "\(color) dark clips")
        }
    }

    /// "The five habits read at equal weight — no habit dominates."
    /// Perceptual lightness is what carries weight; the handoff lifts
    /// orange (and this palette, yellow) to 0.64 because at 0.58 they
    /// go brown, and asks dark mode for 0.68–0.72.
    @Test("Bases share a lightness band: 0.58…0.64 light, 0.68…0.72 dark")
    func matchedLightness() {
        for color in HabitColor.allCases {
            #expect((0.58...0.64).contains(color.base.l), "\(color) light L \(color.base.l)")
            #expect((0.68...0.72).contains(color.darkBase.l), "\(color) dark L \(color.darkBase.l)")
            #expect(color.darkBase.c == color.base.c, "\(color) dark changes chroma")
            #expect(color.darkBase.h == color.base.h, "\(color) dark changes hue")
        }
    }

    @Test("Chroma stays in the handoff's 0.10…0.14 band")
    func matchedChroma() {
        for color in HabitColor.allCases {
            #expect((0.10...0.14).contains(color.base.c), "\(color) C \(color.base.c)")
        }
    }

    @Test("Hues are spaced at least 15° apart")
    func hueSpacing() {
        let hues = HabitColor.allCases.map { ($0, $0.base.h) }
        for (i, (a, ha)) in hues.enumerated() {
            for (b, hb) in hues[(i + 1)...] {
                let delta = abs(ha - hb).truncatingRemainder(dividingBy: 360)
                let distance = min(delta, 360 - delta)
                #expect(distance >= 15, "\(a) and \(b) are \(distance)° apart")
            }
        }
    }

    // MARK: - Derivations

    @Test("tint(0) is the page and tint(1) is the base, in both schemes")
    func tintEndpoints() {
        for color in HabitColor.allCases {
            for scheme in schemes {
                let page = srgb(Color.kadoBackground, scheme)
                #expect(srgb(color.tint(0), scheme).isWithinOneStep(of: page), "\(color) \(scheme) tint(0)")
                #expect(srgb(color.tint(1), scheme).isWithinOneStep(of: srgb(color.color, scheme)), "\(color) \(scheme) tint(1)")
            }
        }
    }

    /// The Overview ramp is `0.2 + 0.8·value`; whatever the value, more
    /// of it must read as more of the hue. Lightness moves away from
    /// the page monotonically — down in light, up in dark.
    @Test("The ramp moves steadily away from the page")
    func tintRampIsMonotonic() {
        let steps: [Double] = [0, 0.16, 0.2, 0.45, 0.7, 1]
        for color in HabitColor.allCases {
            for scheme in schemes {
                let lightness = steps.map { oklab(color.tint($0), scheme).l }
                for (a, b) in zip(lightness, lightness.dropFirst()) {
                    if scheme == .light {
                        #expect(a > b, "\(color) light ramp reverses: \(lightness)")
                    } else {
                        #expect(a < b, "\(color) dark ramp reverses: \(lightness)")
                    }
                }
            }
        }
    }

    @Test("The named surfaces carry the handoff's amounts")
    func namedSurfaces() {
        #expect(HabitTint.mark.amount == 0.16)
        #expect(HabitTint.timerPill.amount == 0.18)
        #expect(HabitTint.counterPill.amount == 0.14)
        #expect(HabitTint.slippedTag.amount == 0.20)
        #expect(HabitTint.outline.amount == 0.36)
        #expect(HabitTint.tilePartial.amount == 0.45)
        #expect(HabitTint.tileLight.amount == 0.20)
        for color in HabitColor.allCases {
            for surface in HabitTint.allCases {
                for scheme in schemes {
                    #expect(
                        srgb(color.tint(surface), scheme)
                            .isWithinOneStep(of: srgb(color.tint(surface.amount), scheme)),
                        "\(color) \(surface) \(scheme)"
                    )
                }
            }
        }
    }

    /// Named surfaces are handed out from a table so two reads of the
    /// same one are the *same* `Color` — a dynamic colour compares by
    /// identity, and views and tests both compare colours with `==`.
    @Test("The same surface is the same Color")
    func derivedColorsAreStable() {
        for color in HabitColor.allCases {
            #expect(color.color == color.color)
            #expect(color.onTint == color.onTint)
            for surface in HabitTint.allCases {
                #expect(color.tint(surface) == color.tint(surface))
            }
        }
    }

    // MARK: - Contrast

    /// The handoff's "Icon / text on tint" row: same H and C, L 0.42–0.50.
    @Test("Ink on a tint clears 4.5:1 on the mark, both schemes")
    func inkOnTintContrast() {
        for color in HabitColor.allCases {
            for scheme in schemes {
                let ratio = srgb(color.onTint, scheme).contrastRatio(with: srgb(color.tint(.mark), scheme))
                #expect(ratio >= 4.5, "\(color) \(scheme): \(ratio)")
            }
        }
    }

    /// Why the glyph on a filled control is the page colour rather
    /// than white: on the lifted dark bases white sits under 3:1.
    @Test("The glyph on a filled control clears 3:1, both schemes")
    func glyphOnFillContrast() {
        for color in HabitColor.allCases {
            for scheme in schemes {
                let ratio = srgb(color.onFill, scheme).contrastRatio(with: srgb(color.color, scheme))
                #expect(ratio >= 3, "\(color) \(scheme): \(ratio)")
            }
        }
    }

    // MARK: - Helpers

    private func srgb(_ color: Color, _ scheme: UIUserInterfaceStyle) -> SRGB {
        let resolved = UIColor(color)
            .resolvedColor(with: UITraitCollection(userInterfaceStyle: scheme))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
        return SRGB(red: r, green: g, blue: b)
    }

    private func oklab(_ color: Color, _ scheme: UIUserInterfaceStyle) -> Oklab {
        let c = srgb(color, scheme)
        return Oklab(srgbRed: c.red, green: c.green, blue: c.blue)
    }
}

private extension SRGB {
    func isWithinOneStep(of other: SRGB) -> Bool {
        abs(red - other.red) <= 1.01 / 255
            && abs(green - other.green) <= 1.01 / 255
            && abs(blue - other.blue) <= 1.01 / 255
    }
}
