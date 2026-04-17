import SwiftData
import SwiftUI

/// The Today tab — lists habits due today and handles tap-to-toggle
/// for binary and negative habits.
struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.frequencyEvaluator) private var frequencyEvaluator
    @Environment(\.calendar) private var calendar

    @Query(
        filter: #Predicate<HabitRecord> { $0.archivedAt == nil },
        sort: \HabitRecord.createdAt
    )
    private var activeHabits: [HabitRecord]

    @State private var showingNewHabit = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(Text("Today"))
                .navigationDestination(for: HabitRecord.self) { habit in
                    HabitDetailView(habit: habit)
                }
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showingNewHabit = true
                        } label: {
                            Label("New habit", systemImage: "plus")
                        }
                    }
                }
                .sheet(isPresented: $showingNewHabit) {
                    NewHabitFormView(model: NewHabitFormModel())
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if activeHabits.isEmpty {
            ContentUnavailableView(
                "No habits yet",
                systemImage: "list.bullet.clipboard",
                description: Text("Habits you create will appear here.")
            )
        } else {
            let due = habitsDueToday
            if due.isEmpty {
                ContentUnavailableView(
                    "Nothing due today",
                    systemImage: "checkmark.circle",
                    description: Text("Come back tomorrow, or check your habit detail to log a past day.")
                )
            } else {
                List(due) { record in
                    NavigationLink(value: record) {
                        HabitRowView(
                            habit: record.snapshot,
                            isCompletedToday: isCompletedToday(record),
                            onToggle: canToggle(record) ? { toggle(record) } : nil
                        )
                    }
                }
            }
        }
    }

    private var habitsDueToday: [HabitRecord] {
        let now = Date.now
        return activeHabits.filter { record in
            frequencyEvaluator.isDue(
                habit: record.snapshot,
                on: now,
                completions: record.completions.map(\.snapshot)
            )
        }
    }

    private func isCompletedToday(_ record: HabitRecord) -> Bool {
        let now = Date.now
        return record.completions.contains { calendar.isDate($0.date, inSameDayAs: now) }
    }

    private func canToggle(_ record: HabitRecord) -> Bool {
        switch record.type {
        case .binary, .negative: true
        case .counter, .timer: false
        }
    }

    private func toggle(_ record: HabitRecord) {
        CompletionToggler(calendar: calendar)
            .toggleToday(for: record, in: modelContext)
    }
}

#Preview("Populated") {
    TodayView()
        .modelContainer(PreviewContainer.shared)
}

#Preview("No habits") {
    TodayView()
        .modelContainer(PreviewContainer.emptyContainer())
}

#Preview("Nothing due today") {
    TodayView()
        .modelContainer(PreviewContainer.noneDueTodayContainer())
}
