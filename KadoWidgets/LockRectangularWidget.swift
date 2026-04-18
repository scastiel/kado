import SwiftUI
import WidgetKit

struct LockRectangularWidget: Widget {
    let kind: String = "dev.scastiel.kado.widget.lockRectangular"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: PickHabitIntent.self,
            provider: PickedHabitProvider()
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
    let entry: PickedHabitEntry

    var body: some View {
        if let habit = entry.habit, let state = entry.state {
            filled(habit: habit, state: state)
        } else {
            pickPrompt
        }
    }

    private func filled(habit: Habit, state: HabitRowState) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: habit.icon)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(habit.name)
                    .font(.headline)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text("\(entry.streak ?? 0)d")
                        .font(.caption2.monospacedDigit())
                    scoreBar(progress: state.progress)
                    Text("\(entry.scorePercent ?? 0)%")
                        .font(.caption2.monospacedDigit())
                }
            }
            Spacer(minLength: 0)
        }
        .widgetAccentable()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(habit.name)
        .accessibilityValue(accessibilityValue(for: state))
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

    private func accessibilityValue(for state: HabitRowState) -> String {
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

#Preview("Picked habit", as: .accessoryRectangular) {
    LockRectangularWidget()
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

#Preview("Unpicked", as: .accessoryRectangular) {
    LockRectangularWidget()
} timeline: {
    PickedHabitEntry.empty()
}
