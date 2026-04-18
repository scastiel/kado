import SwiftUI

/// A single row in the Today list. Three regions:
/// - **Leading**: 38pt circular badge — fills with the habit color when
///   the day's target is met; otherwise shows an outlined ring with a
///   trim arc representing today's progress (counter/timer only).
/// - **Center**: habit name on top; below, a "🔥 streak · score%"
///   caption that surfaces the per-row metrics that previously only
///   lived on Detail.
/// - **Trailing**: type-aware action. Binary uses a "Mark done" pill
///   that flips to a checkmark capsule when complete. Negative uses a
///   red "Slipped" pill with the same shape. Counter and timer keep
///   their text-only labels in this iteration; subsequent commits
///   replace them with an inline stepper and a "+5m" chip.
struct HabitRowView: View {
    let habit: Habit
    let state: HabitRowState
    let streak: Int
    let scorePercent: Int
    /// Binary / negative: fires the toggle. `nil` for counter / timer.
    let onToggle: (() -> Void)?
    /// Counter: increment / decrement today's value by 1. `nil` for
    /// other types.
    var onCounterIncrement: (() -> Void)? = nil
    var onCounterDecrement: (() -> Void)? = nil

    private var isComplete: Bool { state.status == .complete }

    var body: some View {
        HStack(spacing: 12) {
            leadingBadge
                .frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text(habit.name)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                metricsLine
            }
            Spacer(minLength: 8)
            trailingControl
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabelText)
        .accessibilityValue(accessibilityValueText)
    }

    // MARK: - Leading badge

    private var leadingBadge: some View {
        ZStack {
            if isComplete {
                Circle().fill(habit.color.color)
            } else {
                Circle()
                    .strokeBorder(habit.color.color.opacity(0.25), lineWidth: 2)
                Circle()
                    .trim(from: 0, to: state.progress)
                    .stroke(
                        habit.color.color,
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
            }
            Image(systemName: habit.icon)
                .font(.callout.weight(.semibold))
                .foregroundStyle(isComplete ? Color.white : habit.color.color)
        }
        .animation(.easeOut(duration: 0.2), value: state.progress)
        .animation(.easeOut(duration: 0.2), value: isComplete)
    }

    // MARK: - Metrics line

    @ViewBuilder
    private var metricsLine: some View {
        HStack(spacing: 6) {
            if streak > 0 {
                Label("\(streak)", systemImage: "flame.fill")
                    .labelStyle(.titleAndIcon)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.orange)
                Text("·")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text("\(scorePercent)%")
                .font(.caption2.weight(.semibold).monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Trailing control

    @ViewBuilder
    private var trailingControl: some View {
        switch habit.type {
        case .binary:
            binaryPill
        case .negative:
            negativePill
        case .counter(let target):
            counterStepper(target: target)
        case .timer(let targetSeconds):
            Text(timerLabel(target: targetSeconds))
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var binaryPill: some View {
        if let onToggle {
            Button(action: onToggle) {
                if isComplete {
                    Label("Done", systemImage: "checkmark")
                        .labelStyle(.titleAndIcon)
                } else {
                    Text("Mark done")
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(isComplete ? habit.color.color : Color.accentColor)
            .controlSize(.small)
            .sensoryFeedback(.success, trigger: state.status)
            .accessibilityLabel(
                isComplete
                    ? String(localized: "Mark as not done")
                    : String(localized: "Mark as done")
            )
        }
    }

    @ViewBuilder
    private var negativePill: some View {
        if let onToggle {
            Button(action: onToggle) {
                if isComplete {
                    Label("Slipped", systemImage: "checkmark")
                        .labelStyle(.titleAndIcon)
                } else {
                    Text("Slipped")
                }
            }
            // Outlined when *not* slipped (good day, calm affordance);
            // filled red + checkmark when slipped today (recorded).
            .modifier(NegativePillStyleModifier(isSlipped: isComplete))
            .controlSize(.small)
            .sensoryFeedback(.success, trigger: state.status)
            .accessibilityLabel(
                isComplete
                    ? String(localized: "Mark as not done")
                    : String(localized: "Mark as done")
            )
        }
    }

    // MARK: - Counter stepper

    /// Inline `−  value/target  +` stepper. Collapses to `value/target +`
    /// (no minus) when the row width can't host both buttons — the
    /// usual case at Dynamic Type XXL+ where the labels grow large.
    /// Decrement is disabled at zero so "no completion" stays equivalent
    /// to "not started today" (matches CompletionLogger semantics).
    @ViewBuilder
    private func counterStepper(target: Double) -> some View {
        ViewThatFits(in: .horizontal) {
            counterStepperFull(target: target)
            counterStepperPlusOnly(target: target)
        }
        .sensoryFeedback(.success, trigger: isComplete) { old, new in
            !old && new
        }
    }

    private func counterStepperFull(target: Double) -> some View {
        HStack(spacing: 8) {
            Button(action: { onCounterDecrement?() }) {
                Image(systemName: "minus")
                    .font(.callout.weight(.semibold))
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color(.secondarySystemFill)))
                    .foregroundStyle(canDecrement ? Color.primary : Color.secondary)
            }
            .buttonStyle(.borderless)
            .disabled(!canDecrement)
            .accessibilityLabel(String(localized: "Decrement"))

            Text(counterLabel(target: target))
                .font(.callout.monospacedDigit())
                .foregroundStyle(isComplete ? habit.color.color : .secondary)

            Button(action: { onCounterIncrement?() }) {
                Image(systemName: "plus")
                    .font(.callout.weight(.semibold))
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(habit.color.color.opacity(0.15)))
                    .foregroundStyle(habit.color.color)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(String(localized: "Increment"))
        }
    }

    private func counterStepperPlusOnly(target: Double) -> some View {
        HStack(spacing: 8) {
            Text(counterLabel(target: target))
                .font(.callout.monospacedDigit())
                .foregroundStyle(isComplete ? habit.color.color : .secondary)

            Button(action: { onCounterIncrement?() }) {
                Image(systemName: "plus")
                    .font(.callout.weight(.semibold))
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(habit.color.color.opacity(0.15)))
                    .foregroundStyle(habit.color.color)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(String(localized: "Increment"))
        }
    }

    private var canDecrement: Bool {
        (state.valueToday ?? 0) > 0
    }

    // MARK: - Counter / timer labels (preserved from prior layout)

    private func counterLabel(target: Double) -> String {
        if let value = state.valueToday {
            return "\(Int(value))/\(Int(target))"
        }
        return "–/\(Int(target))"
    }

    private func timerLabel(target: TimeInterval) -> String {
        if let value = state.valueToday {
            return "\(formatSeconds(value)) / \(formatSeconds(target))"
        }
        return formatSeconds(target)
    }

    private func formatSeconds(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let minutes = total / 60
        let remaining = total % 60
        return String(format: "%d:%02d", minutes, remaining)
    }

    // MARK: - Accessibility

    private var accessibilityLabelText: String {
        switch habit.type {
        case .binary, .negative:
            let stateText = isComplete
                ? String(localized: "done")
                : String(localized: "not done")
            return String(localized: "\(habit.name), \(stateText)")
        case .counter(let target):
            return String(localized: "\(habit.name), counter, target \(Int(target))")
        case .timer(let targetSeconds):
            return String(localized: "\(habit.name), timer, target \(formatSeconds(targetSeconds))")
        }
    }

    private var accessibilityValueText: String {
        if streak > 0 {
            return String(localized: "Streak \(streak), score \(scorePercent) percent")
        }
        return String(localized: "Score \(scorePercent) percent")
    }
}

/// Conditional style swap — `.bordered` vs `.borderedProminent` aren't
/// the same opaque type, so a plain ternary doesn't compile. Using a
/// `ViewModifier` keeps the call site flat.
private struct NegativePillStyleModifier: ViewModifier {
    let isSlipped: Bool
    func body(content: Content) -> some View {
        if isSlipped {
            content
                .buttonStyle(.borderedProminent)
                .tint(.red)
        } else {
            content
                .buttonStyle(.bordered)
                .tint(.red)
        }
    }
}

// MARK: - Previews

private extension HabitRowView {
    static func previewState(for type: HabitType, value: Double? = nil) -> HabitRowState {
        switch type {
        case .binary, .negative:
            return value == nil
                ? HabitRowState(status: .none, progress: 0, valueToday: nil)
                : HabitRowState(status: .complete, progress: 1, valueToday: 1)
        case .counter(let target):
            guard let value else { return HabitRowState(status: .none, progress: 0, valueToday: nil) }
            let progress = min(value / target, 1)
            return HabitRowState(
                status: value >= target ? .complete : .partial,
                progress: progress,
                valueToday: value
            )
        case .timer(let targetSeconds):
            guard let value else { return HabitRowState(status: .none, progress: 0, valueToday: nil) }
            let progress = min(value / targetSeconds, 1)
            return HabitRowState(
                status: value >= targetSeconds ? .complete : .partial,
                progress: progress,
                valueToday: value
            )
        }
    }
}

#Preview("All types — not done") {
    let binary = Habit(name: "Morning meditation", frequency: .daily, type: .binary, createdAt: .now, color: .purple, icon: "figure.mind.and.body")
    let counter = Habit(name: "Drink water", frequency: .daily, type: .counter(target: 8), createdAt: .now, color: .blue, icon: "drop.fill")
    let timer = Habit(name: "Read", frequency: .daily, type: .timer(targetSeconds: 1800), createdAt: .now, color: .mint, icon: "book.fill")
    let negative = Habit(name: "No social media", frequency: .daily, type: .negative, createdAt: .now, color: .red, icon: "flame.fill")
    return List {
        HabitRowView(habit: binary, state: HabitRowView.previewState(for: binary.type), streak: 5, scorePercent: 72, onToggle: {})
        HabitRowView(habit: counter, state: HabitRowView.previewState(for: counter.type), streak: 0, scorePercent: 41, onToggle: nil)
        HabitRowView(habit: timer, state: HabitRowView.previewState(for: timer.type), streak: 12, scorePercent: 87, onToggle: nil)
        HabitRowView(habit: negative, state: HabitRowView.previewState(for: negative.type), streak: 3, scorePercent: 64, onToggle: {})
    }
}

#Preview("All types — complete") {
    let binary = Habit(name: "Morning meditation", frequency: .daily, type: .binary, createdAt: .now, color: .purple, icon: "figure.mind.and.body")
    let counter = Habit(name: "Drink water", frequency: .daily, type: .counter(target: 8), createdAt: .now, color: .blue, icon: "drop.fill")
    let timer = Habit(name: "Read", frequency: .daily, type: .timer(targetSeconds: 1800), createdAt: .now, color: .mint, icon: "book.fill")
    let negative = Habit(name: "No social media", frequency: .daily, type: .negative, createdAt: .now, color: .red, icon: "flame.fill")
    return List {
        HabitRowView(habit: binary, state: HabitRowView.previewState(for: binary.type, value: 1), streak: 6, scorePercent: 78, onToggle: {})
        HabitRowView(habit: counter, state: HabitRowView.previewState(for: counter.type, value: 8), streak: 4, scorePercent: 90, onToggle: nil)
        HabitRowView(habit: timer, state: HabitRowView.previewState(for: timer.type, value: 1800), streak: 14, scorePercent: 95, onToggle: nil)
        HabitRowView(habit: negative, state: HabitRowView.previewState(for: negative.type, value: 1), streak: 0, scorePercent: 30, onToggle: {})
    }
}

#Preview("Counter — partial / overshoot") {
    let counter = Habit(name: "Drink water", frequency: .daily, type: .counter(target: 8), createdAt: .now, color: .blue, icon: "drop.fill")
    let timer = Habit(name: "Read", frequency: .daily, type: .timer(targetSeconds: 1800), createdAt: .now, color: .mint, icon: "book.fill")
    return List {
        HabitRowView(habit: counter, state: HabitRowView.previewState(for: counter.type, value: 3), streak: 2, scorePercent: 55, onToggle: nil)
        HabitRowView(habit: counter, state: HabitRowView.previewState(for: counter.type, value: 12), streak: 7, scorePercent: 92, onToggle: nil)
        HabitRowView(habit: timer, state: HabitRowView.previewState(for: timer.type, value: 750), streak: 3, scorePercent: 60, onToggle: nil)
    }
}

#Preview("Dynamic Type XXXL") {
    let binary = Habit(name: "Morning meditation", frequency: .daily, type: .binary, createdAt: .now)
    let counter = Habit(name: "Drink water", frequency: .daily, type: .counter(target: 8), createdAt: .now)
    return List {
        HabitRowView(habit: binary, state: HabitRowView.previewState(for: binary.type, value: 1), streak: 6, scorePercent: 78, onToggle: {})
        HabitRowView(habit: counter, state: HabitRowView.previewState(for: counter.type, value: 3), streak: 2, scorePercent: 55, onToggle: nil)
    }
    .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Dark") {
    let binary = Habit(name: "Morning meditation", frequency: .daily, type: .binary, createdAt: .now)
    let counter = Habit(name: "Drink water", frequency: .daily, type: .counter(target: 8), createdAt: .now)
    let timer = Habit(name: "Read", frequency: .daily, type: .timer(targetSeconds: 1800), createdAt: .now)
    let negative = Habit(name: "No social media", frequency: .daily, type: .negative, createdAt: .now)
    return List {
        HabitRowView(habit: binary, state: HabitRowView.previewState(for: binary.type, value: 1), streak: 6, scorePercent: 78, onToggle: {})
        HabitRowView(habit: counter, state: HabitRowView.previewState(for: counter.type, value: 3), streak: 2, scorePercent: 55, onToggle: nil)
        HabitRowView(habit: timer, state: HabitRowView.previewState(for: timer.type, value: 1800), streak: 14, scorePercent: 95, onToggle: nil)
        HabitRowView(habit: negative, state: HabitRowView.previewState(for: negative.type, value: 1), streak: 0, scorePercent: 30, onToggle: {})
    }
    .preferredColorScheme(.dark)
}
