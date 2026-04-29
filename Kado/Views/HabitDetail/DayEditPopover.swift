import SwiftUI
import KadoCore

/// Anchored popover that edits one day's completion for a habit from
/// the detail view's monthly calendar. Branches on `habit.type`:
/// single toggle for binary / negative, stepper for counter, minute
/// stepper for timer. Counter / timer also offer a `Clear` action
/// that sets the value to 0 (deleting the record via the logger).
/// All types show an optional note field below the main control.
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

    @State private var counterValue: Int = 0
    @State private var timerMinutes: Int = 0
    @State private var noteText: String = ""
    @State private var isNoteExpanded: Bool = false
    @FocusState private var isNoteFocused: Bool

    private let noteCharLimit = 500

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

    private func counterControl(target: Int) -> some View {
        let maxValue = max(target * 3, 99)
        return VStack(alignment: .leading, spacing: 12) {
            Stepper(
                value: Binding(
                    get: { counterValue },
                    set: { newValue in
                        counterValue = newValue
                        onSetCounter(Double(newValue))
                    }
                ),
                in: 0...maxValue,
                step: 1
            ) {
                Text("\(counterValue) of \(target)")
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(counterValue >= target ? Color.accentColor : Color.primary)
            }
            clearButton(shown: counterValue > 0)
        }
    }

    private func timerControl(targetMinutes: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Stepper(
                value: Binding(
                    get: { timerMinutes },
                    set: { newValue in
                        timerMinutes = newValue
                        onSetTimerSeconds(TimeInterval(newValue) * 60)
                    }
                ),
                in: 0...480,
                step: 1
            ) {
                Text("\(timerMinutes) of \(targetMinutes) min")
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(timerMinutes >= targetMinutes ? Color.accentColor : Color.primary)
            }
            clearButton(shown: timerMinutes > 0)
        }
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

    private func seedLocalState() {
        switch habit.type {
        case .counter:
            counterValue = Int(currentValue.rounded())
        case .timer:
            timerMinutes = currentValue > 0
                ? max(1, Int((currentValue / 60).rounded()))
                : 0
        case .binary, .negative:
            break
        }
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
