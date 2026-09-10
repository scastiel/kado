import SwiftUI
import WidgetKit
import KadoCore

/// The round lock-screen "button" for the whole day: a ring that
/// closes as habits get done, with the Kadō mark in the middle.
/// Sibling of `LockCircularWidget`, which shows one picked habit; this
/// one needs no configuration, so it is a static widget on the shared
/// snapshot. The content is `LockDayProgressView`, in `KadoCore`, so
/// the app can draw it too.
struct LockDayProgressWidget: Widget {
    let kind: String = "dev.scastiel.kado.widget.lockDayProgress"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotTimelineProvider()) { entry in
            LockDayProgressView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName(Text("Daily Progress"))
        .description(Text("How many of today's habits are done, as a ring."))
        .supportedFamilies([.accessoryCircular])
    }
}

#Preview("Partial", as: .accessoryCircular) {
    LockDayProgressWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: PreviewSnapshots.populated)
}

#Preview("All done", as: .accessoryCircular) {
    LockDayProgressWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: PreviewSnapshots.allDone)
}

#Preview("Rest day", as: .accessoryCircular) {
    LockDayProgressWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: .empty)
}
