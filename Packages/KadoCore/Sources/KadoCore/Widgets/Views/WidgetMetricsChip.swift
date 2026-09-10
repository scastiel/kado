import SwiftUI
import WidgetKit

/// `🔥 streak · score%` caption for a habit row in the large home
/// widget — the widget's counterpart to the app's `MetricsChip`.
///
/// Kept separate rather than shared because the app's version paints
/// straight from the paper / ink palette, and a widget does not get
/// to keep its palette: under the Home Screen's Tinted and Clear
/// appearances every opaque pixel is re-tinted with one system colour
/// and only alpha survives. Colours therefore route through
/// `WidgetPalette`, which flattens the flame's orange onto the
/// secondary weight once hue stops carrying information.
///
/// Streak is hidden when zero, matching the app: a habit with no run
/// going shouldn't display a `0` for it.
public struct WidgetMetricsChip: View {
    let streak: Int
    let scorePercent: Int

    @Environment(\.widgetRenderingMode) private var renderingMode

    public init(streak: Int, scorePercent: Int) {
        self.streak = streak
        self.scorePercent = scorePercent
    }

    private var palette: WidgetPalette {
        WidgetPalette(renderingMode: renderingMode)
    }

    public var body: some View {
        HStack(spacing: 4) {
            if streak > 0 {
                // Hand-rolled "label" — `Label`'s default icon-to-title
                // gap is sized for body text and reads as loose here.
                HStack(spacing: 2) {
                    Image(systemName: "flame.fill")
                    Text("\(streak)")
                }
                .foregroundStyle(palette.streakAccent)
                Text(verbatim: "·")
                    .foregroundStyle(palette.foregroundSecondary)
            }
            Text("\(scorePercent)%")
                .foregroundStyle(palette.foregroundSecondary)
        }
        // `.caption2` rather than the app chip's fixed 11pt: one step
        // below the `.caption` habit name beside it, and it still
        // scales with Dynamic Type.
        .font(.caption2.weight(.semibold).monospacedDigit())
        // One element, or VoiceOver reads a bare "7" for the flame.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        // The numbers shouldn't truncate to "7…", but they mustn't
        // hold the row hostage either: at accessibility sizes the
        // widest chip ("128 · 100%") plus its gap can eat a
        // systemLarge row and leave the habit name as an ellipsis,
        // which is worse than a smaller number. Shrink first, and
        // only then let the name give.
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var accessibilityLabel: String {
        guard streak > 0 else {
            return String(
                localized: "Score \(scorePercent) percent",
                comment: "VoiceOver label for a large-widget habit row with no active streak. Arg: EMA score percent (0-100)."
            )
        }
        return String(
            localized: "Streak \(streak), score \(scorePercent) percent",
            comment: "VoiceOver label for a large-widget habit row. First arg: streak length in days. Second arg: EMA score percent (0-100)."
        )
    }
}

#Preview("Chip") {
    VStack(alignment: .trailing, spacing: 8) {
        WidgetMetricsChip(streak: 0, scorePercent: 30)
        WidgetMetricsChip(streak: 3, scorePercent: 65)
        WidgetMetricsChip(streak: 128, scorePercent: 100)
    }
    .padding()
}

#Preview("Dark") {
    VStack(alignment: .trailing, spacing: 8) {
        WidgetMetricsChip(streak: 0, scorePercent: 30)
        WidgetMetricsChip(streak: 12, scorePercent: 87)
    }
    .padding()
    .preferredColorScheme(.dark)
}
