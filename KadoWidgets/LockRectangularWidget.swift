import SwiftUI
import WidgetKit
import KadoCore

/// One picked habit on the Lock Screen. The content is
/// `LockRectangularView`, in `KadoCore`, so the app can draw it too.
struct LockRectangularWidget: Widget {
    let kind: String = "dev.scastiel.kado.widget.lockRectangular"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: PickHabitIntent.self,
            provider: PickedSnapshotProvider()
        ) { entry in
            LockRectangularView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName(Text("Habit"))
        .description(Text("Show one habit on the lock screen."))
        .supportedFamilies([.accessoryRectangular])
    }
}

#Preview("Picked habit", as: .accessoryRectangular) {
    LockRectangularWidget()
} timeline: {
    PickedSnapshotEntry(
        date: .now,
        snapshot: PreviewSnapshots.populated,
        habitID: PreviewSnapshots.firstHabitID
    )
}

#Preview("Unpicked", as: .accessoryRectangular) {
    LockRectangularWidget()
} timeline: {
    PickedSnapshotEntry(date: .now, snapshot: .empty, habitID: nil)
}
