import SwiftUI
import WidgetKit
import KadoCore

/// The small home widget — up to five habits due today as
/// tappable, score-shaded chips. Reads from the App Group JSON
/// snapshot, narrowed to the habits the user picked in the
/// widget-edit sheet.
struct TodayGridSmallWidget: Widget {
    let kind: String = "dev.scastiel.kado.widget.todaySmall"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectHabitsIntent.self,
            provider: SelectedSnapshotProvider()
        ) { entry in
            TodayGridSmallView(entry: entry)
                .containerBackground(for: .widget) { Color.kadoBackgroundSecondary }
                .widgetURL(URL(string: "kado://today"))
        }
        .configurationDisplayName(Text("Today"))
        .description(Text("Quick tap-to-complete for the habits due today. Pick up to 5."))
        .supportedFamilies([.systemSmall])
    }
}

struct TodayGridSmallView: View {
    let entry: SelectedSnapshotEntry

    private var rows: [WidgetTodayRow] {
        entry.todayRows(limit: WidgetHabitLimit.small)
    }

    var body: some View {
        if rows.isEmpty {
            // "All done" only when the day really is empty. If other
            // habits are due and none of them was picked, saying "all
            // done" would be a lie about habits the user still owes.
            TodayEmptyPlaceholder(isFilteredOut: !entry.snapshot.today.isEmpty)
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

struct TodayEmptyPlaceholder: View {
    /// `true` when the tile is empty because the user's pick matched
    /// nothing, rather than because there is nothing left to do.
    var isFilteredOut: Bool = false

    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        let palette = WidgetPalette(renderingMode: renderingMode)
        VStack(spacing: 6) {
            Image(systemName: isFilteredOut ? "line.3.horizontal.decrease.circle" : "checkmark.circle")
                .font(.title2)
                .foregroundStyle(palette.foregroundSecondary)
            // Split rather than a ternary inside one `Text`: a
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

#Preview("Five habits", as: .systemSmall) {
    TodayGridSmallWidget()
} timeline: {
    SelectedSnapshotEntry(date: .now, snapshot: PreviewSnapshots.populated, habitIDs: [])
}

#Preview("Picked two", as: .systemSmall) {
    TodayGridSmallWidget()
} timeline: {
    SelectedSnapshotEntry(
        date: .now,
        snapshot: PreviewSnapshots.populated,
        habitIDs: PreviewSnapshots.pickedTodayIDs
    )
}

#Preview("Picked, none due", as: .systemSmall) {
    TodayGridSmallWidget()
} timeline: {
    SelectedSnapshotEntry(
        date: .now,
        snapshot: PreviewSnapshots.populated,
        habitIDs: [UUID()]
    )
}

#Preview("Empty", as: .systemSmall) {
    TodayGridSmallWidget()
} timeline: {
    SelectedSnapshotEntry(date: .now, snapshot: .empty, habitIDs: [])
}
