import SwiftUI
import WidgetKit
import KadoCore

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

struct LockCircularView: View {
    let entry: PickedSnapshotEntry

    var body: some View {
        if let row = entry.pickedRow {
            filled(row: row)
        } else {
            prompt
        }
    }

    private func filled(row: WidgetTodayRow) -> some View {
        Gauge(value: row.progress) {
            Image(systemName: row.habit.icon)
        } currentValueLabel: {
            currentLabel(for: row)
        }
        .gaugeStyle(.accessoryCircular)
        .widgetAccentable()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(row.habit.name)
    }

    @ViewBuilder
    private func currentLabel(for row: WidgetTodayRow) -> some View {
        switch row.habit.typeKind {
        case .binary, .negative:
            Image(systemName: row.status == .complete ? "checkmark" : "")
                .font(.caption2)
        case .counter, .timer:
            Text("\(Int(row.progress * 100))")
                .font(.caption2.monospacedDigit())
        }
    }

    private var prompt: some View {
        Image(systemName: "square.and.pencil")
            .widgetAccentable()
            .accessibilityLabel("Pick a habit")
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
