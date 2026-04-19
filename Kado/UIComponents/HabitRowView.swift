import SwiftUI
import KadoCore

/// A single row in the Today list. Three regions:
/// - **Leading**: 38pt circular badge — fills with the habit color when
///   the day's target is met; otherwise shows an outlined ring with a
///   trim arc representing today's progress (counter/timer only).
/// - **Center**: habit name on top; below, a "🔥 streak · score%"
///   caption that surfaces the per-row metrics that previously only
///   lived on Detail.
/// - **Trailing**: type-aware control. Binary, counter, and timer
///   share a 28pt-circle icon vocabulary (checkmark, `−` / `+`,
///   `+5m`). Negative is the deliberate exception — it keeps a
///   text "Slipped" pill so a slip never reads as a "done"
///   achievement at a glance. In every case the *filled* variant
///   is the recorded state and the tinted / outlined variant is
///   the ready-to-record state.
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
    /// Timer: add five minutes to today's session. `nil` for other types.
    var onTimerAddFiveMinutes: (() -> Void)? = nil
    /// Context-menu actions. Caller decides which apply per habit type
    /// — passing `nil` hides the corresponding menu item.
    var onLogSpecificValue: (() -> Void)? = nil
    var onOpenDetail: (() -> Void)? = nil
    var onEdit: (() -> Void)? = nil
    var onArchive: (() -> Void)? = nil

    private var isComplete: Bool { state.status == .complete }

    var body: some View {
        HStack(spacing: 12) {
            leadingBadge
                .frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text(habit.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.kadoForeground)
                    .lineLimit(1)
                    .truncationMode(.tail)
                metricsLine
            }
            Spacer(minLength: 8)
            trailingControl
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .contextMenu { contextMenuContent }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabelText)
        .accessibilityValue(accessibilityValueText)
        .accessibilityActions { rowAccessibilityActions }
    }

    /// VoiceOver picks these up via the Actions rotor. The row's
    /// default activate stays "navigate to detail" (the
    /// `NavigationLink` parent supplies it); these expose the pill /
    /// stepper / chip actions that `.combine` would otherwise hide.
    @ViewBuilder
    private var rowAccessibilityActions: some View {
        if let onToggle {
            Button(
                isComplete
                    ? String(localized: "Mark as not done")
                    : String(localized: "Mark as done"),
                action: onToggle
            )
        }
        if let onCounterIncrement {
            Button(String(localized: "Increment"), action: onCounterIncrement)
        }
        if let onCounterDecrement, canDecrement {
            Button(String(localized: "Decrement"), action: onCounterDecrement)
        }
        if let onTimerAddFiveMinutes {
            Button(String(localized: "Add 5 minutes"), action: onTimerAddFiveMinutes)
        }
        if let onLogSpecificValue {
            Button(String(localized: "Log specific value…"), action: onLogSpecificValue)
        }
        if let onEdit {
            Button(String(localized: "Edit"), action: onEdit)
        }
        if let onArchive {
            Button(String(localized: "Archive"), action: onArchive)
        }
    }

    @ViewBuilder
    private var contextMenuContent: some View {
        if let onLogSpecificValue {
            Button(action: onLogSpecificValue) {
                Label("Log specific value…", systemImage: "square.and.pencil")
            }
        }
        if let onOpenDetail {
            Button(action: onOpenDetail) {
                Label("Open detail", systemImage: "arrow.right")
            }
        }
        if let onEdit {
            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
            }
        }
        if let onArchive {
            Button(role: .destructive, action: onArchive) {
                Label("Archive", systemImage: "archivebox")
            }
        }
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
        .animation(KadoMotion.base, value: state.progress)
        .animation(KadoMotion.base, value: isComplete)
    }

    // MARK: - Metrics line

    private var metricsLine: some View {
        MetricsChip(streak: streak, scorePercent: scorePercent)
    }

    // MARK: - Trailing control

    @ViewBuilder
    private var trailingControl: some View {
        switch habit.type {
        case .binary:
            binaryCheckButton
        case .negative:
            negativePill
        case .counter(let target):
            counterStepper(target: target)
        case .timer(let targetSeconds):
            timerAddFiveChip(target: targetSeconds)
        }
    }

    // MARK: - Timer chip

    /// Trailing `+5m` quick-log chip. Tap adds five minutes to today's
    /// session — the fast-path power-user action. The leading ring
    /// communicates progress; the full session editor (existing
    /// `TimerLogSheet`) is reachable from the row's context menu via
    /// "Log specific value…".
    @ViewBuilder
    private func timerAddFiveChip(target: TimeInterval) -> some View {
        if let onTimerAddFiveMinutes {
            Button(action: onTimerAddFiveMinutes) {
                Text("+5m")
                    .font(.callout.weight(.semibold).monospacedDigit())
                    .padding(.vertical, 4)
                    .padding(.horizontal, 10)
                    .background(
                        Capsule().fill(habit.color.color.opacity(0.15))
                    )
                    .foregroundStyle(habit.color.color)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(String(localized: "Add 5 minutes"))
            .sensoryFeedback(.success, trigger: isComplete) { old, new in
                !old && new
            }
        }
    }

    @ViewBuilder
    private var binaryCheckButton: some View {
        if let onToggle {
            Button(action: onToggle) {
                checkCircle(
                    icon: "checkmark",
                    tint: habit.color.color,
                    filled: isComplete
                )
            }
            .buttonStyle(.borderless)
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
            // Outlined when *not* slipped (calm, ready); filled red
            // with a checkmark when slipped today (recorded).
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

    /// Shared 28pt-circle treatment for the binary trailing button.
    /// Tinted-fill background when the day isn't recorded yet;
    /// full-saturation fill with white icon when it is. Matches the
    /// counter `+` button styling exactly so the row's trailing
    /// region reads as one cohesive icon strip.
    private func checkCircle(icon: String, tint: Color, filled: Bool) -> some View {
        Image(systemName: icon)
            .font(.callout.weight(.semibold))
            .frame(width: 28, height: 28)
            .background(Circle().fill(filled ? tint : tint.opacity(0.15)))
            .foregroundStyle(filled ? Color.white : tint)
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
                    .background(Circle().fill(Color.kadoPaper200))
                    .foregroundStyle(canDecrement ? Color.kadoForeground : Color.kadoForegroundSecondary)
            }
            .buttonStyle(.borderless)
            .disabled(!canDecrement)
            .accessibilityLabel(String(localized: "Decrement"))

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

    private var canDecrement: Bool {
        (state.valueToday ?? 0) > 0
    }

    // MARK: - Formatting helpers

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

    /// Value-only progress phrase for counter / timer rows. Empty for
    /// binary / negative (their state lives in `accessibilityLabel`).
    /// Surfaced here because the visual `value/target` text was
    /// removed in favor of the leading progress ring — VoiceOver
    /// users still need the numbers.
    private var accessibilityProgressText: String {
        switch habit.type {
        case .binary, .negative:
            return ""
        case .counter(let target):
            let v = Int(state.valueToday ?? 0)
            return String(localized: "\(v) of \(Int(target))")
        case .timer(let targetSeconds):
            let v = Int((state.valueToday ?? 0) / 60)
            let t = Int(targetSeconds / 60)
            return String(localized: "\(v) of \(t) minutes")
        }
    }

    private var accessibilityValueText: String {
        let progress = accessibilityProgressText
        if progress.isEmpty {
            if streak > 0 {
                return String(localized: "Streak \(streak), score \(scorePercent) percent")
            }
            return String(localized: "Score \(scorePercent) percent")
        }
        if streak > 0 {
            return String(localized: "\(progress), streak \(streak), score \(scorePercent) percent")
        }
        return String(localized: "\(progress), score \(scorePercent) percent")
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
