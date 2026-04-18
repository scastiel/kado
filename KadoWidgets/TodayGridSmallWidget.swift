import SwiftUI
import WidgetKit

/// The small home widget — up to five habits due today as
/// tappable, score-shaded chips. Uses `HabitTimelineProvider`
/// (limit 5) shared with the medium widget.
struct TodayGridSmallWidget: Widget {
    let kind: String = "dev.scastiel.kado.widget.todaySmall"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: HabitTimelineProvider(limit: 5)
        ) { entry in
            TodayGridSmallView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(URL(string: "kado://today"))
        }
        .configurationDisplayName(Text("Today"))
        .description(Text("Quick tap-to-complete for the habits due today."))
        .supportedFamilies([.systemSmall])
    }
}

struct TodayGridSmallView: View {
    let entry: HabitTimelineEntry

    var body: some View {
        if entry.rows.isEmpty {
            TodayEmptyPlaceholder()
        } else {
            VStack(spacing: 4) {
                ForEach(entry.rows) { row in
                    HabitWidgetCell(row: row)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

struct TodayEmptyPlaceholder: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "checkmark.circle")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("All done")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("Five habits", as: .systemSmall) {
    TodayGridSmallWidget()
} timeline: {
    HabitTimelineEntry(
        date: .now,
        rows: PreviewRows.mixed5,
        totalCount: 5,
        completedCount: 2
    )
}

#Preview("Empty", as: .systemSmall) {
    TodayGridSmallWidget()
} timeline: {
    HabitTimelineEntry(
        date: .now,
        rows: [],
        totalCount: 0,
        completedCount: 0
    )
}
