import SwiftData
import SwiftUI
import KadoCore

/// Modal sheet for setting a counter habit's value to an exact number.
/// Reachable from the Today row's context menu — the row's `−/+`
/// stepper covers unit changes; this sheet covers "I forgot all day,
/// set it to 5". Single-record-per-day invariant holds: saving with
/// `0` deletes today's completion.
struct CounterLogSheet: View {
    let habit: HabitRecord

    @Environment(\.modelContext) private var modelContext
    @Environment(\.calendar) private var calendar
    @Environment(\.dismiss) private var dismiss

    /// Prefilled lazily in `.onAppear` so the env calendar (not
    /// `.current`) drives today-completion lookup. Matches the
    /// pattern used by `TimerLogSheet`.
    @State private var value: Int?
    @State private var saveTick = 0

    private var target: Int {
        if case .counter(let t) = habit.type { return Int(t) }
        return 1
    }

    private var maxValue: Int {
        max(target * 4, 100)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(
                        String(localized: "\(value ?? 0) of \(target)"),
                        value: Binding(
                            get: { value ?? 0 },
                            set: { value = $0 }
                        ),
                        in: 0...maxValue
                    )
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
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
            .sensoryFeedback(.success, trigger: saveTick)
            .onAppear {
                if value == nil { value = todayValue() }
            }
        }
    }

    private func todayValue() -> Int {
        let existing = habit.completions?.first {
            calendar.isDate($0.date, inSameDayAs: .now)
        }
        return Int(existing?.value ?? 0)
    }

    private func save() {
        let v = value ?? todayValue()
        CompletionLogger(calendar: calendar).setCounter(
            for: habit,
            to: Double(v),
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
