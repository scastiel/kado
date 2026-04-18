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
    /// Today's completion value, if any. Counter and timer rows
    /// surface this in the trailing label (e.g. `3/8`, `12:34/30:00`).
    var todayValue: Double? = nil

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
                    iconBadge
                }
                .buttonStyle(.borderless)
                .sensoryFeedback(.success, trigger: isCompletedToday)
                .accessibilityLabel(
                    isCompletedToday
                        ? String(localized: "Mark as not done")
                        : String(localized: "Mark as done")
                )
            } else {
                iconBadge
            }
        case .counter, .timer:
            iconBadge
        }
    }

    /// Circular badge showing the habit's icon in its color. Fills with
    /// the habit color when the day is complete; shows an outline
    /// treatment otherwise.
    private var iconBadge: some View {
        ZStack {
            Circle()
                .fill(isCompletedToday ? habit.color.color : Color.clear)
                .overlay {
                    Circle()
                        .strokeBorder(
                            habit.color.color.opacity(isCompletedToday ? 0 : 0.5),
                            lineWidth: 1.5
                        )
                }
            Image(systemName: habit.icon)
                .font(.callout.weight(.semibold))
                .foregroundStyle(isCompletedToday ? Color.white : habit.color.color)
        }
    }

    @ViewBuilder
    private var trailingState: some View {
        switch habit.type {
        case .counter(let target):
            Text(counterLabel(target: target))
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
        case .timer(let targetSeconds):
            Text(timerLabel(target: targetSeconds))
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
        case .binary, .negative:
            EmptyView()
        }
    }

    private func counterLabel(target: Double) -> String {
        if let todayValue {
            return "\(Int(todayValue))/\(Int(target))"
        }
        return "–/\(Int(target))"
    }

    private func timerLabel(target: TimeInterval) -> String {
        if let todayValue {
            return "\(formatSeconds(todayValue)) / \(formatSeconds(target))"
        }
        return formatSeconds(target)
    }

    private var accessibilityLabelText: String {
        switch habit.type {
        case .binary, .negative:
            let state = isCompletedToday
                ? String(localized: "done")
                : String(localized: "not done")
            return String(localized: "\(habit.name), \(state)")
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
            habit: Habit(name: "Morning meditation", frequency: .daily, type: .binary, createdAt: .now, color: .purple, icon: "figure.mind.and.body"),
            isCompletedToday: false,
            onToggle: {}
        )
        HabitRowView(
            habit: Habit(name: "Drink water", frequency: .daily, type: .counter(target: 8), createdAt: .now, color: .blue, icon: "drop.fill"),
            isCompletedToday: false,
            onToggle: nil
        )
        HabitRowView(
            habit: Habit(name: "Read", frequency: .daily, type: .timer(targetSeconds: 1800), createdAt: .now, color: .mint, icon: "book.fill"),
            isCompletedToday: false,
            onToggle: nil
        )
        HabitRowView(
            habit: Habit(name: "No social media", frequency: .daily, type: .negative, createdAt: .now, color: .red, icon: "flame.fill"),
            isCompletedToday: false,
            onToggle: {}
        )
    }
}

#Preview("All types — done") {
    List {
        HabitRowView(
            habit: Habit(name: "Morning meditation", frequency: .daily, type: .binary, createdAt: .now, color: .purple, icon: "figure.mind.and.body"),
            isCompletedToday: true,
            onToggle: {}
        )
        HabitRowView(
            habit: Habit(name: "Drink water", frequency: .daily, type: .counter(target: 8), createdAt: .now, color: .blue, icon: "drop.fill"),
            isCompletedToday: true,
            onToggle: nil
        )
        HabitRowView(
            habit: Habit(name: "Read", frequency: .daily, type: .timer(targetSeconds: 1800), createdAt: .now, color: .mint, icon: "book.fill"),
            isCompletedToday: true,
            onToggle: nil
        )
        HabitRowView(
            habit: Habit(name: "No social media", frequency: .daily, type: .negative, createdAt: .now, color: .red, icon: "flame.fill"),
            isCompletedToday: true,
            onToggle: {}
        )
    }
}

#Preview("Counter / timer in progress") {
    List {
        HabitRowView(
            habit: Habit(name: "Drink water", frequency: .daily, type: .counter(target: 8), createdAt: .now),
            isCompletedToday: false,
            onToggle: nil,
            todayValue: 3
        )
        HabitRowView(
            habit: Habit(name: "Drink water", frequency: .daily, type: .counter(target: 8), createdAt: .now),
            isCompletedToday: true,
            onToggle: nil,
            todayValue: 8
        )
        HabitRowView(
            habit: Habit(name: "Read", frequency: .daily, type: .timer(targetSeconds: 1800), createdAt: .now),
            isCompletedToday: false,
            onToggle: nil,
            todayValue: 750
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

#Preview("Dark") {
    List {
        HabitRowView(
            habit: Habit(name: "Morning meditation", frequency: .daily, type: .binary, createdAt: .now),
            isCompletedToday: true,
            onToggle: {}
        )
        HabitRowView(
            habit: Habit(name: "Drink water", frequency: .daily, type: .counter(target: 8), createdAt: .now),
            isCompletedToday: false,
            onToggle: nil,
            todayValue: 3
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
    .preferredColorScheme(.dark)
}
