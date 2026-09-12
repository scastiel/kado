import SwiftUI
import UIKit

/// A curated palette of habit colours, authored in OKLCH at matched
/// lightness and chroma so that eight habits read at the same weight —
/// system hues at "the same" brightness range from shouting to
/// vanishing, and read as a different app from the paper / ink / sage
/// brand they sit in.
///
/// Every habit-coloured surface derives from the base:
/// - `color` — the base, full. Filled controls, complete tiles, the
///   icon beside a habit's name.
/// - `tint(_:)` — the base mixed over the page ground in Oklab, by a
///   named `HabitTint` amount. Marks, chips, tiles, rings.
/// - `onTint` — text or a glyph *on* one of those tints: same hue and
///   chroma, darker (lighter in dark mode).
/// - `onFill` — text or a glyph on the filled base: the page colour.
///   Not white — on the lifted dark bases white sits under 3:1.
///
/// Dark mode raises L to 0.70 and keeps C and H, and mixes over the
/// dark ground; every derived colour resolves per trait collection.
///
/// Raw values are stable strings so the on-disk / CloudKit shape
/// survives enum reordering.
nonisolated public enum HabitColor: String, Codable, Sendable, Hashable, CaseIterable {
    case red
    case orange
    case yellow
    case green
    case mint
    case teal
    case blue
    case purple

    // MARK: - Authoring

    /// The hue's light-mode base. The five the design handoff specifies
    /// are verbatim, except teal's chroma: 0.11 is a hair outside sRGB
    /// at that hue and lightness, 0.105 is the last value inside it
    /// and renders one step apart. Yellow, green and mint are spaced
    /// between them at the same chroma; yellow is lifted to 0.64 the
    /// way the handoff lifts orange, because at 0.58 both go brown.
    public var base: OKLCH {
        switch self {
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

    /// The dark-mode base: L raised to 0.70, same C and H.
    public var darkBase: OKLCH {
        OKLCH(l: Palette.darkLightness, c: base.c, h: base.h)
    }

    // MARK: - Derived colours

    /// The base, full.
    public var color: Color { Palette.base[self]! }

    /// Text or a glyph on one of this hue's tints.
    public var onTint: Color { Palette.onTint[self]! }

    /// Text or a glyph on the filled base.
    public var onFill: Color { .kadoBackground }

    /// A named surface — the base at that surface's amount over the
    /// page, mixed in Oklab. Table-backed, so the same surface is the
    /// same `Color` every time it is read.
    public func tint(_ surface: HabitTint) -> Color {
        Palette.tints[self]![surface]!
    }

    /// The base at an arbitrary amount over the page, for ramps whose
    /// amount is data (`DayCell.colorOpacity`). Built on each call;
    /// prefer `tint(_ surface:)` for the fixed surfaces.
    public func tint(_ amount: Double) -> Color {
        Palette.mix(self, amount: amount)
    }

    // MARK: - Resolution

    /// Resolves every derived colour once. The ground is read back from
    /// `kadoPaper50` rather than restated here, so the palette cannot
    /// drift from the token it mixes over.
    private enum Palette {
        static let darkLightness = 0.70
        static let lightInkLightness = 0.46
        static let darkInkLightness = 0.78

        static let ground = (
            light: oklab(of: .kadoBackground, in: .light),
            dark: oklab(of: .kadoBackground, in: .dark)
        )

        static let base: [HabitColor: Color] = table { color in
            Color(light: color.base.oklab.uiColor, dark: color.darkBase.oklab.uiColor)
        }

        static let onTint: [HabitColor: Color] = table { color in
            let light = OKLCH(l: lightInkLightness, c: color.base.c, h: color.base.h)
            let dark = OKLCH(l: darkInkLightness, c: color.base.c, h: color.base.h)
            return Color(light: light.oklab.uiColor, dark: dark.oklab.uiColor)
        }

        static let tints: [HabitColor: [HabitTint: Color]] = table { color in
            Dictionary(uniqueKeysWithValues: HabitTint.allCases.map { surface in
                (surface, mix(color, amount: surface.amount))
            })
        }

        static func mix(_ color: HabitColor, amount: Double) -> Color {
            Color(
                light: color.base.oklab.mixed(over: ground.light, amount: amount).uiColor,
                dark: color.darkBase.oklab.mixed(over: ground.dark, amount: amount).uiColor
            )
        }

        private static func table<T>(_ make: (HabitColor) -> T) -> [HabitColor: T] {
            Dictionary(uniqueKeysWithValues: HabitColor.allCases.map { ($0, make($0)) })
        }

        private static func oklab(of color: Color, in style: UIUserInterfaceStyle) -> Oklab {
            let resolved = UIColor(color)
                .resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
            return Oklab(srgbRed: r, green: g, blue: b)
        }
    }
}
