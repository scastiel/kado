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
/// `.vibrant` (the Lock Screen) behaves the same way for our purposes:
/// desaturated, alpha-driven, no background of ours.
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
    /// empty-state captions. Held back by alpha under the tint,
    /// because a second opaque colour would render identically to
    /// `foreground`.
    public var foregroundSecondary: Color {
        isTinted ? .primary.opacity(0.6) : .kadoForegroundSecondary
    }

    // MARK: - Fills

    /// The resting fill behind an untouched habit row, and behind a
    /// not-due day in the weekly matrix. Opaque paper in full colour;
    /// a faint wash under the tint, so whatever sits on top of it
    /// still reads.
    public var restingFill: Color {
        isTinted ? .primary.opacity(0.14) : .kadoHairline
    }

    /// Fill for a habit row, given its status for today.
    ///
    /// Full colour keeps the habit's own hue. Under the tint the hue
    /// is gone, so the three states are separated by alpha alone —
    /// and every one of them stays well below the foreground so the
    /// name on top survives.
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
            case .none: return .kadoHairline
            }
        }
        switch status {
        case .complete: return .primary.opacity(0.4)
        case .partial: return .primary.opacity(0.2 + clamped * 0.15)
        case .none: return .primary.opacity(0.14)
        }
    }

    /// Text and glyphs drawn *on top of* `habitFill`.
    ///
    /// In full colour a completed row is a saturated block, so its
    /// label is knocked out in white. Under the tint that same white
    /// would be re-tinted to exactly the colour of the block beneath
    /// it — the label would vanish — so it goes to full-strength
    /// `foreground` and leans on the fill's alpha for contrast.
    public func onHabitFill(_ color: HabitColor, status: WidgetStatus) -> Color {
        guard isTinted else {
            return status == .complete ? .white : color.color
        }
        return .primary
    }
}
