import SwiftUI
import WidgetKit
import KadoCore

struct LockInlineWidget: Widget {
    let kind: String = "dev.scastiel.kado.widget.lockInline"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: HabitTimelineProvider(limit: 0)
        ) { entry in
            LockInlineView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName(Text("Today Summary"))
        .description(Text("One-line summary of today's habits."))
        .supportedFamilies([.accessoryInline])
    }
}

struct LockInlineView: View {
    let entry: HabitTimelineEntry

    var body: some View {
        if entry.totalCount == 0 {
            Label {
                Text("No habits due today")
            } icon: {
                Image(systemName: "checkmark.circle")
            }
        } else {
            Label {
                Text(
                    String(
                        localized: "\(entry.completedCount) of \(entry.totalCount) done today",
                        comment: "Inline lock widget summary. Arg 1 completed, arg 2 total."
                    )
                )
            } icon: {
                Image(systemName: summaryIcon)
            }
        }
    }

    private var summaryIcon: String {
        if entry.totalCount == 0 { return "checkmark.circle" }
        if entry.completedCount == entry.totalCount { return "checkmark.circle.fill" }
        return "circle.dotted"
    }
}

#Preview("Partial", as: .accessoryInline) {
    LockInlineWidget()
} timeline: {
    HabitTimelineEntry(
        date: .now,
        rows: [],
        totalCount: 5,
        completedCount: 3
    )
}

#Preview("All done", as: .accessoryInline) {
    LockInlineWidget()
} timeline: {
    HabitTimelineEntry(
        date: .now,
        rows: [],
        totalCount: 5,
        completedCount: 5
    )
}

#Preview("Empty", as: .accessoryInline) {
    LockInlineWidget()
} timeline: {
    HabitTimelineEntry(
        date: .now,
        rows: [],
        totalCount: 0,
        completedCount: 0
    )
}
