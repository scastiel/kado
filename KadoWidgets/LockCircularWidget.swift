import SwiftUI
import WidgetKit

struct LockCircularWidget: Widget {
    let kind: String = "dev.scastiel.kado.widget.lockCircular"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: PickHabitIntent.self,
            provider: PickedHabitProvider()
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
    let entry: PickedHabitEntry

    var body: some View {
        if let habit = entry.habit, let state = entry.state {
            filled(habit: habit, state: state)
        } else {
            prompt
        }
    }

    private func filled(habit: Habit, state: HabitRowState) -> some View {
        Gauge(value: state.progress) {
            Image(systemName: habit.icon)
        } currentValueLabel: {
            currentLabel(for: habit, state: state)
        }
        .gaugeStyle(.accessoryCircular)
        .widgetAccentable()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(habit.name)
        .accessibilityValue(accessibilityValue(for: habit, state: state))
    }

    @ViewBuilder
    private func currentLabel(for habit: Habit, state: HabitRowState) -> some View {
        switch habit.type {
        case .binary, .negative:
            Image(systemName: state.status == .complete ? "checkmark" : "")
                .font(.caption2)
        case .counter, .timer:
            Text("\(Int(state.progress * 100))")
                .font(.caption2.monospacedDigit())
        }
    }

    private var prompt: some View {
        Image(systemName: "square.and.pencil")
            .widgetAccentable()
            .accessibilityLabel("Pick a habit")
    }

    private func accessibilityValue(for habit: Habit, state: HabitRowState) -> String {
        switch state.status {
        case .complete:
            return String(localized: "done", comment: "Widget accessibility: habit completed today")
        case .partial:
            return String(localized: "\(Int(state.progress * 100))% complete",
                          comment: "Widget accessibility: habit partially complete. Arg is percent 0-100.")
        case .none:
            return String(localized: "not done", comment: "Widget accessibility: habit not completed today")
        }
    }
}

#Preview("Complete binary", as: .accessoryCircular) {
    LockCircularWidget()
} timeline: {
    PickedHabitEntry(
        date: .now,
        habit: Habit(
            id: UUID(),
            name: "Meditate",
            frequency: .daily,
            type: .binary,
            createdAt: .now,
            color: .green,
            icon: "leaf.fill"
        ),
        state: HabitRowState(status: .complete, progress: 1.0, valueToday: 1),
        streak: 12,
        scorePercent: 87
    )
}

#Preview("Partial counter", as: .accessoryCircular) {
    LockCircularWidget()
} timeline: {
    PickedHabitEntry(
        date: .now,
        habit: Habit(
            id: UUID(),
            name: "Water",
            frequency: .daily,
            type: .counter(target: 8),
            createdAt: .now,
            color: .teal,
            icon: "drop.fill"
        ),
        state: HabitRowState(status: .partial, progress: 0.4, valueToday: 3),
        streak: 5,
        scorePercent: 62
    )
}

#Preview("Unpicked", as: .accessoryCircular) {
    LockCircularWidget()
} timeline: {
    PickedHabitEntry.empty()
}
