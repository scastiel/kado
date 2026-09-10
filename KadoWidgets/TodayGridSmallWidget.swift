import SwiftUI
import WidgetKit
import KadoCore

/// The small home widget — up to five habits due today as
/// tappable, score-shaded chips. Reads from the App Group JSON
/// snapshot via `SnapshotTimelineProvider`. The content is
/// `TodayGridSmallView`, in `KadoCore`, so the app can draw it too.
struct TodayGridSmallWidget: Widget {
    let kind: String = "dev.scastiel.kado.widget.todaySmall"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotTimelineProvider()) { entry in
            TodayGridSmallView(entry: entry)
                .containerBackground(for: .widget) { Color.kadoBackgroundSecondary }
                .widgetURL(URL(string: "kado://today"))
        }
        .configurationDisplayName(Text("Today"))
        .description(Text("Quick tap-to-complete for the habits due today."))
        .supportedFamilies([.systemSmall])
    }
}

#Preview("Five habits", as: .systemSmall) {
    TodayGridSmallWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: PreviewSnapshots.populated)
}

#Preview("Empty", as: .systemSmall) {
    TodayGridSmallWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: .empty)
}
