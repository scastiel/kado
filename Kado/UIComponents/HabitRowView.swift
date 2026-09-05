import SwiftUI
import KadoCore

/// A single row in the Today card. Three columns: a 38pt identity
/// mark, the name over a one-line caption, and one control.
///
/// **One control type per habit type, and every variant is 44pt tall.**
/// The previous row carried four different control vocabularies plus a
/// chevron, at three different heights, so no two rows lined up and the
/// eye had to re-learn the trailing edge on each one. Height is fixed
/// by construction here, not by whatever the content happened to
/// measure.
///
/// **Status is never a control.** A negative habit's slip shows as a
/// tag beside its name; the action slot keeps the same circle every
/// other binary habit has, so a slipped habit is still loggable. That
/// slot previously *was* the "Slipped" pill, which is why it wasn't.
///
/// **No chevron.** The whole row outside the control opens detail, so
/// the chevron only duplicated the affordance and stole width from the
/// caption.
struct HabitRowView: View {
    let habit: Habit
    let state: HabitRowState
    /// Pre-composed caption — see `TodayRowMeta`. Passed in rather
    /// than derived here because it needs the calendar and the habit's
    /// next due date, neither of which belongs in a row renderer.
    let meta: String
    /// Whether today's schedule asks for this habit. Drives the dashed
    /// control outline: "you may log this, but it doesn't count
    /// against today".
    var isScheduledToday: Bool = true
    /// Carried for VoiceOver only — the visible row says both through
    /// `meta`.
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
    /// Reordering. Lives in the menu because the card this row sits in
    /// is not a `List` and so has no drag handles; `nil` at the ends of
    /// a section hides the corresponding item rather than offering a
    /// no-op.
    var onMoveUp: (() -> Void)? = nil
    var onMoveDown: (() -> Void)? = nil
    var onEdit: (() -> Void)? = nil
    var onArchive: (() -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isComplete: Bool { state.status == .complete }

    private var isSlipped: Bool {
        if case .negative = habit.type { return isComplete }
        return false
    }

    var body: some View {
        HStack(spacing: 12) {
            // A Button rather than a NavigationLink: the trailing
            // control is itself a button, and SwiftUI does not deliver
            // taps to a button nested inside a link's label. The caller
            // pushes the route.
            Button { onOpenDetail?() } label: {
                HStack(spacing: 12) {
                    mark
                    titleAndMeta
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(onOpenDetail == nil)

            trailingControl
        }
        .padding(.vertical, 13)
        .contentShape(Rectangle())
        .contextMenu { contextMenuContent }
        .accessibilityElement(children: .combine)
        // Safe here precisely because `.combine` has already collapsed
        // the subtree: the row is one element, so this lands on a leaf
        // rather than stamping over anything. Keyed by id because the
        // name is both localized and user-editable.
        .accessibilityIdentifier(AccessibilityID.Today.row(habit.id))
        .accessibilityLabel(accessibilityLabelText)
        .accessibilityValue(accessibilityValueText)
        .accessibilityActions { rowAccessibilityActions }
    }

    // MARK: - Mark

    /// Identity only — no progress ring. Progress moved into the
    /// caption (`20/30 min`), which states it in numbers a ring can
    /// only approximate, and frees the mark to be the thing the eye
    /// uses to find a habit in the list.
    private var mark: some View {
        ZStack {
            Circle().fill(habit.color.color.opacity(KadoTint.mark))
            Image(systemName: habit.icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(habit.color.ink)
        }
        .frame(width: 38, height: 38)
    }

    // MARK: - Title + caption

    private var titleAndMeta: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(habit.name)
                    .font(.system(size: 17, weight: .semibold))
                    .kerning(-0.17)
                    .foregroundStyle(Color.kadoForeground)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if isSlipped {
                    slippedTag
                }
            }
            Text(meta)
                .font(.system(size: 13).monospacedDigit())
                .foregroundStyle(Color.kadoForegroundSecondary)
                // Truncate rather than wrap: every row in the card is
                // the same height by design, and one wrapped caption
                // would break the alignment for all of them.
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    private var slippedTag: some View {
        Text("Slipped")
            .font(.system(size: 11, weight: .bold))
            .textCase(.uppercase)
            .tracking(0.44)
            .foregroundStyle(habit.color.ink)
            .padding(.vertical, 2)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: KadoRadius.tag, style: .continuous)
                    .fill(habit.color.color.opacity(KadoTint.slippedTag))
            )
            .fixedSize()
    }

    // MARK: - Trailing control

    @ViewBuilder
    private var trailingControl: some View {
        switch habit.type {
        case .binary, .negative:
            binaryControl
        case .counter(let target):
            counterControl(target: target)
        case .timer:
            timerControl
        }
    }

    /// Variants 1–3 of the control vocabulary: filled when today is
    /// recorded, outlined when it is not, dashed when the schedule
    /// didn't ask for today at all.
    ///
    /// A negative habit deliberately never reaches the filled variant.
    /// A slip is not an achievement, and a white checkmark on a solid
    /// fill is what the rest of the card uses to mean "well done" — so
    /// the slip lives in the tag beside the name, and this slot stays
    /// the plain "log it" circle in both directions.
    @ViewBuilder
    private var binaryControl: some View {
        if let onToggle {
            Button(action: onToggle) {
                ZStack {
                    if isComplete && !isSlipped {
                        Circle().fill(habit.color.color)
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.kadoBackground)
                    } else {
                        Circle()
                            .strokeBorder(
                                habit.color.color.opacity(
                                    isScheduledToday ? KadoTint.outline : KadoTint.outlineDashed
                                ),
                                style: StrokeStyle(
                                    lineWidth: 2,
                                    dash: isScheduledToday ? [] : [4, 3]
                                )
                            )
                    }
                }
                .frame(width: 44, height: 44)
                .animation(reduceMotion ? nil : KadoMotion.base, value: isComplete)
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.success, trigger: state.status)
            .accessibilityLabel(toggleActionLabel)
        }
    }

