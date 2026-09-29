import Foundation

/// What the eight habit colour *slots* look like. A habit stores its
/// slot (`HabitColor`), never a hue; the theme — one per device, chosen
/// in Settings → Habit colours — decides the hue that slot paints in.
/// Switching recolours every habit at once and switching back is
/// lossless, because nothing about a habit changed.
///
/// A theme supplies only the light and dark **bases**. Everything else
/// — the ink on a tint, the tints and ramps, the glyph on a fill —
/// derives from them by the same rules for every theme
/// (`HabitColor`), so a theme cannot ship a surface the palette tests
/// haven't swept. It touches habit hues only: the paper / ink / sage
/// brand is the same under every theme.
///
/// Raw values are stored in `UserDefaults` (`HabitThemeDefaults`), so
/// they stay stable strings. What is stored is the user's *pick*;
/// what renders is `HabitTheme.effective(preferred:isSupporter:)`,
/// since every theme after Classic needs the Supporter pack.
nonisolated public enum HabitTheme: String, CaseIterable, Codable, Sendable, Hashable {
    /// The OKLCH palette at matched lightness and chroma (#89). The
    /// default.
    case kado
    /// Apple's system hues, as habits wore them before #89.
    case classic
    /// Kadō's lightness at half its chroma: ink wash. Supporter pack.
    case muted
    /// As much chroma as sRGB shows at each hue. Supporter pack.
    case vivid
    /// An autumn set — brick to plum. Supporter pack.
    case autumn
    /// One hue, the brand sage, told apart by lightness alone.
    /// Supporter pack.
    case monochromeSage

    /// The slot's light-mode base.
    public func base(for color: HabitColor) -> OKLCH {
        switch self {
        case .kado: Self.kadoBase(color)
        case .classic: Self.classicBase(color).light
        case .muted: Self.mutedBase(color)
        case .vivid: Self.vividBase(color).light
        case .autumn: Self.autumnBase(color).light
        case .monochromeSage: Self.monochromeSageBase(color, darkMode: false)
        }
    }

    /// The slot's dark-mode base. Kadō's and Muted's are derived — L
    /// lifted to 0.70 / 0.72, same C and H. The others are authored,
    /// because their light bases don't share a lightness to lift from.
    public func darkBase(for color: HabitColor) -> OKLCH {
        switch self {
        case .kado:
            let base = Self.kadoBase(color)
            return OKLCH(l: Self.kadoDarkLightness, c: base.c, h: base.h)
        case .classic:
            return Self.classicBase(color).dark
        case .muted:
            let base = Self.mutedBase(color)
            return OKLCH(l: Self.mutedDarkLightness, c: base.c, h: base.h)
        case .vivid:
            return Self.vividBase(color).dark
        case .autumn:
            return Self.autumnBase(color).dark
        case .monochromeSage:
            return Self.monochromeSageBase(color, darkMode: true)
        }
    }

    /// Whether the slots are told apart by hue. Monochrome sage is
    /// the one that isn't: its slots share a hue and differ by
    /// lightness, so the palette tests hold it to a lightness spacing
    /// instead of a hue spacing. Both are held to the same minimum
    /// Oklab distance.
    public var variesHue: Bool {
        self != .monochromeSage
    }

    // MARK: - Kadō

    static let kadoDarkLightness = 0.70

    /// The five hues the design handoff specifies are verbatim, except
    /// teal's chroma: 0.11 is a hair outside sRGB at that hue and
    /// lightness, 0.105 is the last value inside it and renders one
    /// step apart. Yellow, green and mint are spaced between them at
    /// the same chroma; yellow is lifted to 0.64 the way the handoff
    /// lifts orange, because at 0.58 both go brown.
    private static func kadoBase(_ color: HabitColor) -> OKLCH {
        switch color {
        case .red: OKLCH(l: 0.60, c: 0.14, h: 30)
        case .orange: OKLCH(l: 0.64, c: 0.12, h: 65)
        case .yellow: OKLCH(l: 0.64, c: 0.12, h: 95)
        case .green: OKLCH(l: 0.60, c: 0.12, h: 145)
        case .mint: OKLCH(l: 0.60, c: 0.11, h: 165)
        case .teal: OKLCH(l: 0.58, c: 0.105, h: 180)
        case .blue: OKLCH(l: 0.58, c: 0.12, h: 250)
        case .purple: OKLCH(l: 0.58, c: 0.14, h: 305)
        }
    }

    // MARK: - Classic

    /// UIKit's `.systemRed` … `.systemPurple` — what SwiftUI's `.red` …
    /// `.purple` resolved to before #89 — resolved in light and dark
    /// trait collections on iOS 26.5 and converted with
    /// `Oklab(srgbRed:green:blue:)`. Pasted output, not hand-computed,
    /// and frozen: a later OS retuning its system hues must not
    /// silently recolour a theme people picked for how it looked.
    /// Light yellow alone is nudged darker; see its entry.
    private static func classicBase(_ color: HabitColor) -> (light: OKLCH, dark: OKLCH) {
        switch color {
        case .red: (
            OKLCH(l: 0.6531973986515769, c: 0.23282108612297542, h: 25.73935138034414),
            OKLCH(l: 0.6620019592038325, c: 0.22459912042373134, h: 25.12233350405593)
        )
        case .orange: (
            OKLCH(l: 0.7533236525787629, c: 0.17195497352805073, h: 55.71895688676479),
            OKLCH(l: 0.761877833719579, c: 0.16699704429087966, h: 57.05211726610055)
        )
        case .yellow: (
            // The one departure: the system's light yellow is L 0.865,
            // so pale that its 20% ramp floor (a scheduled day with
            // nothing logged) lands lighter than the never-due tile and
            // a missed day reads as quieter than an empty one. 0.84 is
            // the lightest in whole hundredths that clears it. The hue
            // is the system's; the chroma is as much of the system's
            // as sRGB can show that much darker, the same fit the ink
            // takes.
            OKLCH(l: 0.84, c: 0.17682824048983725, h: 90.38155627342546).fittedToSRGBGamut(),
            OKLCH(l: 0.8847945900161382, c: 0.1816422637411277, h: 94.89715977153321)
        )
        case .green: (
            OKLCH(l: 0.7303242236822335, c: 0.19438085964996174, h: 147.44394305128816),
            OKLCH(l: 0.7555507906392209, c: 0.20824556254649432, h: 146.98358844908066)
        )
        case .mint: (
            OKLCH(l: 0.7470904848146559, c: 0.13401288875837142, h: 181.7731042841568),
            OKLCH(l: 0.7968760324422136, c: 0.1430533509806484, h: 181.6471850008415)
        )
        case .teal: (
            OKLCH(l: 0.7446360513932833, c: 0.12684904077205886, h: 203.30322820513152),
            OKLCH(l: 0.7871119180043308, c: 0.1340911502965891, h: 203.34393713415704)
        )
        case .blue: (
            OKLCH(l: 0.6320535731799914, c: 0.2017874155540712, h: 254.08790274034567),
            OKLCH(l: 0.6514711897692063, c: 0.19197222832569907, h: 251.4695985140168)
        )
        case .purple: (
            OKLCH(l: 0.6215707975337017, c: 0.2629355343400136, h: 322.5056820788143),
            OKLCH(l: 0.6578824066618576, c: 0.2791333924588945, h: 322.41176757045)
        )
        }
    }

    // MARK: - Muted

    static let mutedDarkLightness = 0.72

    /// Ink wash: Kadō's lightness band at C 0.065, about half its
    /// chroma. Halving chroma halves how far apart two hues sit, so
    /// the hues are re-spaced more evenly than Kadō's — no two closer
    /// than 35°, where Kadō's mint and teal are 15° apart — or the
    /// greens would merge. 0.065 is about as low as it goes: the ink
    /// keeps the base's chroma and has to stay a tint of the hue, not
    /// a grey. Dark lifts to 0.72, a hair above Kadō's 0.70, because
    /// low-chroma hues read darker than their L at the same lightness.
    private static func mutedBase(_ color: HabitColor) -> OKLCH {
        switch color {
        case .red: OKLCH(l: 0.60, c: 0.065, h: 25)
        case .orange: OKLCH(l: 0.63, c: 0.065, h: 60)
        case .yellow: OKLCH(l: 0.64, c: 0.065, h: 95)
        case .green: OKLCH(l: 0.60, c: 0.065, h: 135)
        case .mint: OKLCH(l: 0.60, c: 0.065, h: 170)
        case .teal: OKLCH(l: 0.58, c: 0.065, h: 205)
        case .blue: OKLCH(l: 0.58, c: 0.065, h: 250)
        case .purple: OKLCH(l: 0.58, c: 0.065, h: 310)
        }
    }

    // MARK: - Vivid

    /// Each hue at close to the most chroma sRGB can show, capped at
    /// 0.22. Unlike Kadō, lightness is not matched: sRGB's loudest
    /// yellow, orange and greens only exist well above Kadō's 0.60,
    /// so each hue sits where its chroma peaks — yellow at 0.80 —
    /// and the glyph on those fills falls back to the ink. Dark lifts
    /// the rest to 0.72 and trims chroma back inside the gamut there.
    /// Chroma values are rounded *down* from the gamut edge so the
    /// literals stay displayable.
    private static func vividBase(_ color: HabitColor) -> (light: OKLCH, dark: OKLCH) {
        switch color {
        case .red: (OKLCH(l: 0.62, c: 0.22, h: 28), OKLCH(l: 0.72, c: 0.17, h: 28))
        case .orange: (OKLCH(l: 0.70, c: 0.16, h: 60), OKLCH(l: 0.72, c: 0.165, h: 60))
        case .yellow: (OKLCH(l: 0.80, c: 0.16, h: 95), OKLCH(l: 0.80, c: 0.16, h: 95))
        case .green: (OKLCH(l: 0.68, c: 0.21, h: 145), OKLCH(l: 0.72, c: 0.22, h: 145))
        case .mint: (OKLCH(l: 0.70, c: 0.135, h: 170), OKLCH(l: 0.72, c: 0.14, h: 170))
        case .teal: (OKLCH(l: 0.66, c: 0.11, h: 205), OKLCH(l: 0.72, c: 0.12, h: 205))
        case .blue: (OKLCH(l: 0.58, c: 0.19, h: 255), OKLCH(l: 0.72, c: 0.145, h: 255))
        case .purple: (OKLCH(l: 0.58, c: 0.22, h: 310), OKLCH(l: 0.72, c: 0.195, h: 310))
        }
    }

    // MARK: - Autumn

    /// Brick, pumpkin, mustard, olive, moss, spruce, dusk and plum —
    /// each slot keeps its name's family, so a habit picked as "blue"
    /// is still the blue one. The warm half carries the chroma and the
    /// cool half is deliberately quiet (C 0.07–0.08), the way a
    /// landscape in October is; lightness steps between neighbours so
    /// the quiet ones still stand apart. Dark lifts each by 0.14,
    /// never below 0.70, at the same C and H — mustard ends at 0.88,
    /// the lightest base anywhere in the palette.
    private static func autumnBase(_ color: HabitColor) -> (light: OKLCH, dark: OKLCH) {
        switch color {
        case .red: (OKLCH(l: 0.55, c: 0.13, h: 30), OKLCH(l: 0.70, c: 0.13, h: 30))
        case .orange: (OKLCH(l: 0.66, c: 0.14, h: 55), OKLCH(l: 0.80, c: 0.13, h: 55))
        case .yellow: (OKLCH(l: 0.74, c: 0.13, h: 88), OKLCH(l: 0.88, c: 0.13, h: 88))
        case .green: (OKLCH(l: 0.60, c: 0.11, h: 118), OKLCH(l: 0.74, c: 0.11, h: 118))
        case .mint: (OKLCH(l: 0.52, c: 0.08, h: 150), OKLCH(l: 0.70, c: 0.08, h: 150))
        case .teal: (OKLCH(l: 0.50, c: 0.07, h: 200), OKLCH(l: 0.70, c: 0.07, h: 200))
        case .blue: (OKLCH(l: 0.52, c: 0.07, h: 250), OKLCH(l: 0.70, c: 0.07, h: 250))
        case .purple: (OKLCH(l: 0.48, c: 0.10, h: 345), OKLCH(l: 0.70, c: 0.10, h: 345))
        }
    }

    // MARK: - Monochrome sage

    /// The brand sage (H 158, the hue of `kadoSage`) at C 0.065 — a
    /// touch above the sage's own 0.054 so the lightest steps still
    /// read as green rather than grey — in eight lightness steps 0.06
    /// apart, darkest first in slot order. 0.06 in L is twice the
    /// closest pair Kadō ships (0.029 in Oklab), so every slot is told
    /// apart by lightness alone.
    ///
    /// The ends are set by the palette's own rules, not by taste. In
    /// light mode the lightest (0.78) is as pale as a base gets while
    /// its 20% ramp floor still sits below the never-due tile; seven
    /// 0.06 steps down from there, the darkest (0.36) is still a deep
    /// green next to the near-black text, not another black.
    /// Dark mode runs 0.48…0.90 — its darkest must clear the dark
    /// never-due tile the same way — and keeps the order, so the slot
    /// that was darkest is still the darkest.
    private static func monochromeSageBase(_ color: HabitColor, darkMode: Bool) -> OKLCH {
        let index = Double(HabitColor.allCases.firstIndex(of: color)!)
        let lightness = (darkMode ? 0.48 : 0.36) + index * 0.06
        return OKLCH(l: lightness, c: 0.065, h: 158)
    }
}

// MARK: - Supporter pack

/// Kadō and Classic are free; every other theme needs the Supporter
/// pack. Without it a paid pick renders as Kadō — the stored choice is
/// kept, so it comes back the moment the pack does.
extension HabitTheme: SupporterGated {
    public var requiresSupporterPack: Bool {
        switch self {
        case .kado, .classic: false
        case .muted, .vivid, .autumn, .monochromeSage: true
        }
    }

    public static let freeFallback = HabitTheme.kado
}
