import SwiftUI
import UIKit

/// One of eight habit colour *slots*. What a slot looks like is up to
/// the `HabitTheme` — every accessor that returns a colour takes one,
/// and views read it from `@Environment(\.habitTheme)` so a switch in
/// Settings redraws them.
///
/// Every habit-coloured surface derives from the theme's base for the
/// slot:
/// - `color(in:)` — the base, full. Filled controls, complete tiles,
///   the icon beside a habit's name.
/// - `tint(_:in:)` — the base mixed over the page ground in Oklab, by a
///   named `HabitTint` amount. Marks, chips, tiles, rings.
/// - `onTint(in:)` — text or a glyph *on* one of those tints: same hue,
///   darker (lighter in dark mode), chroma reduced only where sRGB
///   cannot show the base's at that lightness.
/// - `onFill(in:)` — text or a glyph on the filled base: the page
///   colour. Not white — on Kadō's lifted dark bases white sits under
///   3:1. Where even the page falls under 3:1 (Classic's bright light-
///   mode yellow, orange, green, mint and teal) it is the ink instead.
///
/// Every derived colour resolves per trait collection, and is mixed
/// over the dark ground in dark mode.
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

    /// The slot's light-mode base under `theme`.
    public func base(in theme: HabitTheme) -> OKLCH {
        theme.base(for: self)
    }

    /// The slot's dark-mode base under `theme`.
    public func darkBase(in theme: HabitTheme) -> OKLCH {
        theme.darkBase(for: self)
    }

    /// The light-mode ink for text on this slot's tints: L 0.46 at the
    /// base's hue, with chroma reduced only where sRGB cannot show the
    /// base's at that lightness.
    public func ink(in theme: HabitTheme) -> OKLCH {
        let base = base(in: theme)
        return OKLCH(l: Palette.lightInkLightness, c: base.c, h: base.h).fittedToSRGBGamut()
    }

    /// The dark-mode ink: L 0.78 at the dark base's hue, fitted the
    /// same way.
    public func darkInk(in theme: HabitTheme) -> OKLCH {
        let base = darkBase(in: theme)
        return OKLCH(l: Palette.darkInkLightness, c: base.c, h: base.h).fittedToSRGBGamut()
    }

    // MARK: - Derived colours

    /// The base, full.
    public func color(in theme: HabitTheme) -> Color {
        Palette.tables[theme]!.base[self]!
    }

    /// Text or a glyph on one of this slot's tints.
    public func onTint(in theme: HabitTheme) -> Color {
        Palette.tables[theme]!.onTint[self]!
    }

    /// Text or a glyph on the filled base.
    public func onFill(in theme: HabitTheme) -> Color {
        Palette.tables[theme]!.onFill[self]!
    }

    /// A named surface — the base at that surface's amount over the
    /// page, mixed in Oklab. Table-backed, so the same surface is the
    /// same `Color` every time it is read.
    public func tint(_ surface: HabitTint, in theme: HabitTheme) -> Color {
        tint(surface.amount, in: theme)
    }

    /// The base at an amount over the page, for ramps whose amount is
    /// data (`DayCell.colorOpacity`). Quantised to hundredths and read
    /// from a table resolved once, so a matrix of cells hands SwiftUI
    /// the same `Color` for the same value on every render instead of
    /// a fresh dynamic colour it can never compare equal.
    public func tint(_ amount: Double, in theme: HabitTheme) -> Color {
        Palette.tables[theme]!.ramp[self]![Palette.step(for: amount)]
    }

    // MARK: - Resolution

    /// Resolves every derived colour once, per theme. The ground and
    /// the ink are read back from `kadoBackground` / `kadoForeground`
    /// rather than restated here, so the palette cannot drift from the
    /// tokens it mixes over and falls back on.
    private enum Palette {
        static let lightInkLightness = 0.46
        static let darkInkLightness = 0.78

        /// The contrast the glyph on a filled control has to clear.
        static let minimumFillContrast = 3.0

        struct Tables {
            let base: [HabitColor: Color]
            let onTint: [HabitColor: Color]
            let onFill: [HabitColor: Color]
            let ramp: [HabitColor: [Color]]
        }

        static let tables: [HabitTheme: Tables] = Dictionary(
            uniqueKeysWithValues: HabitTheme.allCases.map { ($0, resolve($0)) }
        )

        static let ground = (
            light: oklab(of: .kadoBackground, in: .light),
            dark: oklab(of: .kadoBackground, in: .dark)
        )

        static let foreground = (
            light: oklab(of: .kadoForeground, in: .light),
            dark: oklab(of: .kadoForeground, in: .dark)
        )

        /// One entry per hundredth of the ramp. Every `HabitTint`
        /// amount is a whole hundredth, so the named surfaces are
        /// exact entries rather than nearest neighbours.
        static let steps = 100

        static func step(for amount: Double) -> Int {
            Int((max(0, min(1, amount)) * Double(steps)).rounded())
        }

        private static func resolve(_ theme: HabitTheme) -> Tables {
            Tables(
                base: table { color in
                    Color(light: color.base(in: theme).oklab.uiColor, dark: color.darkBase(in: theme).oklab.uiColor)
                },
                onTint: table { color in
                    Color(light: color.ink(in: theme).oklab.uiColor, dark: color.darkInk(in: theme).oklab.uiColor)
                },
                onFill: table { color in onFill(color, in: theme) },
                ramp: table { color in
                    (0...steps).map { mix(color, in: theme, amount: Double($0) / Double(steps)) }
                }
            )
        }

        /// The page colour, unless it falls under 3:1 on the base in
        /// that scheme — then whichever of page and ink reads better.
        /// Every Kadō base clears it with the page in both schemes, so
        /// Kadō gets `kadoBackground` itself, not a copy of it.
        private static func onFill(_ color: HabitColor, in theme: HabitTheme) -> Color {
            let light = pick(on: color.base(in: theme).oklab, ground: ground.light, ink: foreground.light)
            let dark = pick(on: color.darkBase(in: theme).oklab, ground: ground.dark, ink: foreground.dark)
            if light == ground.light && dark == ground.dark {
                return .kadoBackground
            }
            return Color(light: light.uiColor, dark: dark.uiColor)
        }

        private static func pick(on fill: Oklab, ground: Oklab, ink: Oklab) -> Oklab {
            let groundContrast = ground.srgb.contrastRatio(with: fill.srgb)
            guard groundContrast < minimumFillContrast else { return ground }
            return ink.srgb.contrastRatio(with: fill.srgb) > groundContrast ? ink : ground
        }

        private static func mix(_ color: HabitColor, in theme: HabitTheme, amount: Double) -> Color {
            Color(
                light: color.base(in: theme).oklab.mixed(over: ground.light, amount: amount).uiColor,
                dark: color.darkBase(in: theme).oklab.mixed(over: ground.dark, amount: amount).uiColor
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
