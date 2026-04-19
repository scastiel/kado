import SwiftUI
import WidgetKit
import KadoCore

/// Medium home widget — two-column habit grid plus a progress
/// summary. Reads the App Group snapshot.
struct TodayProgressMediumWidget: Widget {
    let kind: String = "dev.scastiel.kado.widget.todayMedium"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotTimelineProvider()) { entry in
            TodayProgressMediumView(entry: entry)
                .containerBackground(for: .widget) { Color.kadoBackgroundSecondary }
                .widgetURL(URL(string: "kado://today"))
        }
        .configurationDisplayName(Text("Today · Progress"))
        .description(Text("Habits due today with a completion summary."))
        .supportedFamilies([.systemMedium])
    }
}

struct TodayProgressMediumView: View {
    let entry: SnapshotEntry

    private let limit = 8

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if entry.snapshot.today.isEmpty {
                TodayEmptyPlaceholder()
            } else {
                cellGrid
            }
            Spacer(minLength: 0)
        }
    }

    private var header: some View {
        HStack {
            Text("Today")
                .font(.headline)
            Spacer()
            Text(
                String(
                    localized: "\(entry.snapshot.completedToday) / \(entry.snapshot.totalDueToday) done",
                    comment: "Widget progress summary. Arg 1 is completed count, arg 2 is total count."
                )
            )
            .font(.caption.monospacedDigit())
            .foregroundStyle(Color.kadoForegroundSecondary)
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
            ForEach(entry.snapshot.today.prefix(limit)) { row in
                HabitWidgetCell(row: row)
            }
        }
    }
}

#Preview("Eight habits", as: .systemMedium) {
    TodayProgressMediumWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: PreviewSnapshots.populated)
}

#Preview("Empty", as: .systemMedium) {
    TodayProgressMediumWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: .empty)
}
