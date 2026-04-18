import SwiftUI
import WidgetKit
import KadoCore

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

struct LockRectangularView: View {
    let entry: PickedSnapshotEntry

    var body: some View {
        if let row = entry.pickedRow {
            filled(row: row)
        } else {
            pickPrompt
        }
    }

    private func filled(row: WidgetTodayRow) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: row.habit.icon)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.habit.name)
                    .font(.headline)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text("\(row.streak)d")
                        .font(.caption2.monospacedDigit())
                    scoreBar(progress: row.progress)
                    Text("\(row.scorePercent)%")
                        .font(.caption2.monospacedDigit())
                }
            }
            Spacer(minLength: 0)
        }
        .widgetAccentable()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(row.habit.name)
    }

    private func scoreBar(progress: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.secondary.opacity(0.3))
                Capsule()
                    .fill(.primary)
                    .frame(width: max(4, geo.size.width * max(0, min(1, progress))))
            }
        }
        .frame(height: 4)
    }

    private var pickPrompt: some View {
        HStack(spacing: 6) {
            Image(systemName: "square.and.pencil")
            Text("Tap to pick a habit")
                .font(.caption)
                .lineLimit(2)
        }
        .widgetAccentable()
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
