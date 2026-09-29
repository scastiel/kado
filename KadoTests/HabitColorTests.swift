import SwiftUI
import Testing
import UIKit
@testable import Kado
import KadoCore

/// The habit palette: eight slots whose bases come from a `HabitTheme`,
/// every tint derived from the base by mixing in Oklab over the page
/// ground. The derivation rules — gamut, ramp, contrast, identity — are
/// stated as invariants over **every theme × every slot** in both
/// colour schemes, so a new theme is covered the moment it is a case.
/// The rules that define Kadō's *look* (one lightness band, one chroma
/// band) are Kadō's alone.
@Suite("HabitColor palette")
struct HabitColorTests {

    private let schemes: [UIUserInterfaceStyle] = [.light, .dark]

    init() { ResolvedColor.warmUp() }

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

    @Test("Theme raw values are stable (stored in UserDefaults)")
    func themeRawValuesStable() {
        #expect(HabitTheme.kado.rawValue == "kado")
        #expect(HabitTheme.classic.rawValue == "classic")
        #expect(HabitTheme.muted.rawValue == "muted")
        #expect(HabitTheme.vivid.rawValue == "vivid")
        #expect(HabitTheme.autumn.rawValue == "autumn")
        #expect(HabitTheme.monochromeSage.rawValue == "monochromeSage")
    }