    /// Variant 4. `min-width` keeps `+5m` from collapsing narrower
    /// than the binary circle beside it, so the trailing edge of the
    /// card stays a straight line.
    @ViewBuilder
    private var timerControl: some View {
        if let onTimerAddFiveMinutes {
            Button(action: onTimerAddFiveMinutes) {
                Text("+5m")
                    .font(.system(size: 16, weight: .bold).monospacedDigit())
                    .foregroundStyle(habit.color.ink)
                    .padding(.horizontal, 16)
                    .frame(minWidth: 62, minHeight: 44)
                    .background(
                        Capsule().fill(habit.color.color.opacity(KadoTint.timerPill))
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Add 5 minutes"))
            .sensoryFeedback(.success, trigger: isComplete) { old, new in
                !old && new
            }
        }
    }

    /// Variant 5. The `+` is filled and the `−` is bare on purpose:
    /// they are not equal actions. Incrementing is what the user came
    /// to do; decrementing is a correction, and giving it the same
    /// weight made the pill read as a two-way switch.
    @ViewBuilder
    private func counterControl(target: Double) -> some View {
        HStack(spacing: 0) {
            Button { onCounterDecrement?() } label: {
                Image(systemName: "minus")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(
                        canDecrement ? habit.color.ink : Color.kadoForegroundTertiary
                    )
                    .frame(width: 36, height: 36)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(!canDecrement)
            .accessibilityLabel(String(localized: "Decrement"))

            Text("\(Int(state.valueToday ?? 0))")
                .font(.system(size: 15, weight: .bold).monospacedDigit())
                .foregroundStyle(habit.color.ink)
                .frame(minWidth: 12)
                // Breathing room on both sides, so the value doesn't
                // sit flush against the filled `+` while floating away
                // from the bare `−`.
                .padding(.horizontal, 4)
                .contentTransition(.numericText())
                .animation(reduceMotion ? nil : KadoMotion.base, value: state.valueToday)

            Button { onCounterIncrement?() } label: {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.kadoBackground)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(habit.color.color))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Increment"))
        }
        .padding(4)
        .frame(minHeight: 44)
        .background(
            Capsule().fill(habit.color.color.opacity(KadoTint.counterPill))
        )
        .sensoryFeedback(.success, trigger: isComplete) { old, new in
            !old && new
        }
    }

    private var canDecrement: Bool {
        (state.valueToday ?? 0) > 0
    }

    // MARK: - Menus

    /// VoiceOver picks these up via the Actions rotor. The row's
    /// default activate stays "navigate to detail"; these expose the
    /// control actions that `.combine` would otherwise hide.
    @ViewBuilder
    private var rowAccessibilityActions: some View {
        if let onToggle {
            Button(toggleActionLabel, action: onToggle)
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
        if let onMoveUp {
            Button(String(localized: "Move up"), action: onMoveUp)
        }
        if let onMoveDown {
            Button(String(localized: "Move down"), action: onMoveDown)
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
        if onMoveUp != nil || onMoveDown != nil {
            Section {
                if let onMoveUp {
                    Button(action: onMoveUp) {
                        Label("Move up", systemImage: "arrow.up")
                    }
                }
                if let onMoveDown {
                    Button(action: onMoveDown) {
                        Label("Move down", systemImage: "arrow.down")
                    }
                }
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

    // MARK: - Accessibility

    /// A negative habit's toggle is a slip, not a completion — saying
    /// "Mark as done" for it would invert the meaning.
    private var toggleActionLabel: String {
        if case .negative = habit.type {
            return isComplete
                ? String(localized: "Mark as not slipped")
                : String(localized: "Mark as slipped")
        }
        return isComplete
            ? String(localized: "Mark as not done")
            : String(localized: "Mark as done")
    }

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

    private func formatSeconds(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let minutes = total / 60
        let remaining = total % 60
        return String(format: "%d:%02d", minutes, remaining)
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

/// The five rows of the design mock, in one card.
private struct RowPreviewCard: View {
    var body: some View {
        let meditation = Habit(name: "Morning meditation", frequency: .daily, type: .binary, createdAt: .now, color: .purple, icon: "figure.mind.and.body")
        let read = Habit(name: "Read", frequency: .daily, type: .timer(targetSeconds: 1800), createdAt: .now, color: .teal, icon: "book.fill")
        let social = Habit(name: "No social media", frequency: .daily, type: .negative, createdAt: .now, color: .red, icon: "flame.fill")
        let water = Habit(name: "Drink water", frequency: .daily, type: .counter(target: 8), createdAt: .now, color: .blue, icon: "drop.fill")
        let gym = Habit(name: "Gym", frequency: .daysPerWeek(3), type: .binary, createdAt: .now, color: .orange, icon: "dumbbell.fill")

        return ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HabitCard {
                    HabitRowView(habit: meditation, state: HabitRowView.previewState(for: meditation.type, value: 1), meta: "2-day streak · 43%", streak: 2, scorePercent: 43, onToggle: {}, onOpenDetail: {})
                    HabitRowView(habit: read, state: HabitRowView.previewState(for: read.type, value: 1200), meta: "20/30 min · 35%", streak: 0, scorePercent: 35, onToggle: nil, onTimerAddFiveMinutes: {}, onOpenDetail: {})
                    HabitRowView(habit: social, state: HabitRowView.previewState(for: social.type, value: 1), meta: "Streak reset · 41%", streak: 0, scorePercent: 41, onToggle: {}, onOpenDetail: {})
                    HabitRowView(habit: water, state: HabitRowView.previewState(for: water.type, value: 4), meta: "4/8 · 30%", streak: 2, scorePercent: 30, onToggle: nil, onCounterIncrement: {}, onCounterDecrement: {}, onOpenDetail: {})
                }
                HabitCard {
                    HabitRowView(habit: gym, state: HabitRowView.previewState(for: gym.type), meta: "Next Monday · 21%", isScheduledToday: false, streak: 0, scorePercent: 21, onToggle: {}, onOpenDetail: {})
                }
            }
            .padding(20)
        }
        .background(Color.kadoBackground)
    }
}

#Preview("Design mock rows") {
    RowPreviewCard()
}

#Preview("Dark") {
    RowPreviewCard()
        .preferredColorScheme(.dark)
}

#Preview("Dynamic Type XXXL") {
    RowPreviewCard()
        .environment(\.dynamicTypeSize, .accessibility3)
}
