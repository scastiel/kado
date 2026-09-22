import SwiftData
import SwiftUI
import KadoCore

/// Modal sheet for setting a counter habit's value to an exact number.
/// Reachable from the Today row's context menu — the row's `−/+`
/// stepper covers unit changes; this sheet covers "I forgot all day,
/// set it to 25". A number pad, not a second stepper: reaching 25
/// from 0 is two taps here and twenty-five on the row (issue #100).
/// Single-record-per-day invariant holds: saving `0` clears today's
/// completion.
struct CounterLogSheet: View {
    let habit: HabitRecord

    @Environment(\.modelContext) private var modelContext
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale
    @Environment(\.today) private var today
    @Environment(\.dayBoundary) private var dayBoundary
    @Environment(\.dismiss) private var dismiss

    /// What the field holds, as typed. Prefilled lazily in `.onAppear`
    /// so the env calendar (not `.current`) drives today-completion
    /// lookup; nil before first render. Matches `TimerLogSheet`.
    @State private var text: String?
    @State private var saveTick = 0

    /// The most a day can hold. Not a product limit any more — the
    /// stepper's `max(target * 4, 100)` capped what was worth tapping
    /// to, and 150 pages was over it — just a guard against one digit
    /// too many, since the row has to lay the number out.
    static let valueRange = 0...999_999

    private var target: Int {
        if case .counter(let t) = habit.type { return Int(t) }
        return 1
    }

    private var entry: WholeNumberEntry {
        WholeNumberEntry(locale: locale)
    }

    /// Nil while the field holds no number, which is what disables
    /// Save: an empty field must not quietly save as 0 and clear the day.
    private var value: Int? {
        text.flatMap(entry.value(from:))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(alignment: .firstTextBaseline) {
                        WholeNumberField(
                            title: "Today's value",
                            text: Binding(
                                get: { text ?? "" },
                                set: { text = $0 }
                            )
                        )
                        .accessibilityIdentifier(AccessibilityID.LogSheet.counterField)
                        .font(.title2.weight(.semibold).monospacedDigit())
                        Text("of \(target)")
                            .foregroundStyle(Color.kadoForegroundSecondary)
                    }
                } header: {
                    Text("Today's value")
                } footer: {
                    Text("Saves as today's completion. Setting it to 0 clears today's progress.")
                }
                .listRowBackground(Color.kadoBackgroundSecondary)
            }
            .scrollContentBackground(.hidden)
            .background(Color.kadoBackground.ignoresSafeArea())
            .navigationTitle(Text("Log value"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier(AccessibilityID.LogSheet.cancelButton)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(value == nil)
                        .accessibilityIdentifier(AccessibilityID.LogSheet.saveButton)
                }
            }
            // The number pad has no return key on iPhone; this is for
            // iPad and hardware keyboards.
            .onSubmit { save() }
            .sensoryFeedback(.success, trigger: saveTick)
            .onAppear {
                if text == nil { text = entry.text(for: todayValue()) }
            }
        }
    }

    private func todayValue() -> Int {
        let existing = habit.completions?.first {
            calendar.isDate($0.date, inSameDayAs: today)
        }
        return Int(existing?.value ?? 0)
    }

    private func save() {
        guard let value else { return }
        let clamped = min(max(value, Self.valueRange.lowerBound), Self.valueRange.upperBound)
        CompletionLogger(calendar: calendar).setCounter(
            for: habit,
            on: dayBoundary.loggingInstant(for: .now, on: today),
            to: Double(clamped),
            in: modelContext
        )
        try? modelContext.save()
        WidgetReloader.reloadAll(using: modelContext)
        saveTick += 1
        dismiss()
    }
}

#Preview {
    CounterLogSheet(
        habit: HabitRecord(
            name: "Drink water",
            frequency: .daily,
            type: .counter(target: 8)
        )
    )
    .modelContainer(PreviewContainer.emptyContainer())
}

#Preview("Dark") {
    CounterLogSheet(
        habit: HabitRecord(
            name: "Drink water",
            frequency: .daily,
            type: .counter(target: 8)
        )
    )
    .modelContainer(PreviewContainer.emptyContainer())
    .preferredColorScheme(.dark)
}
