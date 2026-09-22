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

    /// Nil while the field holds no number, which disables Save.
    private var minutes: Int? {
        text.flatMap(entry.value(from:))
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
                    Text("Saves as today's completion. If you already logged a session today, it will be replaced. Setting it to 0 clears it.")
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
            return max(1, Int((existing.value / 60).rounded()))
        }
        switch habit.type {
        case .timer(let seconds): return max(1, Int((seconds / 60).rounded()))
        default: return 10
        }
    }

    private func save() {
        guard let minutes else { return }
        let clamped = min(max(minutes, Self.minutesRange.lowerBound), Self.minutesRange.upperBound)
        let logger = CompletionLogger(calendar: calendar)
        let instant = dayBoundary.loggingInstant(for: .now, on: today)
        if clamped == 0 {
            // `logTimerSession` would keep a zero-second record; clearing
            // returns the day to missed, as stepping the popover to 0 does.
            logger.clear(for: habit, on: instant, in: modelContext)
        } else {
            logger.logTimerSession(
                for: habit,
                seconds: TimeInterval(clamped) * 60,
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
