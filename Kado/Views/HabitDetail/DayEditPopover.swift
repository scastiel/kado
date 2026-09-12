import SwiftUI
import KadoCore

/// Anchored popover that edits one day's completion for a habit from
/// the detail view's monthly calendar. Branches on `habit.type`:
/// single toggle for binary / negative, `−` / `+` for counter, the
/// same in minutes for timer. Counter / timer also offer a `Clear`
/// action that sets the value to 0 (deleting the record via the
/// logger). All types show an optional note field below the main
/// control.
///
/// The value is rendered straight from `currentValue` and stepped
/// through the callbacks — no local copy. The first version mirrored
/// it into `@State` seeded once in `.onAppear` and drove that through a
/// `Stepper`, which meant two sources of truth for one number; when the
/// detail screen behind it stopped refreshing (issue #80) the mirror
/// was all that kept the display moving, and nothing said they had
/// drifted. `CounterQuickLogView` and the Today row have always been
/// stateless like this. The note *is* a local draft the user is typing,
/// so `noteText` stays.
struct DayEditPopover: View {
    let habit: Habit
    let date: Date
    let currentValue: Double
    let currentNote: String?
    let onToggle: () -> Void
    let onSetCounter: (Double) -> Void
    let onSetTimerSeconds: (TimeInterval) -> Void
    let onClear: () -> Void
    let onNoteChanged: (String?) -> Void

    @Environment(\.calendar) private var calendar
    @Environment(\.dismiss) private var dismiss

    @State private var noteText: String = ""
    @State private var isNoteExpanded: Bool = false
    @FocusState private var isNoteFocused: Bool

    private let noteCharLimit = 500

