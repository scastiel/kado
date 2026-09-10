import SwiftUI
import WidgetKit
import KadoCore

/// Medium home widget — two-column habit grid plus a progress
/// summary. Reads the App Group snapshot. The content is
/// `TodayProgressMediumView`, in `KadoCore`, so the app can draw it too.
struct TodayProgressMediumWidget: Widget {
    let kind: String = "dev.scastiel.kado.widget.todayMedium"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotTimelineProvider()) { entry in
            TodayProgressMediumView(entry: entry)
                .containerBackground(for: .widget) { Color.kadoBackgroundSecondary }
                .widgetURL(URL(string: "kado://today"))
        }
        .configurationDisplayName(Text("Today · Progress"))
        .description(Text("Habits due today with a completion summary."))
        .supportedFamilies([.systemMedium])
    }
}

#Preview("Eight habits", as: .systemMedium) {
    TodayProgressMediumWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: PreviewSnapshots.populated)
}

#Preview("Empty", as: .systemMedium) {
    TodayProgressMediumWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: .empty)
}
