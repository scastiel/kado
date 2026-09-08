import SwiftUI
import WidgetKit

/// Resolves the home widgets' colours against the current
/// `WidgetRenderingMode`.
///
/// In `.fullColor` the widgets paint themselves in the Kadō paper /
/// ink palette, exactly like the app. Under the Home Screen's Tinted
/// and Clear appearances WidgetKit switches to `.accented`: it drops
/// our `containerBackground` in favour of its own glass and re-tints
/// every *opaque* pixel with a single system colour, preserving only
/// alpha. Hue therefore stops carrying any information — paper and
/// ink flatten to the same tint, and a title with no fill of its own
/// disappears into the tile. Contrast has to come from alpha instead.
///
/// `.vibrant` (the Lock Screen, and a Home Screen widget in StandBy
/// night mode) is *approximated* by the same branch, not equal to it:
/// vibrant maps content into a grayscale material by **luminance**
/// rather than preserving alpha, so a very faint fill can map to
/// nothing at all. Nothing renders through this palette in vibrant
/// today — the lock-screen widgets roll their own colours — so the
/// approximation is untested against a real vibrant render. Re-check
/// these alphas before routing a lock-screen widget through here.
///
/// `WidgetRenderingMode` is not `Sendable`, so neither is this — it is
/// built inside a `body` and read straight away, never handed across
/// an actor.
public struct WidgetPalette {

    /// The mode the enclosing widget is being rendered in. Read it
    /// from `@Environment(\.widgetRenderingMode)`.
    public let renderingMode: WidgetRenderingMode

    public init(renderingMode: WidgetRenderingMode) {
        self.renderingMode = renderingMode
    }

    /// `true` when the system, not Kadō, chooses the colours.
    public var isTinted: Bool { renderingMode != .fullColor }

    // MARK: - Text

    /// Widget titles and habit names — the content that has to read
    /// first. Pair with `.widgetAccentable()` so the system puts it in
    /// the prominent group rather than the dimmed one.
    public var foreground: Color {
        isTinted ? .primary : .kadoForeground
    }

    /// Supporting text: the "3 / 8 done" counter, weekday letters,
    /// empty-state captions.
    ///
    /// Held only slightly back under the tint. Most of the hierarchy
    /// against `foreground` is already carried by the accent-group
    /// split, and non-accentable content is *itself* rendered in the
    /// dimmed group — so a heavy alpha here dims twice over and buries
    /// the very text it is meant to rank second. The remaining margin
    /// exists for the one place both colours land in the same group:
    /// the weekly widget's weekday stripe, where today's letter is
    /// told apart from the other six by alpha alone.
    public var foregroundSecondary: Color {
        isTinted ? .primary.opacity(0.75) : .kadoForegroundSecondary
    }

    /// The streak flame in the weekly widget's per-row metrics.
    ///
    /// Orange in full colour so a row reads the same as the app's
    /// `MetricsChip`, where the flame is deliberately off-palette —
    /// it means "streak" regardless of the habit's own accent. Under
    /// the tint that second hue buys nothing (every opaque pixel
    /// arrives the same colour), so it collapses onto the secondary
    /// text it sits beside and keeps the row to one weight.
    public var streakAccent: Color {
        isTinted ? foregroundSecondary : .orange
    }

    // MARK: - Fills

    /// The resting fill behind an untouched habit row in the small and
    /// medium widgets. Opaque paper in full colour; a wash under the
    /// tint that still reads as a pill behind its label.
    public var restingFill: Color {
        isTinted ? .primary.opacity(0.14) : .kadoHairline
    }

    /// The fill for a day the habit was never due, in the weekly
    /// matrix.
    ///
    /// Deliberately *not* `restingFill`, despite both being "the quiet
    /// one": `WidgetDayCell.colorOpacity` floors the scored ramp at
    /// 0.2, so a not-due day has to sit clearly under that or it
    /// becomes indistinguishable from a day that was scheduled and
    /// missed — the tint having erased the hue that told them apart in
    /// full colour.
    public var notDueFill: Color {
        isTinted ? .primary.opacity(0.08) : .kadoHairline
    }

    /// Fill for a habit row, given its status for today.
    ///
    /// Full colour keeps the habit's own hue. Under the tint the hue
    /// is gone, so the three states are separated by alpha alone —
    /// and every one of them stays well below the label above it.
    public func habitFill(
        _ color: HabitColor,
        status: WidgetStatus,
        progress: Double
    ) -> Color {
        let clamped = max(0, min(1, progress))
        guard isTinted else {
            switch status {
            case .complete: return color.color
            case .partial: return color.color.opacity(0.3 + clamped * 0.4)
            case .none: return restingFill
            }
        }
        switch status {
        case .complete: return .primary.opacity(0.4)
        case .partial: return .primary.opacity(0.2 + clamped * 0.15)
        case .none: return restingFill
        }
    }

    /// Colour for the icon and the trailing indicator, which sit on
    /// top of `habitFill`.
    ///
    /// In full colour they carry the habit's hue, knocked out to white
    /// once the row is complete and its fill is saturated.
    public func glyphColor(_ color: HabitColor, status: WidgetStatus) -> Color {
        guard isTinted else {
            return status == .complete ? .white : color.color
        }
        return .primary
    }

    /// Colour for the habit's *name*, which sits on the same fill but
    /// wants ink rather than the habit's hue while the row is
    /// incomplete — hence a second accessor rather than one shared
    /// with `glyphColor`.
    ///
    /// Under the tint both collapse to `.primary`: the white knockout
    /// would otherwise be re-tinted to exactly the colour of the block
    /// beneath it and the name would vanish. Contrast comes from
    /// `habitFill` staying translucent underneath.
    public func labelColor(_ color: HabitColor, status: WidgetStatus) -> Color {
        guard isTinted else {
            return status == .complete ? .white : .kadoForeground
        }
        return .primary
    }
}