    /// The `−` / `+` circles follow Dynamic Type with the glyph inside
    /// them; a fixed 36pt left the symbol spilling past its fill at the
    /// accessibility sizes.
    @ScaledMetric(relativeTo: .body) private var stepButtonSize: CGFloat = 36

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            content
            noteSection
        }
        .padding()
        .frame(minWidth: 260, idealWidth: 300, maxWidth: 340)
        .onAppear { seedLocalState() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: habit.icon)
                    .foregroundStyle(habit.color.color)
                Text(habit.name)
                    .font(.headline)
            }
            Text(formattedDate)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch habit.type {
        case .binary:
            binaryToggle
        case .negative:
            negativeToggle
        case .counter(let target):
            counterControl(target: Int(target))
        case .timer(let seconds):
            timerControl(targetMinutes: max(1, Int((seconds / 60).rounded())))
        }
    }

    private var isRecorded: Bool { currentValue > 0 }

    private var binaryToggle: some View {
        Button {
            onToggle()
            if !isNoteExpanded {
                dismiss()
            }
        } label: {
            toggleLabel(
                title: isRecorded
                    ? String(localized: "Mark as not done")
                    : String(localized: "Mark as done"),
                systemImage: isRecorded ? "xmark.circle" : "checkmark.circle.fill",
                active: !isRecorded
            )
        }
        .buttonStyle(.plain)
    }

    private var negativeToggle: some View {
        Button {
            onToggle()
            if !isNoteExpanded {
                dismiss()
            }
        } label: {
            toggleLabel(
                title: isRecorded
                    ? String(localized: "Mark as not slipped")
                    : String(localized: "Mark as slipped"),
                systemImage: isRecorded ? "xmark.circle" : "hand.raised.fill",
                active: !isRecorded
            )
        }
        .buttonStyle(.plain)
    }

    private func toggleLabel(title: String, systemImage: String, active: Bool) -> some View {
        Label(title, systemImage: systemImage)
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(active ? Color.accentColor : Color.kadoBackgroundSecondary)
            )
            .foregroundStyle(active ? Color.white : Color.primary)
    }

    /// Same ceiling the `Stepper` used to enforce: well past any
    /// sensible target, but bounded.
    private func counterControl(target: Int) -> some View {
        let value = Int(currentValue.rounded())
        let maxValue = max(target * 3, 99)
        return VStack(alignment: .leading, spacing: 12) {
            stepRow(
                label: Text("\(value) of \(target)"),
                value: value,
                reached: value >= target,
                canDecrement: value > 0,
                canIncrement: value < maxValue,
                onDecrement: { onSetCounter(Double(value - 1)) },
                onIncrement: { onSetCounter(Double(value + 1)) }
            )
            clearButton(shown: value > 0)
        }
    }

    /// Minutes, rounded the way the old seeding did: anything logged
    /// reads as at least one minute, nothing logged reads as zero.
    private func timerControl(targetMinutes: Int) -> some View {
        let minutes = currentValue > 0
            ? max(1, Int((currentValue / 60).rounded()))
            : 0
        return VStack(alignment: .leading, spacing: 12) {
            stepRow(
                label: Text("\(minutes) of \(targetMinutes) min"),
                value: minutes,
                reached: minutes >= targetMinutes,
                canDecrement: minutes > 0,
                canIncrement: minutes < 480,
                // The parent routes zero seconds through `clear`, so
                // stepping down from one minute empties the day.
                onDecrement: { onSetTimerSeconds(TimeInterval(minutes - 1) * 60) },
                onIncrement: { onSetTimerSeconds(TimeInterval(minutes + 1) * 60) }
            )
            clearButton(shown: minutes > 0)
        }
    }

    /// The value with `−` and `+` beside it — `CounterQuickLogView`'s
    /// language at popover scale. `label` is built by the caller so the
    /// two catalog keys ("%lld of %lld", "%lld of %lld min") stay where
    /// they were.
    ///
    /// Side by side while it fits; once the scaled circles and a large
    /// label outgrow the popover's width, the pair drops under the
    /// value instead of clipping. The value itself is VoiceOver
    /// adjustable — focus "3 of 8", swipe up or down — which is what
    /// the `Stepper` used to give for free; the buttons stay separate
    /// elements for Switch Control and the UI suite.
    private func stepRow(
        label: Text,
        value: Int,
        reached: Bool,
        canDecrement: Bool,
        canIncrement: Bool,
        onDecrement: @escaping () -> Void,
        onIncrement: @escaping () -> Void
    ) -> some View {
        let valueText = label
            .font(.title3.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(reached ? Color.accentColor : Color.primary)
            .accessibilityIdentifier(AccessibilityID.HabitDetail.DayEdit.value)
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: if canIncrement { onIncrement() }
                case .decrement: if canDecrement { onDecrement() }
                @unknown default: break
                }
            }
        let buttons = HStack(spacing: 4) {
            stepButton(
                systemImage: "minus",
                enabled: canDecrement,
                fill: Color.kadoPaper200,
                tint: Color.kadoForeground,
                label: String(localized: "Decrement"),
                identifier: AccessibilityID.HabitDetail.DayEdit.decrement,
                action: onDecrement
            )
            stepButton(
                systemImage: "plus",
                enabled: canIncrement,
                fill: Color.accentColor.opacity(0.15),
                tint: Color.accentColor,
                label: String(localized: "Increment"),
                identifier: AccessibilityID.HabitDetail.DayEdit.increment,
                action: onIncrement
            )
        }
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                valueText
                Spacer(minLength: 0)
                buttons
            }
            VStack(alignment: .leading, spacing: 8) {
                valueText
                buttons
            }
        }
    }

    /// A 36pt circle (scaled) inside a hit area that never drops below
    /// the 44pt HIG minimum — the quick-log's circles are 44pt outright;
    /// here the popover is tighter, so the target is padding.
    private func stepButton(
        systemImage: String,
        enabled: Bool,
        fill: Color,
        tint: Color,
        label: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .frame(width: stepButtonSize, height: stepButtonSize)
                .background(Circle().fill(fill))
                .foregroundStyle(enabled ? tint : Color.kadoForegroundSecondary)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }

    @ViewBuilder
    private func clearButton(shown: Bool) -> some View {
        if shown {
            Button(role: .destructive) {
                onClear()
                dismiss()
            } label: {
                Text("Clear")
                    .font(.body.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .accessibilityIdentifier(AccessibilityID.HabitDetail.DayEdit.clear)
        }
    }

    // MARK: - Note

    @ViewBuilder
    private var noteSection: some View {
        if isNoteExpanded {
            VStack(alignment: .leading, spacing: 6) {
                TextField(
                    String(localized: "Add a note..."),
                    text: $noteText,
                    axis: .vertical
                )
                .lineLimit(1...4)
                .font(.callout)
                .focused($isNoteFocused)
                .accessibilityLabel(String(localized: "Note"))
                .onChange(of: noteText) { _, newValue in
                    if newValue.count > noteCharLimit {
                        noteText = String(newValue.prefix(noteCharLimit))
                    }
                }
                .onSubmit { commitNote() }

                HStack {
                    Text("\(noteText.count)/\(noteCharLimit)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Button(String(localized: "Done")) { commitNote() }
                        .font(.caption.weight(.medium))
                }
            }
        } else {
            Button {
                isNoteExpanded = true
                isNoteFocused = true
            } label: {
                Label(
                    currentNote ?? String(localized: "Add a note..."),
                    systemImage: "note.text"
                )
                .font(.callout)
                .foregroundStyle(currentNote != nil ? .primary : .secondary)
                .lineLimit(1)
            }
            .buttonStyle(.plain)
        }
    }

    private func commitNote() {
        isNoteFocused = false
        let trimmed = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        onNoteChanged(trimmed.isEmpty ? nil : trimmed)
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale ?? .current
        formatter.dateStyle = .full
        return formatter.string(from: date)
    }

    /// Only the note draft is local state — see the type comment.
    private func seedLocalState() {
        noteText = currentNote ?? ""
        isNoteExpanded = currentNote != nil
    }
}

#Preview("Binary — not done") {
    DayEditPopover(
        habit: Habit(
            name: "Morning meditation",
            frequency: .daily,
            type: .binary,
            createdAt: .now,
            color: .purple,
            icon: "figure.mind.and.body"
        ),
        date: Calendar.current.date(byAdding: .day, value: -1, to: .now)!,
        currentValue: 0,
        currentNote: nil,
        onToggle: {},
        onSetCounter: { _ in },
        onSetTimerSeconds: { _ in },
        onClear: {},
        onNoteChanged: { _ in }
    )
}

#Preview("Binary — done") {
    DayEditPopover(
        habit: Habit(
            name: "Morning meditation",
            frequency: .daily,
            type: .binary,
            createdAt: .now,
            color: .purple,
            icon: "figure.mind.and.body"
        ),
        date: Calendar.current.date(byAdding: .day, value: -1, to: .now)!,
        currentValue: 1,
        currentNote: nil,
        onToggle: {},
        onSetCounter: { _ in },
        onSetTimerSeconds: { _ in },
        onClear: {},
        onNoteChanged: { _ in }
    )
}

