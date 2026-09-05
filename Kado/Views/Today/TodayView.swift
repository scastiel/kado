import SwiftData
import SwiftUI
import KadoCore

/// The Today tab — lists habits due today and handles tap-to-toggle
/// for binary and negative habits, inline counter / timer logging,
/// and a long-press context menu for the secondary actions
/// (specific-value sheets, edit, archive).
///
/// Every piece of state this view retains — the list rows, the
/// navigation path, the presented sheet, the pending archive
/// confirmation — holds a habit **id**, never a `HabitRecord`. A
/// dev-mode `ModelContainer` swap invalidates every managed object the
/// previous store vended, and SwiftUI re-reads its retained data
/// during the next list diff, which traps inside SwiftData. Ids
/// survive the swap; records don't (issue #63).
struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.frequencyEvaluator) private var frequencyEvaluator
    @Environment(\.streakCalculator) private var streakCalculator
    @Environment(\.habitScoreCalculator) private var scoreCalculator
    @Environment(\.reviewPromptService) private var reviewPromptService
    @Environment(\.calendar) private var calendar
    @Environment(\.today) private var today
    @Environment(\.dayBoundary) private var dayBoundary

    @Query(
        filter: #Predicate<HabitRecord> { $0.archivedAt == nil },
        sort: \HabitRecord.sortOrder
    )
    private var activeHabits: [HabitRecord]

    @State private var path = NavigationPath()
    @State private var sheet: TodaySheet?
    @State private var confirmingArchiveOf: UUID?

    /// Single source of truth for sheets the Today surface presents.
    /// Replaces the boolean soup that would otherwise emerge from
    /// New / Edit / Log-counter / Log-timer running in parallel.
    enum TodaySheet: Identifiable {
        case newHabit
        case editHabit(UUID)
        case logCounter(UUID)
        case logTimer(UUID)

        var id: String {
            switch self {
            case .newHabit: "new"
            case .editHabit(let habitID): "edit-\(habitID)"
            case .logCounter(let habitID): "counter-\(habitID)"
            case .logTimer(let habitID): "timer-\(habitID)"
            }
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.kadoBackground.ignoresSafeArea())
                .navigationTitle(Text("Today"))
                .navigationDestination(for: HabitRoute.self) { route in
                    HabitDetailLoader(habitID: route.id)
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
                ) { habitID in
                    Button(String(localized: "Archive"), role: .destructive) {
                        archive(habitID)
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
        case .editHabit(let habitID):
            if let record = record(for: habitID) {
                NewHabitFormView(model: NewHabitFormModel(editing: record))
            } else {
                HabitUnavailableView()
            }
        case .logCounter(let habitID):
            if let record = record(for: habitID) {
                CounterLogSheet(habit: record)
            } else {
                HabitUnavailableView()
            }
        case .logTimer(let habitID):
            if let record = record(for: habitID) {
                TimerLogSheet(habit: record)
            } else {
                HabitUnavailableView()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if activeHabits.isEmpty {
            ContentUnavailableView {
                Label("No habits yet", systemImage: "list.bullet.clipboard")
            } description: {
                Text("Habits you create will appear here.")
            } actions: {
                Button {
                    sheet = .newHabit
                } label: {
                    Label("Create your first habit", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
        } else {
            let (due, other) = sections
            List {
                // Sampled once and passed down: letting the guard and
                // the view each read `.now` lets them straddle the
                // rollover and leave an empty, space-taking row.
                let now = Date.now
                if TodayDayCaption.isBeforeRollover(dayBoundary, now: now) {
                    TodayDayCaption(boundary: dayBoundary, now: now)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 6, trailing: 20))
                }
                if !due.isEmpty {
                    Section {
                        ForEach(due) { row($0) }
                            .onMove { moveHabits(due, from: $0, to: $1) }
                    } header: {
                        Text("Scheduled")
                    }
                }
                if !other.isEmpty {
                    Section {
                        ForEach(other) { row($0) }
                            .onMove { moveHabits(other, from: $0, to: $1) }
                    } header: {
                        Text("Not scheduled today")
                    } footer: {
                        Text("Tap to open detail, or long-press to edit or archive.")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.kadoBackground.ignoresSafeArea())
            .refreshable {
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    @ViewBuilder
    private func row(_ item: TodayRow) -> some View {
        let state = HabitRowState.resolve(
            habit: item.habit,
            completions: item.completions,
            calendar: calendar,
            asOf: today
        )
        NavigationLink(value: HabitRoute(id: item.id)) {
            HabitRowView(
                habit: item.habit,
                state: state,
                streak: streakCalculator.current(
                    for: item.habit, completions: item.completions, asOf: today
                ),
                scorePercent: Int(
                    (scoreCalculator.currentScore(
                        for: item.habit, completions: item.completions, asOf: today
                    ) * 100).rounded()
                ),
                onToggle: canToggle(item) ? { toggle(item.id) } : nil,
                onCounterIncrement: isCounter(item) ? { incrementCounter(item.id) } : nil,
                onCounterDecrement: isCounter(item) ? { decrementCounter(item.id) } : nil,
                onTimerAddFiveMinutes: isTimer(item) ? { addFiveMinutes(item.id) } : nil,
                onLogSpecificValue: logSheetCallback(for: item),
                onOpenDetail: { path.append(HabitRoute(id: item.id)) },
                onEdit: { sheet = .editHabit(item.id) },
                onArchive: { confirmingArchiveOf = item.id }
            )
        }
        .listRowBackground(Color.kadoBackgroundSecondary)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if canSwipeUndo(item, state: state) {
                Button(role: .destructive) {
                    toggle(item.id)
                } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                }
            }
        }
    }

    /// The two Today sections, snapshotted from the live records.
    ///
    /// The split rule — "the schedule asks for it today, or the user
    /// already logged progress today anyway", which keeps a row
    /// visible with its tick once a daysPerWeek rolling quota
    /// saturates — lives on `FrequencyEvaluating` so this view and the
    /// widget snapshot can't drift apart.
    private var sections: (due: [TodayRow], other: [TodayRow]) {
        TodayRow.sections(
            from: activeHabits,
            on: today,
            evaluator: frequencyEvaluator,
            calendar: calendar
        )
    }

    /// Resolves a row back to the live managed object it was
    /// snapshotted from, against whichever store is mounted now.
    /// Returns `nil` when the habit isn't there any more — archived
    /// from another surface, or left behind by a dev-mode store swap.
    private func record(for habitID: UUID) -> HabitRecord? {
        activeHabits.first { $0.id == habitID }
    }

    private var archiveDialogBinding: Binding<Bool> {
        Binding(
            get: { confirmingArchiveOf != nil },
            set: { if !$0 { confirmingArchiveOf = nil } }
        )
    }

    // MARK: - Type predicates

    private func canToggle(_ item: TodayRow) -> Bool {
        switch item.habit.type {
        case .binary, .negative: true
        case .counter, .timer: false
        }
    }

    private func isCounter(_ item: TodayRow) -> Bool {
        if case .counter = item.habit.type { return true }
        return false
    }

    private func isTimer(_ item: TodayRow) -> Bool {
        if case .timer = item.habit.type { return true }
        return false
    }

    /// Trailing-swipe Undo only applies to binary / negative when the
    /// day is already marked. Counter / timer get their undo from the
    /// row's own `−` button (counter) or the "Log specific value…"
    /// menu item, so a swipe action would be redundant.
    private func canSwipeUndo(_ item: TodayRow, state: HabitRowState) -> Bool {
        guard state.status == .complete else { return false }
        switch item.habit.type {
        case .binary, .negative: return true
        case .counter, .timer: return false
        }
    }

    private func logSheetCallback(for item: TodayRow) -> (() -> Void)? {
        switch item.habit.type {
        case .counter: return { sheet = .logCounter(item.id) }
        case .timer: return { sheet = .logTimer(item.id) }
        case .binary, .negative: return nil
        }
    }

    // MARK: - Actions

    /// The instant to stamp on anything logged right now, pinned to
    /// the day these rows were rendered for. Keeps a tap consistent
    /// with what the user was looking at when they made it.
    private var loggingInstant: Date {
        dayBoundary.loggingInstant(for: .now, on: today)
    }

    private func moveHabits(_ section: [TodayRow], from source: IndexSet, to destination: Int) {
        var reordered = section
        reordered.move(fromOffsets: source, toOffset: destination)

        let (due, other) = sections
        let isDueSection = section.first.map { first in
            due.contains { $0.id == first.id }
        } == true

        let finalOrder: [TodayRow]
        if isDueSection {
            finalOrder = reordered + other
        } else {
            finalOrder = due + reordered
        }

        let recordsByID = Dictionary(
            activeHabits.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        for (index, item) in finalOrder.enumerated() {
            recordsByID[item.id]?.sortOrder = index
        }
        try? modelContext.save()
        WidgetReloader.reloadAll(using: modelContext)
    }

    private func toggle(_ habitID: UUID) {
        guard let record = record(for: habitID) else { return }
        CompletionToggler(calendar: calendar)
            .toggleToday(for: record, on: loggingInstant, in: modelContext)
        try? modelContext.save()
        WidgetReloader.reloadAll(using: modelContext)
        checkMilestones(for: record)
    }

    private func incrementCounter(_ habitID: UUID) {
        guard let record = record(for: habitID) else { return }
        CompletionLogger(calendar: calendar)
            .incrementCounter(for: record, on: loggingInstant, in: modelContext)
        try? modelContext.save()
        WidgetReloader.reloadAll(using: modelContext)
        checkMilestones(for: record)
    }

    private func decrementCounter(_ habitID: UUID) {
        guard let record = record(for: habitID) else { return }
        CompletionLogger(calendar: calendar)
            .decrementCounter(for: record, on: loggingInstant, in: modelContext)
        try? modelContext.save()
        WidgetReloader.reloadAll(using: modelContext)
    }

    private func addFiveMinutes(_ habitID: UUID) {
        guard let record = record(for: habitID) else { return }
        CompletionLogger(calendar: calendar)
            .incrementCounter(for: record, on: loggingInstant, by: 300, in: modelContext)
        try? modelContext.save()
        WidgetReloader.reloadAll(using: modelContext)
        checkMilestones(for: record)
    }

    private func checkMilestones(for record: HabitRecord) {
        let snap = record.snapshot
        let comps = (record.completions ?? []).compactMap(\.snapshot)
        let streak = streakCalculator.current(for: snap, completions: comps, asOf: today)
        if streak == 7 || streak == 30 {
            reviewPromptService.recordMilestone(.streak(days: streak))
        }

        // Re-snapshotted after the save, so this sees the mutation that
        // just landed rather than the pre-tap rows.
        let allComplete = sections.due.allSatisfy { item in
            HabitRowState.resolve(
                habit: item.habit,
                completions: item.completions,
                calendar: calendar,
                asOf: today
            ).status == .complete
        }
        if allComplete {
            reviewPromptService.recordMilestone(.allHabitsComplete)
        }
    }

    private func archive(_ habitID: UUID) {
        guard let record = record(for: habitID) else { return }
        record.archivedAt = loggingInstant
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
