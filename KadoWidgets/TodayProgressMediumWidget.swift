import SwiftUI
import WidgetKit
import KadoCore

/// Medium home widget — two-column habit grid plus a progress
/// summary, narrowed to the habits the user picked in the widget-edit
/// sheet. Reads the App Group snapshot via `SelectedSnapshotProvider`.
/// The content is `TodayProgressMediumView`, in `KadoCore`, so the app
/// can draw it too.
struct TodayProgressMediumWidget: Widget {
    let kind: String = "dev.scastiel.kado.widget.todayMedium"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectHabitsIntent.self,
            provider: SelectedSnapshotProvider()
        ) { entry in
            TodayProgressMediumView(entry: entry)
                .containerBackground(for: .widget) { Color.kadoBackgroundSecondary }
                .widgetURL(URL(string: "kado://today"))
        }
        .configurationDisplayName(Text("Today · Progress"))
        .description(Text("Habits due today with a completion summary. Pick up to 8."))
        .supportedFamilies([.systemMedium])
    }
}

#Preview("Eight habits", as: .systemMedium) {
    TodayProgressMediumWidget()
} timeline: {
    SelectedSnapshotEntry(date: .now, snapshot: PreviewSnapshots.populated, habitIDs: [])
}

#Preview("Picked two", as: .systemMedium) {
    TodayProgressMediumWidget()
} timeline: {
    SelectedSnapshotEntry(
        date: .now,
        snapshot: PreviewSnapshots.populated,
        habitIDs: PreviewSnapshots.pickedTodayIDs
    )
}

#Preview("Picked, one not due today", as: .systemMedium) {
    TodayProgressMediumWidget()
} timeline: {
    SelectedSnapshotEntry(
        date: .now,
        snapshot: PreviewSnapshots.populated,
        habitIDs: PreviewSnapshots.pickedWithNotDueIDs
    )
}

#Preview("Picked, all gone", as: .systemMedium) {
    TodayProgressMediumWidget()
} timeline: {
    SelectedSnapshotEntry(date: .now, snapshot: PreviewSnapshots.populated, habitIDs: [UUID()])
}

#Preview("Empty", as: .systemMedium) {
    TodayProgressMediumWidget()
} timeline: {
    SelectedSnapshotEntry(date: .now, snapshot: .empty, habitIDs: [])
}