    /// Kadō and Classic are the free themes; everything else is the
    /// Supporter pack's, and falls back to Kadō without it.
    @Test("Only Kadō and Classic are free, and a locked theme renders as Kadō")
    func themeGating() {
        let free: Set<HabitTheme> = [.kado, .classic]
        #expect(HabitTheme.freeFallback == .kado)
        for theme in HabitTheme.allCases {
            #expect(theme.requiresSupporterPack == !free.contains(theme), "\(theme)")
            #expect(HabitTheme.effective(preferred: theme, isSupporter: true) == theme)
            #expect(
                HabitTheme.effective(preferred: theme, isSupporter: false) == (free.contains(theme) ? theme : .kado),
                "\(theme)"
            )
        }
    }

    // MARK: - Kadō's look

    /// "The five habits read at equal weight — no habit dominates."
    /// Perceptual lightness is what carries weight; the handoff lifts
    /// orange (and this palette, yellow) to 0.64 because at 0.58 they
    /// go brown, and asks dark mode for 0.68–0.72.
    @Test("Kadō's bases share a lightness band: 0.58…0.64 light, 0.68…0.72 dark")
    func matchedLightness() {
        for color in HabitColor.allCases {
            let base = color.base(in: .kado), dark = color.darkBase(in: .kado)
            #expect((0.58...0.64).contains(base.l), "\(color) light L \(base.l)")
            #expect((0.68...0.72).contains(dark.l), "\(color) dark L \(dark.l)")
            #expect(dark.c == base.c, "\(color) dark changes chroma")
            #expect(dark.h == base.h, "\(color) dark changes hue")
        }
    }

    @Test("Kadō's chroma stays in the handoff's 0.10…0.14 band")
    func matchedChroma() {
        for color in HabitColor.allCases {
            let c = color.base(in: .kado).c
            #expect((0.10...0.14).contains(c), "\(color) C \(c)")
        }
    }

    /// "Nothing changes visually for users who never open the picker":
    /// the glyph on a filled Kadō control is still the page itself.
    @Test("Kadō's glyph on a fill is the page colour for every slot")
    func kadoOnFillIsThePage() {
        for color in HabitColor.allCases {
            #expect(color.onFill(in: .kado) == .kadoBackground, "\(color)")
        }
    }

    // MARK: - Classic

    /// The frozen literals, resolved: iOS 26.5's `.systemRed` …
    /// `.systemPurple` in each scheme, as the probe printed them. Pins
    /// that the OKLCH literals round-trip to the system hue they were
    /// taken from, and that a later OS retuning its system colours
    /// doesn't move a theme someone chose for how it looked. Light
    /// yellow is the exception, nudged from the system's 255, 204, 0 so
    /// its ramp floor clears the not-due tile (`notDueIsQuietest`).
    @Test("Classic resolves to the pre-#89 system hues, light and dark")
    func classicIsTheSystemHues() {
        let expected: [HabitColor: (light: [Int], dark: [Int])] = [
            .red: ([255, 56, 60], [255, 66, 69]),
            .orange: ([255, 141, 40], [255, 146, 48]),
            .yellow: ([245, 196, 0], [255, 214, 0]),
            .green: ([52, 199, 89], [48, 209, 88]),
            .mint: ([0, 200, 179], [0, 218, 195]),
            .teal: ([0, 195, 208], [0, 210, 224]),
            .blue: ([0, 136, 255], [0, 145, 255]),
            .purple: ([203, 48, 224], [219, 52, 242]),
        ]
        for color in HabitColor.allCases {
            let rgb = expected[color]!
            #expect(bytes(color.color(in: .classic), .light) == rgb.light, "\(color) light")
            #expect(bytes(color.color(in: .classic), .dark) == rgb.dark, "\(color) dark")
        }
    }

    /// The page falls under 3:1 on the bright light-mode system hues,
    /// so those take the ink — and only those, and only in light mode.
    @Test("Classic's glyph on a fill is the ink only where the page can't read")
    func classicOnFillFallsBackToInk() {
        let dark: Set<HabitColor> = [.orange, .yellow, .green, .mint, .teal]
        for color in HabitColor.allCases {
            let onFill = srgb(color.onFill(in: .classic), .light)
            let expected = dark.contains(color) ? Color.kadoForeground : .kadoBackground
            #expect(onFill.isWithinOneStep(of: srgb(expected, .light)), "\(color) light")
            #expect(srgb(color.onFill(in: .classic), .dark).isWithinOneStep(of: srgb(.kadoBackground, .dark)), "\(color) dark")
        }
    }

    // MARK: - Every theme: the bases

    @Test("Every base is inside the sRGB gamut, light and dark", arguments: HabitTheme.allCases)
    func basesAreDisplayable(theme: HabitTheme) {
        for color in HabitColor.allCases {
            #expect(color.base(in: theme).oklab.isInSRGBGamut, "\(theme) \(color) light clips")
            #expect(color.darkBase(in: theme).oklab.isInSRGBGamut, "\(theme) \(color) dark clips")
        }
    }

    /// The ink is the base's hue at L 0.46 / 0.78, and for several
    /// hues sRGB cannot show the base's chroma there. It gives up
    /// chroma, never hue or lightness — clipping per channel would
    /// shift both.
    @Test("Ink is displayable at the base's hue and its own lightness", arguments: HabitTheme.allCases)
    func inkIsDisplayable(theme: HabitTheme) {
        for color in HabitColor.allCases {
            let pairs = [
                (color.ink(in: theme), color.base(in: theme), 0.46),
                (color.darkInk(in: theme), color.darkBase(in: theme), 0.78),
            ]
            for (ink, base, lightness) in pairs {
                #expect(ink.oklab.isInSRGBGamut, "\(theme) \(color) ink clips")
                #expect(ink.h == base.h, "\(theme) \(color) ink changes hue")
                #expect(ink.l == lightness, "\(theme) \(color) ink changes lightness")
                #expect(ink.c <= base.c && ink.c > 0.05, "\(theme) \(color) ink C \(ink.c)")
            }
        }
    }

    /// Only for themes spread around the hue wheel — Monochrome sage
    /// and Autumn cluster their hues by design and are held to
    /// `monochromeLadder` / `autumnFamilies` instead.
    @Test("Hues are spaced at least 15° apart", arguments: HabitTheme.allCases.filter(\.spansHueWheel))
    func hueSpacing(theme: HabitTheme) {
        for scheme in schemes {
            let hues = HabitColor.allCases.map {
                ($0, scheme == .light ? $0.base(in: theme).h : $0.darkBase(in: theme).h)
            }
            for (i, (a, ha)) in hues.enumerated() {
                for (b, hb) in hues[(i + 1)...] {
                    let delta = abs(ha - hb).truncatingRemainder(dividingBy: 360)
                    let distance = min(delta, 360 - delta)
                    #expect(distance >= 15, "\(theme) \(scheme): \(a) and \(b) are \(distance)° apart")
                }
            }
        }
    }

    /// Two habits sharing a look is the one real failure mode of a
    /// palette: hue spacing alone can't see it (two hues 15° apart at
    /// low chroma are closer than two 15° apart at high chroma) and
    /// can't see a monochrome palette at all. This measures what the
    /// eye does — Euclidean distance in Oklab, on the 8-bit colours
    /// that actually reach the screen.
    ///
    /// The floor sits under the closest pair Kadō has shipped since
    /// #89 — dark mint and teal, 0.029 apart — so it rejects anything
    /// tighter than what people already tell apart, and a JND-sized
    /// 0.02 would be too lenient for eight small dots in a row. Every
    /// paid palette clears it by a wide margin (Muted, the tightest,
    /// at 0.038).
    @Test("Every pair of slots is at least ΔE 0.025 apart in Oklab", arguments: HabitTheme.allCases)
    func minimumPairwiseDistance(theme: HabitTheme) {
        for scheme in schemes {
            let colors = HabitColor.allCases.map { ($0, oklab(color: $0, in: theme, scheme)) }
            for (i, (a, labA)) in colors.enumerated() {
                for (b, labB) in colors[(i + 1)...] {
                    let distance = labA.distance(to: labB)
                    #expect(distance >= 0.025, "\(theme) \(scheme): \(a) and \(b) are ΔE \(distance)")
                }
            }
        }
    }

    /// Monochrome sage's slots share the brand hue and are a lightness
    /// ladder instead: in slot order, darkest first, in both schemes,
    /// each rung a clear step above the last.
    @Test("Monochrome sage is one hue on an evenly spaced lightness ladder")
    func monochromeLadder() {
        for dark in [false, true] {
            let bases = HabitColor.allCases.map {
                dark ? $0.darkBase(in: .monochromeSage) : $0.base(in: .monochromeSage)
            }
            #expect(Set(bases.map(\.h)).count == 1, "dark: \(dark)")
            for (lower, upper) in zip(bases, bases.dropFirst()) {
                #expect(upper.l - lower.l >= 0.05, "dark: \(dark), \(lower.l) → \(upper.l)")
            }
        }
    }

    /// Autumn is oranges and greens and nothing else — the concept the
    /// maintainer asked for — four of each, so no later tuning drifts
    /// a slot into yellow, red or blue.
    @Test("Autumn is four oranges and four greens, in both schemes")
    func autumnFamilies() {
        let orange = 30.0...75.0, green = 115.0...165.0
        for dark in [false, true] {
            let hues = HabitColor.allCases.map {
                (dark ? $0.darkBase(in: .autumn) : $0.base(in: .autumn)).h
            }
            #expect(hues.filter(orange.contains).count == 4, "dark: \(dark), \(hues)")
            #expect(hues.filter(green.contains).count == 4, "dark: \(dark), \(hues)")
        }
    }

    // MARK: - Every theme: derivations

    @Test("tint(0) is the page and tint(1) is the base, in both schemes", arguments: HabitTheme.allCases)
    func tintEndpoints(theme: HabitTheme) {
        for color in HabitColor.allCases {
            for scheme in schemes {
                let page = srgb(Color.kadoBackground, scheme)
                let base = srgb(color.color(in: theme), scheme)
                #expect(srgb(color.tint(0, in: theme), scheme).isWithinOneStep(of: page), "\(theme) \(color) \(scheme) tint(0)")
                #expect(srgb(color.tint(1, in: theme), scheme).isWithinOneStep(of: base), "\(theme) \(color) \(scheme) tint(1)")
            }
        }
    }

    /// The Overview ramp is `0.2 + 0.8·value`; whatever the value, more
    /// of it must read as more of the hue. Lightness moves away from
    /// the page monotonically — down in light, up in dark.
    @Test("The ramp moves steadily away from the page", arguments: HabitTheme.allCases)
    func tintRampIsMonotonic(theme: HabitTheme) {
        let steps: [Double] = [0, 0.16, 0.2, 0.45, 0.7, 1]
        for color in HabitColor.allCases {
            for scheme in schemes {
                let lightness = steps.map { oklab(color.tint($0, in: theme), scheme).l }
                for (a, b) in zip(lightness, lightness.dropFirst()) {
                    if scheme == .light {
                        #expect(a > b, "\(theme) \(color) light ramp reverses: \(lightness)")
                    } else {
                        #expect(a < b, "\(theme) \(color) dark ramp reverses: \(lightness)")
                    }
                }
            }
        }
    }

    @Test("The named surfaces carry the handoff's amounts", arguments: HabitTheme.allCases)
    func namedSurfaces(theme: HabitTheme) {
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
                        srgb(color.tint(surface, in: theme), scheme)
                            .isWithinOneStep(of: srgb(color.tint(surface.amount, in: theme), scheme)),
                        "\(theme) \(color) \(surface) \(scheme)"
                    )
                }
            }
        }
    }

    /// Every derived colour is handed out from a table so two reads of
    /// the same one are the *same* `Color` — a dynamic colour compares
    /// by identity, and a matrix of cells hands SwiftUI one per render.
    /// The ramp is quantised to hundredths, and every named amount is
    /// a whole hundredth, so a surface and its amount are one entry.
    @Test("The same surface or ramp value is the same Color", arguments: HabitTheme.allCases)
    func derivedColorsAreStable(theme: HabitTheme) {
        for color in HabitColor.allCases {
            #expect(color.color(in: theme) == color.color(in: theme))
            #expect(color.onTint(in: theme) == color.onTint(in: theme))
            #expect(color.onFill(in: theme) == color.onFill(in: theme))
            for surface in HabitTint.allCases {
                #expect(color.tint(surface, in: theme) == color.tint(surface, in: theme))
                #expect(color.tint(surface, in: theme) == color.tint(surface.amount, in: theme))
            }
            #expect(color.tint(0.37, in: theme) == color.tint(0.37, in: theme))
            #expect(color.tint(0.371, in: theme) == color.tint(0.37, in: theme))
            #expect(color.tint(0.2 + 0.8 * 0.5, in: theme) == color.tint(0.6, in: theme))
        }
    }

    /// A never-due tile is the card paper inside a hairline ring; the
    /// ring tells it from a missed day, and this keeps it the quietest
    /// fill in the row — lighter than the ramp's floor in light mode,
    /// darker in dark — so an empty day never outweighs a missed one.
    @Test("The not-due fill is quieter than the ramp's floor", arguments: HabitTheme.allCases)
    func notDueIsQuietest(theme: HabitTheme) {
        for color in HabitColor.allCases {
            let floorLight = oklab(color.tint(.tileLight, in: theme), .light).l
            let floorDark = oklab(color.tint(.tileLight, in: theme), .dark).l
            #expect(oklab(Color.kadoBackgroundSecondary, .light).l > floorLight, "\(theme) \(color) light")
            #expect(oklab(Color.kadoBackgroundSecondary, .dark).l < floorDark, "\(theme) \(color) dark")
        }
    }

    // MARK: - Every theme: contrast

    /// The handoff's "Icon / text on tint" row: same H and C, L 0.42–0.50.
    @Test("Ink on a tint clears 4.5:1 on the mark, both schemes", arguments: HabitTheme.allCases)
    func inkOnTintContrast(theme: HabitTheme) {
        for color in HabitColor.allCases {
            for scheme in schemes {
                let ratio = srgb(color.onTint(in: theme), scheme)
                    .contrastRatio(with: srgb(color.tint(.mark, in: theme), scheme))
                #expect(ratio >= 4.5, "\(theme) \(color) \(scheme): \(ratio)")
            }
        }
    }

    /// Why the glyph on a filled control is the page colour rather
    /// than white: on the lifted dark bases white sits under 3:1. And
    /// why Classic's bright light-mode hues take the ink instead: the
    /// page sits under 3:1 on them too.
    @Test("The glyph on a filled control clears 3:1, both schemes", arguments: HabitTheme.allCases)
    func glyphOnFillContrast(theme: HabitTheme) {
        for color in HabitColor.allCases {
            for scheme in schemes {
                let ratio = srgb(color.onFill(in: theme), scheme)
                    .contrastRatio(with: srgb(color.color(in: theme), scheme))
                #expect(ratio >= 3, "\(theme) \(color) \(scheme): \(ratio)")
            }
        }
    }

    // MARK: - Helpers

    private func srgb(_ color: Color, _ scheme: UIUserInterfaceStyle) -> SRGB {
        let resolved = ResolvedColor.resolved(color, scheme)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
        return SRGB(red: r, green: g, blue: b)
    }

    private func bytes(_ color: Color, _ scheme: UIUserInterfaceStyle) -> [Int] {
        let c = srgb(color, scheme)
        return [c.red, c.green, c.blue].map { Int(($0 * 255).rounded()) }
    }

    private func oklab(_ color: Color, _ scheme: UIUserInterfaceStyle) -> Oklab {
        let c = srgb(color, scheme)
        return Oklab(srgbRed: c.red, green: c.green, blue: c.blue)
    }

    /// The slot's base as rendered — rounded to 8 bits per channel, as
    /// the display gets it — back in Oklab.
    private func oklab(color: HabitColor, in theme: HabitTheme, _ scheme: UIUserInterfaceStyle) -> Oklab {
        let c = srgb(color.color(in: theme), scheme)
        func byte(_ x: Double) -> Double { (x * 255).rounded() / 255 }
        return Oklab(srgbRed: byte(c.red), green: byte(c.green), blue: byte(c.blue))
    }
}

private extension Oklab {
    /// ΔE in Oklab: plain Euclidean distance, which the space is built
    /// to make perceptually uniform.
    func distance(to other: Oklab) -> Double {
        let dl = l - other.l, da = a - other.a, db = b - other.b
        return (dl * dl + da * da + db * db).squareRoot()
    }
}

private extension SRGB {
    func isWithinOneStep(of other: SRGB) -> Bool {
        abs(red - other.red) <= 1.01 / 255
            && abs(green - other.green) <= 1.01 / 255
            && abs(blue - other.blue) <= 1.01 / 255
    }
}
