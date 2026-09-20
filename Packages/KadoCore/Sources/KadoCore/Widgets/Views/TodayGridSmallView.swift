import SwiftUI
import WidgetKit

/// The small home widget's content — up to five habits due today as
/// tappable, score-shaded chips, narrowed to the habits the user
/// picked in the widget-edit sheet. `TodayGridSmallWidget` in the
/// extension wraps it in an `AppIntentConfiguration`; the app draws
/// it directly for the listing's widget screenshot.
public struct TodayGridSmallView: View {
    let entry: SelectedSnapshotEntry

    public init(entry: SelectedSnapshotEntry) {
        self.entry = entry
    }

    private var rows: [WidgetTodayRow] {
        entry.todayRows(limit: WidgetHabitLimit.small)
    }

    public var body: some View {
        if rows.isEmpty {
            // "All done" only when the day really is clear. If other
            // habits are due and none of them was picked, saying "all
            // done" would be a lie about habits the user still owes.
            TodayEmptyPlaceholder(isFilteredOut: entry.isFilteredOut(limit: WidgetHabitLimit.small))
        } else {
            VStack(spacing: 4) {
                ForEach(rows) { row in
                    HabitWidgetCell(row: row)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

/// What the small and medium widgets show when they have no row to
/// draw. An empty state asserts *why* it is empty, so there are two:
/// the day is clear, or the user's pick has nothing due.
public struct TodayEmptyPlaceholder: View {
    /// `true` when the tile is empty because the user's pick matched
    /// nothing — not due today, archived, deleted — rather than
    /// because there is nothing left to do.
    let isFilteredOut: Bool

    @Environment(\.widgetRenderingMode) private var renderingMode

    public init(isFilteredOut: Bool = false) {
        self.isFilteredOut = isFilteredOut
    }

    public var body: some View {
        let palette = WidgetPalette(renderingMode: renderingMode)
        VStack(spacing: 6) {
            Image(systemName: isFilteredOut ? "line.3.horizontal.decrease.circle" : "checkmark.circle")
                .font(.title2)
                .foregroundStyle(palette.foregroundSecondary)
            // Two `Text`s rather than a ternary inside one: a
            // `Text(cond ? "A" : "B")` binds to the `StringProtocol`
            // overload and neither arm ever reaches the catalog.
            Group {
                if isFilteredOut {
                    Text("No picked habits to show")
                } else {
                    Text("All done")
                }
            }
            .font(.caption)
            .multilineTextAlignment(.center)
            .foregroundStyle(palette.foregroundSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // The only content on the tile, so it belongs in the accent
        // group. Without this the whole widget falls into the dimmed
        // default group and the caption's own alpha dims it a second
        // time — leaving the empty state fainter than it was before
        // any of this.
        .widgetAccentable()
    }
}
