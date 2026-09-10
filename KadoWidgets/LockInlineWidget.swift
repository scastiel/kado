import SwiftUI
import WidgetKit
import KadoCore

/// The one-line Lock Screen summary. The content is `LockInlineView`,
/// in `KadoCore`, so the app can draw it too.
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
