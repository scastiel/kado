import SwiftUI
import WidgetKit
import KadoCore

/// Medium home widget — two-column habit grid plus a progress
/// summary. Reads the App Group snapshot, narrowed to the habits the
/// user picked in the widget-edit sheet.
struct TodayProgressMediumWidget: Widget {
    let kind: String = "dev.scastiel.kado.widget.todayMedium"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectHabitsIntent.self,
            provider: SelectedSnapshotProvider()
        ) { entry in
            TodayProgressMediumView(entry: entry)
                .containerBackground(for: .widget) { Color.kadoBackgroundSecondary }
                .widgetURL(URL(string: "kado://today"))
        }
        .configurationDisplayName(Text("Today · Progress"))
        .description(Text("Habits due today with a completion summary. Pick up to 8."))
        .supportedFamilies([.systemMedium])
    }
}

struct TodayProgressMediumView: View {
    let entry: SelectedSnapshotEntry

    @Environment(\.widgetRenderingMode) private var renderingMode

    private var palette: WidgetPalette {
        WidgetPalette(renderingMode: renderingMode)
    }

    private var rows: [WidgetTodayRow] {
        entry.todayRows(limit: WidgetHabitLimit.medium)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if rows.isEmpty {
                TodayEmptyPlaceholder(isFilteredOut: !entry.snapshot.today.isEmpty)
            } else {
                cellGrid
            }
            Spacer(minLength: 0)
        }
    }

    private var header: some View {
        // Counts the pick when there is one, the whole day when there
        // isn't — otherwise the summary describes habits this tile
        // deliberately hides.
        let progress = entry.progress(limit: WidgetHabitLimit.medium)
        return HStack {
            Text("Today")
                .font(.headline)
                .foregroundStyle(palette.foreground)
                .widgetAccentable()
            Spacer()
            Text(
                String(
                    localized: "\(progress.completed) / \(progress.total) done",
                    comment: "Widget progress summary. Arg 1 is completed count, arg 2 is total count."
                )
            )
            .font(.caption.monospacedDigit())
            .foregroundStyle(palette.foregroundSecondary)
        }
    }

    private var cellGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 6),
                GridItem(.flexible(), spacing: 6),
            ],
            spacing: 4
        ) {
            ForEach(rows) { row in
                HabitWidgetCell(row: row)
            }
        }
    }
}

#Preview("Eight habits", as: .systemMedium) {
    TodayProgressMediumWidget()
} timeline: {
    SelectedSnapshotEntry(date: .now, snapshot: PreviewSnapshots.populated, habitIDs: [])
}

#Preview("Picked two", as: .systemMedium) {
    TodayProgressMediumWidget()
} timeline: {
    SelectedSnapshotEntry(
        date: .now,
        snapshot: PreviewSnapshots.populated,
        habitIDs: PreviewSnapshots.pickedTodayIDs
    )
}

#Preview("Empty", as: .systemMedium) {
    TodayProgressMediumWidget()
} timeline: {
    SelectedSnapshotEntry(date: .now, snapshot: .empty, habitIDs: [])
}
