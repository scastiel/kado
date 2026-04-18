import SwiftUI
import WidgetKit
import KadoCore

struct LockInlineWidget: Widget {
    let kind: String = "dev.scastiel.kado.widget.lockInline"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotTimelineProvider()) { entry in
            LockInlineView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName(Text("Today Summary"))
        .description(Text("One-line summary of today's habits."))
        .supportedFamilies([.accessoryInline])
    }
}

struct LockInlineView: View {
    let entry: SnapshotEntry

    var body: some View {
        if entry.snapshot.totalDueToday == 0 {
            Label {
                Text("No habits due today")
            } icon: {
                Image(systemName: "checkmark.circle")
            }
        } else {
            Label {
                Text(
                    String(
                        localized: "\(entry.snapshot.completedToday) of \(entry.snapshot.totalDueToday) done today",
                        comment: "Inline lock widget summary. Arg 1 completed, arg 2 total."
                    )
                )
            } icon: {
                Image(systemName: summaryIcon)
            }
        }
    }

    private var summaryIcon: String {
        if entry.snapshot.totalDueToday == 0 { return "checkmark.circle" }
        if entry.snapshot.completedToday == entry.snapshot.totalDueToday { return "checkmark.circle.fill" }
        return "circle.dotted"
    }
}

#Preview("Partial", as: .accessoryInline) {
    LockInlineWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: PreviewSnapshots.populated)
}

#Preview("Empty", as: .accessoryInline) {
    LockInlineWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: .empty)
}
