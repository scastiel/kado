import SwiftUI
import WidgetKit
import KadoCore

/// The small home widget — up to five habits due today as tappable,
/// score-shaded chips, narrowed to the habits the user picked in the
/// widget-edit sheet (long-press → Edit Widget). Reads from the App
/// Group JSON snapshot via `SelectedSnapshotProvider`. The content is
/// `TodayGridSmallView`, in `KadoCore`, so the app can draw it too.
struct TodayGridSmallWidget: Widget {
    let kind: String = "dev.scastiel.kado.widget.todaySmall"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectHabitsIntent.self,
            provider: SelectedSnapshotProvider()
        ) { entry in
            TodayGridSmallView(entry: entry)
                .containerBackground(for: .widget) { Color.kadoBackgroundSecondary }
                .widgetURL(URL(string: "kado://today"))
        }
        .configurationDisplayName(Text("Today"))
        .description(Text("Quick tap-to-complete for the habits due today. Pick up to 5."))
        .supportedFamilies([.systemSmall])
    }
}

#Preview("Five habits", as: .systemSmall) {
    TodayGridSmallWidget()
} timeline: {
    SelectedSnapshotEntry(date: .now, snapshot: PreviewSnapshots.populated, habitIDs: [])
}

#Preview("Picked two", as: .systemSmall) {
    TodayGridSmallWidget()
} timeline: {
    SelectedSnapshotEntry(
        date: .now,
        snapshot: PreviewSnapshots.populated,
        habitIDs: PreviewSnapshots.pickedTodayIDs
    )
}

#Preview("Picked, one not due today", as: .systemSmall) {
    TodayGridSmallWidget()
} timeline: {
    SelectedSnapshotEntry(
        date: .now,
        snapshot: PreviewSnapshots.populated,
        habitIDs: PreviewSnapshots.pickedWithNotDueIDs
    )
}

#Preview("Picked, all gone", as: .systemSmall) {
    TodayGridSmallWidget()
} timeline: {
    SelectedSnapshotEntry(date: .now, snapshot: PreviewSnapshots.populated, habitIDs: [UUID()])
}

#Preview("Empty", as: .systemSmall) {
    TodayGridSmallWidget()
} timeline: {
    SelectedSnapshotEntry(date: .now, snapshot: .empty, habitIDs: [])
}
