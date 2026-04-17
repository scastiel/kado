import SwiftUI

/// A single row in the Today list. Renders every `HabitType`, but
/// only binary and negative habits accept tap-to-toggle. Counter and
/// timer rows are read-only until the habit detail view ships with
/// per-type input affordances.
struct HabitRowView: View {
    let habit: Habit
    let isCompletedToday: Bool
    let onTap: (() -> Void)?

    var body: some View {
        Group {
            if let onTap {
                Button(action: onTap) { rowContent }
                    .buttonStyle(.plain)
            } else {
                rowContent
            }
        }
        .sensoryFeedback(.success, trigger: isCompletedToday)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabelText)
        .accessibilityHint(onTap == nil ? "" : String(localized: "Double tap to toggle completion."))
    }

    private var rowContent: some View {
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
    }

    @ViewBuilder
    private var leadingIcon: some View {
        switch habit.type {
        case .binary, .negative:
            Image(systemName: isCompletedToday ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(isCompletedToday ? Color.accentColor : Color.secondary)
        case .counter:
            Image(systemName: "number.circle")
                .font(.title2)
                .foregroundStyle(.secondary)
        case .timer:
            Image(systemName: "timer")
                .font(.title2)
                .foregroundStyle(.secondary)
        }
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
            onTap: {}
        )
        HabitRowView(
            habit: Habit(name: "Drink water", frequency: .daily, type: .counter(target: 8), createdAt: .now),
            isCompletedToday: false,
            onTap: nil
        )
        HabitRowView(
            habit: Habit(name: "Read", frequency: .daily, type: .timer(targetSeconds: 1800), createdAt: .now),
            isCompletedToday: false,
            onTap: nil
        )
        HabitRowView(
            habit: Habit(name: "No social media", frequency: .daily, type: .negative, createdAt: .now),
            isCompletedToday: false,
            onTap: {}
        )
    }
}

#Preview("All types — done") {
    List {
        HabitRowView(
            habit: Habit(name: "Morning meditation", frequency: .daily, type: .binary, createdAt: .now),
            isCompletedToday: true,
            onTap: {}
        )
        HabitRowView(
            habit: Habit(name: "Drink water", frequency: .daily, type: .counter(target: 8), createdAt: .now),
            isCompletedToday: true,
            onTap: nil
        )
        HabitRowView(
            habit: Habit(name: "Read", frequency: .daily, type: .timer(targetSeconds: 1800), createdAt: .now),
            isCompletedToday: true,
            onTap: nil
        )
        HabitRowView(
            habit: Habit(name: "No social media", frequency: .daily, type: .negative, createdAt: .now),
            isCompletedToday: true,
            onTap: {}
        )
    }
}

#Preview("Dynamic Type XXXL") {
    List {
        HabitRowView(
            habit: Habit(name: "Morning meditation", frequency: .daily, type: .binary, createdAt: .now),
            isCompletedToday: true,
            onTap: {}
        )
        HabitRowView(
            habit: Habit(name: "Drink water", frequency: .daily, type: .counter(target: 8), createdAt: .now),
            isCompletedToday: false,
            onTap: nil
        )
    }
    .environment(\.dynamicTypeSize, .accessibility3)
}
