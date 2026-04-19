import SwiftUI
import WidgetKit
import KadoCore

/// The small home widget — up to five habits due today as
/// tappable, score-shaded chips. Reads from the App Group JSON
/// snapshot via `SnapshotTimelineProvider`.
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

struct TodayGridSmallView: View {
    let entry: SnapshotEntry

    private let limit = 5

    var body: some View {
        if entry.snapshot.today.isEmpty {
            TodayEmptyPlaceholder()
        } else {
            VStack(spacing: 4) {
                ForEach(entry.snapshot.today.prefix(limit)) { row in
                    HabitWidgetCell(row: row)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

struct TodayEmptyPlaceholder: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "checkmark.circle")
                .font(.title2)
                .foregroundStyle(Color.kadoForegroundSecondary)
            Text("All done")
                .font(.caption)
                .foregroundStyle(Color.kadoForegroundSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
