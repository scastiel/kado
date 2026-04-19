import SwiftData
import SwiftUI
import KadoCore

/// The Today tab — lists habits due today and handles tap-to-toggle
/// for binary and negative habits, inline counter / timer logging,
/// and a long-press context menu for the secondary actions
/// (specific-value sheets, edit, archive).
struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.frequencyEvaluator) private var frequencyEvaluator
    @Environment(\.streakCalculator) private var streakCalculator
    @Environment(\.habitScoreCalculator) private var scoreCalculator
    @Environment(\.calendar) private var calendar

    @Query(
        filter: #Predicate<HabitRecord> { $0.archivedAt == nil },
        sort: \HabitRecord.createdAt
    )
    private var activeHabits: [HabitRecord]

    @State private var path = NavigationPath()
    @State private var sheet: TodaySheet?
    @State private var confirmingArchiveOf: HabitRecord?

    /// Single source of truth for sheets the Today surface presents.
    /// Replaces the boolean soup that would otherwise emerge from
    /// New / Edit / Log-counter / Log-timer running in parallel.
    enum TodaySheet: Identifiable {
        case newHabit
        case editHabit(HabitRecord)
        case logCounter(HabitRecord)
        case logTimer(HabitRecord)

        var id: String {
            switch self {
            case .newHabit: "new"
            case .editHabit(let h): "edit-\(h.id)"
            case .logCounter(let h): "counter-\(h.id)"
            case .logTimer(let h): "timer-\(h.id)"
            }
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            content
                .navigationTitle(Text("Today"))
                .navigationDestination(for: HabitRecord.self) { habit in
                    HabitDetailView(habit: habit)
                }
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            sheet = .newHabit
                        } label: {
                            Label("New habit", systemImage: "plus")
                        }
                    }
                }
                .sheet(item: $sheet) { sheet in
                    sheetContent(for: sheet)
                }
                .confirmationDialog(
                    String(localized: "Archive this habit?"),
                    isPresented: archiveDialogBinding,
                    titleVisibility: .visible,
                    presenting: confirmingArchiveOf
                ) { habit in
                    Button(String(localized: "Archive"), role: .destructive) {
                        archive(habit)
                    }
                    Button(String(localized: "Cancel"), role: .cancel) {}
                } message: { _ in
                    Text("Archived habits stop appearing on Today but keep their history.")
                }
        }
    }

    @ViewBuilder
    private func sheetContent(for sheet: TodaySheet) -> some View {
        switch sheet {
        case .newHabit:
            NewHabitFormView(model: NewHabitFormModel())
        case .editHabit(let habit):
            NewHabitFormView(model: NewHabitFormModel(editing: habit))
        case .logCounter(let habit):
            CounterLogSheet(habit: habit)
        case .logTimer(let habit):
            TimerLogSheet(habit: habit)
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
                    let snap = record.snapshot
                    let comps = (record.completions ?? []).map(\.snapshot)
                    let state = HabitRowState.resolve(
                        habit: snap,
                        completions: comps,
                        calendar: calendar,
                        asOf: .now
                    )
                    NavigationLink(value: record) {
                        HabitRowView(
                            habit: snap,
                            state: state,
                            streak: streakCalculator.current(
                                for: snap, completions: comps, asOf: .now
                            ),
                            scorePercent: Int(
                                (scoreCalculator.currentScore(
                                    for: snap, completions: comps, asOf: .now
                                ) * 100).rounded()
                            ),
                            onToggle: canToggle(record) ? { toggle(record) } : nil,
                            onCounterIncrement: isCounter(record) ? { incrementCounter(record) } : nil,
                            onCounterDecrement: isCounter(record) ? { decrementCounter(record) } : nil,
                            onTimerAddFiveMinutes: isTimer(record) ? { addFiveMinutes(record) } : nil,
                            onLogSpecificValue: logSheetCallback(for: record),
                            onOpenDetail: { path.append(record) },
                            onEdit: { sheet = .editHabit(record) },
                            onArchive: { confirmingArchiveOf = record }
                        )
                    }
                    .listRowBackground(Color.kadoBackgroundSecondary)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        if canSwipeUndo(record, state: state) {
                            Button(role: .destructive) {
                                toggle(record)
                            } label: {
                                Label("Undo", systemImage: "arrow.uturn.backward")
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.kadoBackground.ignoresSafeArea())
                .refreshable {
                    // SwiftData has no public API to force a CloudKit
                    // pull; the brief delay lets any in-flight push
                    // settle so the @Query rebind shows the latest
                    // remote state when the spinner retracts.
                    try? await Task.sleep(for: .seconds(1))
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
                completions: (record.completions ?? []).map(\.snapshot)
            )
        }
    }

    private var archiveDialogBinding: Binding<Bool> {
        Binding(
            get: { confirmingArchiveOf != nil },
            set: { if !$0 { confirmingArchiveOf = nil } }
        )
    }

    // MARK: - Type predicates

    private func canToggle(_ record: HabitRecord) -> Bool {
        switch record.type {
        case .binary, .negative: true
        case .counter, .timer: false
        }
    }

    private func isCounter(_ record: HabitRecord) -> Bool {
        if case .counter = record.type { return true }
        return false
    }

    private func isTimer(_ record: HabitRecord) -> Bool {
        if case .timer = record.type { return true }
        return false
    }

    /// Trailing-swipe Undo only applies to binary / negative when the
    /// day is already marked. Counter / timer get their undo from the
    /// row's own `−` button (counter) or the "Log specific value…"
    /// menu item, so a swipe action would be redundant.
    private func canSwipeUndo(_ record: HabitRecord, state: HabitRowState) -> Bool {
        guard state.status == .complete else { return false }
        switch record.type {
        case .binary, .negative: return true
        case .counter, .timer: return false
        }
    }

    private func logSheetCallback(for record: HabitRecord) -> (() -> Void)? {
        switch record.type {
        case .counter: return { sheet = .logCounter(record) }
        case .timer: return { sheet = .logTimer(record) }
        case .binary, .negative: return nil
        }
    }

    // MARK: - Actions

    private func toggle(_ record: HabitRecord) {
        CompletionToggler(calendar: calendar)
            .toggleToday(for: record, in: modelContext)
        try? modelContext.save()
        WidgetReloader.reloadAll(using: modelContext)
    }

    private func incrementCounter(_ record: HabitRecord) {
        CompletionLogger(calendar: calendar)
            .incrementCounter(for: record, in: modelContext)
        try? modelContext.save()
        WidgetReloader.reloadAll(using: modelContext)
    }

    private func decrementCounter(_ record: HabitRecord) {
        CompletionLogger(calendar: calendar)
            .decrementCounter(for: record, in: modelContext)
        try? modelContext.save()
        WidgetReloader.reloadAll(using: modelContext)
    }

    private func addFiveMinutes(_ record: HabitRecord) {
        // CompletionRecord.value carries seconds for timer habits, so a
        // five-minute bump is just delta = 300 through the same
        // increment path the counter uses.
        CompletionLogger(calendar: calendar)
            .incrementCounter(for: record, by: 300, in: modelContext)
        try? modelContext.save()
        WidgetReloader.reloadAll(using: modelContext)
    }

    private func archive(_ record: HabitRecord) {
        record.archivedAt = .now
        try? modelContext.save()
        WidgetReloader.reloadAll(using: modelContext)
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

#Preview("Dark") {
    TodayView()
        .modelContainer(PreviewContainer.shared)
        .preferredColorScheme(.dark)
}
