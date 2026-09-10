import SwiftUI
import WidgetKit
import KadoCore

/// One picked habit as a Lock Screen ring. The content is
/// `LockCircularView`, in `KadoCore`, so the app can draw it too.
struct LockCircularWidget: Widget {
    let kind: String = "dev.scastiel.kado.widget.lockCircular"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: PickHabitIntent.self,
            provider: PickedSnapshotProvider()
        ) { entry in
            LockCircularView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName(Text("Habit Progress"))
        .description(Text("Today's progress for one habit as a ring."))
        .supportedFamilies([.accessoryCircular])
    }
}

#Preview("Complete binary", as: .accessoryCircular) {
    LockCircularWidget()
} timeline: {
    PickedSnapshotEntry(
        date: .now,
        snapshot: PreviewSnapshots.populated,
        habitID: PreviewSnapshots.firstHabitID
    )
}

#Preview("Unpicked", as: .accessoryCircular) {
    LockCircularWidget()
} timeline: {
    PickedSnapshotEntry(date: .now, snapshot: .empty, habitID: nil)
}