#Preview("Binary — with note") {
    DayEditPopover(
        habit: Habit(
            name: "Morning meditation",
            frequency: .daily,
            type: .binary,
            createdAt: .now,
            color: .purple,
            icon: "figure.mind.and.body"
        ),
        date: Calendar.current.date(byAdding: .day, value: -1, to: .now)!,
        currentValue: 1,
        currentNote: "20 minutes, felt very focused today",
        onToggle: {},
        onSetCounter: { _ in },
        onSetTimerSeconds: { _ in },
        onClear: {},
        onNoteChanged: { _ in }
    )
}

#Preview("Negative — not slipped") {
    DayEditPopover(
        habit: Habit(
            name: "No smoking",
            frequency: .daily,
            type: .negative,
            createdAt: .now,
            color: .red,
            icon: "smoke.fill"
        ),
        date: Calendar.current.date(byAdding: .day, value: -1, to: .now)!,
        currentValue: 0,
        currentNote: nil,
        onToggle: {},
        onSetCounter: { _ in },
        onSetTimerSeconds: { _ in },
        onClear: {},
        onNoteChanged: { _ in }
    )
}

#Preview("Counter — partial") {
    DayEditPopover(
        habit: Habit(
            name: "Drink water",
            frequency: .daily,
            type: .counter(target: 8),
            createdAt: .now,
            color: .blue,
            icon: "drop.fill"
        ),
        date: Calendar.current.date(byAdding: .day, value: -2, to: .now)!,
        currentValue: 5,
        currentNote: nil,
        onToggle: {},
        onSetCounter: { _ in },
        onSetTimerSeconds: { _ in },
        onClear: {},
        onNoteChanged: { _ in }
    )
}

#Preview("Counter — with note") {
    DayEditPopover(
        habit: Habit(
            name: "Drink water",
            frequency: .daily,
            type: .counter(target: 8),
            createdAt: .now,
            color: .blue,
            icon: "drop.fill"
        ),
        date: Calendar.current.date(byAdding: .day, value: -2, to: .now)!,
        currentValue: 6,
        currentNote: "Included 2 glasses of sparkling water",
        onToggle: {},
        onSetCounter: { _ in },
        onSetTimerSeconds: { _ in },
        onClear: {},
        onNoteChanged: { _ in }
    )
}

#Preview("Timer — empty") {
    DayEditPopover(
        habit: Habit(
            name: "Read",
            frequency: .daily,
            type: .timer(targetSeconds: 30 * 60),
            createdAt: .now,
            color: .orange,
            icon: "book.fill"
        ),
        date: Calendar.current.date(byAdding: .day, value: -3, to: .now)!,
        currentValue: 0,
        currentNote: nil,
        onToggle: {},
        onSetCounter: { _ in },
        onSetTimerSeconds: { _ in },
        onClear: {},
        onNoteChanged: { _ in }
    )
}

#Preview("Counter — partial · Dark") {
    DayEditPopover(
        habit: Habit(
            name: "Drink water",
            frequency: .daily,
            type: .counter(target: 8),
            createdAt: .now,
            color: .blue,
            icon: "drop.fill"
        ),
        date: Calendar.current.date(byAdding: .day, value: -2, to: .now)!,
        currentValue: 5,
        currentNote: "Almost hit the target!",
        onToggle: {},
        onSetCounter: { _ in },
        onSetTimerSeconds: { _ in },
        onClear: {},
        onNoteChanged: { _ in }
    )
    .preferredColorScheme(.dark)
}
