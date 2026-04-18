import SwiftUI
import WidgetKit

/// The medium home widget — up to eight habits in a two-column
/// grid plus a header line summarising the day's progress.
struct TodayProgressMediumWidget: Widget {
    let kind: String = "dev.scastiel.kado.widget.todayMedium"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: HabitTimelineProvider(limit: 8)
        ) { entry in
            TodayProgressMediumView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(URL(string: "kado://today"))
        }
        .configurationDisplayName(Text("Today · Progress"))
        .description(Text("Habits due today with a completion summary."))
        .supportedFamilies([.systemMedium])
    }
}

struct TodayProgressMediumView: View {
    let entry: HabitTimelineEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if entry.rows.isEmpty {
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
            Text(String(localized: "\(entry.completedCount) / \(entry.totalCount) done",
                        comment: "Widget progress summary. Arg 1 is completed count, arg 2 is total count."))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .accessibilityLabel(accessibilitySummary)
        }
    }

    private var accessibilitySummary: String {
        String(
            localized: "\(entry.completedCount) of \(entry.totalCount) habits done today",
            comment: "Widget VoiceOver: progress summary. Arg 1 completed, arg 2 total."
        )
    }

    private var cellGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 6),
                GridItem(.flexible(), spacing: 6),
            ],
            spacing: 4
        ) {
            ForEach(entry.rows) { row in
                HabitWidgetCell(row: row)
            }
        }
    }
}

#Preview("Eight habits", as: .systemMedium) {
    TodayProgressMediumWidget()
} timeline: {
    HabitTimelineEntry(
        date: .now,
        rows: PreviewRows.mixed8,
        totalCount: 8,
        completedCount: 4
    )
}

#Preview("Empty", as: .systemMedium) {
    TodayProgressMediumWidget()
} timeline: {
    HabitTimelineEntry(
        date: .now,
        rows: [],
        totalCount: 0,
        completedCount: 0
    )
}
