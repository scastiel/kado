import SwiftUI
import WidgetKit
import KadoCore

/// Large home widget — habits × last 7 days matrix read from the
/// App Group snapshot. The content is `WeeklyGridLargeView`, in
/// `KadoCore`, so the app can draw it too.
struct WeeklyGridLargeWidget: Widget {
    let kind: String = "dev.scastiel.kado.widget.weeklyLarge"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotTimelineProvider()) { entry in
            WeeklyGridLargeView(entry: entry)
                .containerBackground(for: .widget) { Color.kadoBackgroundSecondary }
                .widgetURL(URL(string: "kado://overview"))
        }
        .configurationDisplayName(Text("This Week"))
        .description(Text("Your habit grid for the past seven days."))
        .supportedFamilies([.systemLarge])
    }
}

#Preview("Populated", as: .systemLarge) {
    WeeklyGridLargeWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: PreviewSnapshots.populated)
}

#Preview("Empty", as: .systemLarge) {
    WeeklyGridLargeWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: .empty)
}
