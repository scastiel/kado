import SwiftData
import SwiftUI

/// Modal sheet for logging a timer habit's session duration in
/// minutes. Replaces today's completion on save (single-record-
/// per-day invariant).
struct TimerLogSheet: View {
    let habit: HabitRecord

    @Environment(\.modelContext) private var modelContext
    @Environment(\.calendar) private var calendar
    @Environment(\.dismiss) private var dismiss

    /// Prefilled lazily in `.onAppear` so the env calendar (not the
    /// unrelated `.current`) drives today-completion lookup. `nil`
    /// before first render.
    @State private var minutes: Int?
    @State private var saveTick = 0

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(
                        String(localized: "\(minutes ?? 1) min"),
                        value: Binding(
                            get: { minutes ?? 1 },
                            set: { minutes = $0 }
                        ),
                        in: 1...480
                    )
                } header: {
                    Text("Session length")
                } footer: {
                    Text("Saves as today's completion. If you already logged a session today, it will be replaced.")
                }
            }
            .navigationTitle(Text("Log session"))
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
                if minutes == nil {
                    minutes = defaultMinutes()
                }
            }
        }
    }

    private func defaultMinutes() -> Int {
        let existing = habit.completions.first {
            calendar.isDate($0.date, inSameDayAs: .now)
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
        let m = minutes ?? defaultMinutes()
        CompletionLogger(calendar: calendar).logTimerSession(
            for: habit,
            seconds: TimeInterval(m) * 60,
            in: modelContext
        )
        try? modelContext.save()
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
