import SwiftData
import SwiftUI
import KadoCore

/// Modal sheet for logging a timer habit's session duration in
/// minutes, typed on a number pad (issue #100). Replaces today's
/// completion on save (single-record-per-day invariant); saving `0`
/// clears it, the way the counter sheet and the day popover do.
struct TimerLogSheet: View {
    let habit: HabitRecord

    @Environment(\.modelContext) private var modelContext
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale
    @Environment(\.today) private var today
    @Environment(\.dayBoundary) private var dayBoundary
    @Environment(\.dismiss) private var dismiss

    /// What the field holds, as typed. Prefilled lazily in `.onAppear`
    /// so the env calendar (not the unrelated `.current`) drives
    /// today-completion lookup. `nil` before first render.
    @State private var text: String?
    @State private var saveTick = 0

    /// A day's worth of minutes. The stepper stopped at eight hours,
    /// which was about how far anyone would tap; typed, the only
    /// bound that means anything is the physical one.
    static let minutesRange = 0...1_440

    private var entry: WholeNumberEntry {
        WholeNumberEntry(locale: locale)
    }

    /// What the field spells, whether or not it is in range.
    private var typedMinutes: Int? {
        text.flatMap(entry.value(from:))
    }

    /// What Save writes, and nil whenever Save is disabled — see the
    /// matching note on `CounterLogSheet`. Rejecting rather than
    /// clamping also keeps a day that already holds a longer session
    /// (an import, say) from being truncated to the cap by opening
    /// this sheet and saving without typing anything.
    private var minutes: Int? {
        typedMinutes.flatMap { Self.minutesRange.contains($0) ? $0 : nil }
    }

    private var isOutOfRange: Bool {
        typedMinutes.map { !Self.minutesRange.contains($0) } ?? false
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(alignment: .firstTextBaseline) {
                        WholeNumberField(
                            title: "Session length",
                            text: Binding(
                                get: { text ?? "" },
                                set: { text = $0 }
                            )
                        )
                        .accessibilityIdentifier(AccessibilityID.LogSheet.timerField)
                        .font(.title2.weight(.semibold).monospacedDigit())
                        Text("min")
                            .foregroundStyle(Color.kadoForegroundSecondary)
                    }
                } header: {
                    Text("Session length")
                } footer: {
                    if isOutOfRange {
                        Text("Enter a number no higher than \(Self.minutesRange.upperBound).")
                    } else {
                        Text("Saves as today's completion. If you already logged a session today, it will be replaced. Setting it to 0 clears it.")
                    }
                }
                .listRowBackground(Color.kadoBackgroundSecondary)
            }
            .scrollContentBackground(.hidden)
            .background(Color.kadoBackground.ignoresSafeArea())
            .navigationTitle(Text("Log session"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier(AccessibilityID.LogSheet.cancelButton)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(minutes == nil)
                        .accessibilityIdentifier(AccessibilityID.LogSheet.saveButton)
                }
            }
            // The number pad has no return key on iPhone; this is for
            // iPad and hardware keyboards.
            .onSubmit { save() }
            .sensoryFeedback(.success, trigger: saveTick)
            .onAppear {
                if text == nil { text = entry.text(for: defaultMinutes()) }
            }
        }
    }

    private func defaultMinutes() -> Int {
        let existing = habit.completions?.first {
            calendar.isDate($0.date, inSameDayAs: today)
        }
        if let existing {
            // The day's own value, 0 included — not floored to 1. A
            // record can hold zero seconds (a standalone note, or a
            // session shorter than half a minute), and flooring it
            // meant opening this sheet and saving wrote a minute onto
            // a day that had none.
            return Int((existing.value / 60).rounded())
        }
        switch habit.type {
        case .timer(let seconds): return max(1, Int((seconds / 60).rounded()))
        default: return 10
        }
    }

    private func save() {
        guard let minutes else { return }
        let logger = CompletionLogger(calendar: calendar)
        let instant = dayBoundary.loggingInstant(for: .now, on: today)
        if minutes == 0 {
            // `logTimerSession` would keep a zero-second record; clearing
            // returns the day to missed, as stepping the popover to 0 does.
            logger.clear(for: habit, on: instant, in: modelContext)
        } else {
            logger.logTimerSession(
                for: habit,
                seconds: TimeInterval(minutes) * 60,
                on: instant,
                in: modelContext
            )
        }
        try? modelContext.save()
        WidgetReloader.reloadAll(using: modelContext)
        saveTick += 1
        dismiss()
    }
}

#Preview {
    TimerLogSheet(
        habit: HabitRecord(
            name: "Read",
            frequency: .daily,
            type: .timer(targetSeconds: 30 * 60)
        )
    )
    .modelContainer(PreviewContainer.emptyContainer())
}

#Preview("Dark") {
    TimerLogSheet(
        habit: HabitRecord(
            name: "Read",
            frequency: .daily,
            type: .timer(targetSeconds: 30 * 60)
        )
    )
    .modelContainer(PreviewContainer.emptyContainer())
    .preferredColorScheme(.dark)
}
