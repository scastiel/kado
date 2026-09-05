import SwiftUI
import UIKit

/// A curated palette of habit colors.
///
/// Raw values are stable strings so the on-disk / CloudKit shape
/// survives enum reordering — the case list and its raw values are
/// persistence surface and must not change. Everything *below* the
/// raw value is presentation and may be retuned freely.
///
/// The hues are declared in ``OKLCH`` rather than mapped onto Apple's
/// system colors. System hues don't share a lightness (system yellow
/// is far lighter than system purple) or a chroma, so a screen of
/// habit marks drawn from them reads as a set of unrelated intensities
/// fighting the warm-cream ground. Holding L and C fixed and varying
/// only the hue is what makes a Today card or an Overview grid read as
/// one palette.
nonisolated public enum HabitColor: String, Codable, Sendable, Hashable, CaseIterable {
    case red
    case orange
    case yellow
    case green
    case mint
    case teal
    case blue
    case purple

    /// Lightness every hue sits at in light mode. Low enough that a
    /// filled control can carry white, high enough that a 16% tint of
    /// it still reads as colored rather than grey.
    public static let baseLightness: Double = 0.59
    /// Dark-mode lift. The marks and tiles sit on a near-black ground,
    /// so the same L would sink into it.
    public static let darkLightness: Double = 0.70
    /// Icons and numerals drawn *on* a tinted fill, light mode.
    public static let inkLightness: Double = 0.46
    /// The same, dark mode — where the tinted fill is dark, so its
    /// foreground has to be lighter than the base rather than darker.
    public static let darkInkLightness: Double = 0.82

    /// Hue and chroma per case, at ``baseLightness``.
    ///
    /// Chroma varies slightly by hue because equal chroma does not
    /// read as equal saturation across the wheel — yellows and greens
    /// need less to feel as present as a purple.
    public var oklch: OKLCH {
        switch self {
        case .red:    OKLCH(Self.baseLightness, 0.14, 30)
        case .orange: OKLCH(Self.baseLightness, 0.12, 65)
        case .yellow: OKLCH(Self.baseLightness, 0.11, 95)
        case .green:  OKLCH(Self.baseLightness, 0.12, 145)
        case .mint:   OKLCH(Self.baseLightness, 0.10, 165)
        case .teal:   OKLCH(Self.baseLightness, 0.11, 195)
        case .blue:   OKLCH(Self.baseLightness, 0.12, 250)
        case .purple: OKLCH(Self.baseLightness, 0.14, 305)
        }
    }

    /// The habit's hue. Fills a completed control, tints every other
    /// surface via ``KadoTint``, and colors the Overview ramp.
    public var color: Color {
        Color(
            light: UIColor(oklch.lightness(Self.baseLightness)),
            dark: UIColor(oklch.lightness(Self.darkLightness))
        )
    }

    /// Foreground for anything sitting on a *tinted* fill of this hue
    /// — the icon in a habit mark, the `+5m` label, a counter's value,
    /// the `SLIPPED` tag's text. Darker than ``color`` in light mode
    /// and lighter in dark, because the tint it sits on moves the
    /// other way.
    ///
    /// Never use ``color`` for text on a tint: at 16% the fill barely
    /// shifts the ground, so a mid-lightness hue on it lands well
    /// under 4.5:1.
    public var ink: Color {
        Color(
            light: UIColor(oklch.lightness(Self.inkLightness)),
            dark: UIColor(oklch.lightness(Self.darkInkLightness))
        )
    }
}

private extension UIColor {
    /// Resolves an ``OKLCH`` to a concrete sRGB `UIColor`.
    convenience init(_ oklch: OKLCH) {
        let (red, green, blue) = oklch.sRGB
        self.init(red: red, green: green, blue: blue, alpha: 1)
    }
}
