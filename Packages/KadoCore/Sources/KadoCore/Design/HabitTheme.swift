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
/// they stay stable strings.
nonisolated public enum HabitTheme: String, CaseIterable, Codable, Sendable, Hashable {
    /// The OKLCH palette at matched lightness and chroma (#89). The
    /// default.
    case kado
    /// Apple's system hues, as habits wore them before #89.
    case classic

    /// The slot's light-mode base.
    public func base(for color: HabitColor) -> OKLCH {
        switch self {
        case .kado: Self.kadoBase(color)
        case .classic: Self.classicBase(color).light
        }
    }

    /// The slot's dark-mode base. Kadō's is derived — L lifted to 0.70,
    /// same C and H. Classic's is authored, because the system's dark
    /// hues are not "the light one, lifted": each moves its own way.
    public func darkBase(for color: HabitColor) -> OKLCH {
        switch self {
        case .kado:
            let base = Self.kadoBase(color)
            return OKLCH(l: Self.kadoDarkLightness, c: base.c, h: base.h)
        case .classic:
            return Self.classicBase(color).dark
        }
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
}
