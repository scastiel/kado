import SwiftUI
import WidgetKit
import KadoCore

/// Large home widget — habits × last 7 days matrix read from the App
/// Group snapshot, narrowed to the habits the user picked in the
/// widget-edit sheet. The content is `WeeklyGridLargeView`, in
/// `KadoCore`, so the app can draw it too.
struct WeeklyGridLargeWidget: Widget {
    let kind: String = "dev.scastiel.kado.widget.weeklyLarge"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectHabitsIntent.self,
            provider: SelectedSnapshotProvider()
        ) { entry in
            WeeklyGridLargeView(entry: entry)
                .containerBackground(for: .widget) { Color.kadoBackgroundSecondary }
                .widgetURL(URL(string: "kado://overview"))
        }
        .configurationDisplayName(Text("This Week"))
        .description(Text("Your habit grid for the past seven days. Pick up to 5."))
        .supportedFamilies([.systemLarge])
    }
}

#Preview("Populated", as: .systemLarge) {
    WeeklyGridLargeWidget()
} timeline: {
    SelectedSnapshotEntry(date: .now, snapshot: PreviewSnapshots.populated, habitIDs: [])
}

#Preview("Picked three", as: .systemLarge) {
    WeeklyGridLargeWidget()
} timeline: {
    SelectedSnapshotEntry(
        date: .now,
        snapshot: PreviewSnapshots.populated,
        habitIDs: PreviewSnapshots.pickedMatrixIDs
    )
}

#Preview("Picked, all gone", as: .systemLarge) {
    WeeklyGridLargeWidget()
} timeline: {
    SelectedSnapshotEntry(date: .now, snapshot: PreviewSnapshots.populated, habitIDs: [UUID()])
}

#Preview("Empty", as: .systemLarge) {
    WeeklyGridLargeWidget()
} timeline: {
    SelectedSnapshotEntry(date: .now, snapshot: .empty, habitIDs: [])
}
