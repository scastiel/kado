import SwiftUI

/// A single row in the Today list. Renders every `HabitType`. The
/// leading circle is an independent Button that toggles completion
/// for binary/negative habits; the rest of the row is visual only
/// and composes with a parent `NavigationLink` to push to detail.
/// For counter/timer, the leading icon is non-interactive (quick-log
/// affordances live on the detail view).
struct HabitRowView: View {
    let habit: Habit
    let isCompletedToday: Bool
    let onToggle: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            leadingIcon
                .frame(width: 28, height: 28)
            Text(habit.name)
                .font(.body)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 8)
            trailingState
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabelText)
    }

    @ViewBuilder
    private var leadingIcon: some View {
        switch habit.type {
        case .binary, .negative:
            if let onToggle {
                Button(action: onToggle) {
                    toggleImage
                }
                .buttonStyle(.borderless)
                .sensoryFeedback(.success, trigger: isCompletedToday)
                .accessibilityLabel(
                    isCompletedToday
                        ? String(localized: "Mark as not done")
                        : String(localized: "Mark as done")
                )
            } else {
                toggleImage
            }
        case .counter:
            nonInteractiveIcon("number.circle")
        case .timer:
            nonInteractiveIcon("timer")
        }
    }

    private var toggleImage: some View {
        Image(systemName: isCompletedToday ? "checkmark.circle.fill" : "circle")
            .font(.title2)
            .foregroundStyle(isCompletedToday ? Color.accentColor : Color.secondary)
    }

    private func nonInteractiveIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.title2)
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var trailingState: some View {
        switch habit.type {
        case .counter(let target):
            Text("–/\(Int(target))")
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
        case .timer(let targetSeconds):
            Text(formatSeconds(targetSeconds))
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
        case .binary, .negative:
            EmptyView()
        }
    }

    private var accessibilityLabelText: String {
        switch habit.type {
        case .binary, .negative:
            let state = isCompletedToday
                ? String(localized: "done")
                : String(localized: "not done")
            return "\(habit.name), \(state)"
        case .counter(let target):
            return String(localized: "\(habit.name), counter, target \(Int(target))")
        case .timer(let targetSeconds):
            return String(localized: "\(habit.name), timer, target \(formatSeconds(targetSeconds))")
        }
    }

    private func formatSeconds(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let minutes = total / 60
        let remaining = total % 60
        return String(format: "%d:%02d", minutes, remaining)
    }
}

#Preview("All types — not done") {
    List {
        HabitRowView(
            habit: Habit(name: "Morning meditation", frequency: .daily, type: .binary, createdAt: .now),
            isCompletedToday: false,
            onToggle: {}
        )
        HabitRowView(
            habit: Habit(name: "Drink water", frequency: .daily, type: .counter(target: 8), createdAt: .now),
            isCompletedToday: false,
            onToggle: nil
        )
        HabitRowView(
            habit: Habit(name: "Read", frequency: .daily, type: .timer(targetSeconds: 1800), createdAt: .now),
            isCompletedToday: false,
            onToggle: nil
        )
        HabitRowView(
            habit: Habit(name: "No social media", frequency: .daily, type: .negative, createdAt: .now),
            isCompletedToday: false,
            onToggle: {}
        )
    }
}

#Preview("All types — done") {
    List {
        HabitRowView(
            habit: Habit(name: "Morning meditation", frequency: .daily, type: .binary, createdAt: .now),
            isCompletedToday: true,
            onToggle: {}
        )
        HabitRowView(
            habit: Habit(name: "Drink water", frequency: .daily, type: .counter(target: 8), createdAt: .now),
            isCompletedToday: true,
            onToggle: nil
        )
        HabitRowView(
            habit: Habit(name: "Read", frequency: .daily, type: .timer(targetSeconds: 1800), createdAt: .now),
            isCompletedToday: true,
            onToggle: nil
        )
        HabitRowView(
            habit: Habit(name: "No social media", frequency: .daily, type: .negative, createdAt: .now),
            isCompletedToday: true,
            onToggle: {}
        )
    }
}

#Preview("Dynamic Type XXXL") {
    List {
        HabitRowView(
            habit: Habit(name: "Morning meditation", frequency: .daily, type: .binary, createdAt: .now),
            isCompletedToday: true,
            onToggle: {}
        )
        HabitRowView(
            habit: Habit(name: "Drink water", frequency: .daily, type: .counter(target: 8), createdAt: .now),
            isCompletedToday: false,
            onToggle: nil
        )
    }
    .environment(\.dynamicTypeSize, .accessibility3)
}
