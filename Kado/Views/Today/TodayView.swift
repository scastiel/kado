import SwiftData
import SwiftUI
import KadoCore

/// The Today tab — lists habits due today and handles tap-to-toggle
/// for binary and negative habits, inline counter / timer logging,
/// and a long-press context menu for the secondary actions
/// (specific-value sheets, reordering, edit, archive).
///
/// Built from a `ScrollView` of `HabitCard`s rather than a `List`.
/// The design's grouped card — 22pt corners, a hairline inset to the
/// text column, 13pt row padding — is not reachable through `List`'s
/// row insets and separator insets, and every approximation of it
/// fought the platform. What `List` was giving us in return was
/// drag-to-reorder and swipe-to-undo: reordering moved to the row's
/// context menu, and undo was already redundant with the row control,
/// which toggles in both directions.
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
    @Environment(\.tipNudge) private var tipNudge
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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

    /// Whether the tip nudge is showing. Seeded in `.onAppear` rather
    /// than in the property's initial value, because `@State` is set up
    /// before the environment is injected and would capture the
    /// `@Entry` default instead of whatever the app injected
    /// (CLAUDE.md, SwiftUI section). `nil` means "not asked yet".
    @State private var showsTipNudge: Bool?

    /// Single source of truth for sheets the Today surface presents.
    /// Replaces the boolean soup that would otherwise emerge from
    /// New / Edit / Log-counter / Log-timer running in parallel.
    enum TodaySheet: Identifiable {
        case newHabit
        case editHabit(UUID)
        case logCounter(UUID)
        case logTimer(UUID)
        /// The Tip Jar, reached from the nudge at the bottom of the
        /// list. A sheet rather than a `navigationDestination`, so the
        /// detour doesn't leave the Tip Jar sitting on Today's
        /// navigation stack once it's done.
        case tipJar

        var id: String {
            switch self {
            case .newHabit: "new"
            case .editHabit(let habitID): "edit-\(habitID)"
            case .logCounter(let habitID): "counter-\(habitID)"
            case .logTimer(let habitID): "timer-\(habitID)"
            case .tipJar: "tip-jar"
            }
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack(alignment: .bottomTrailing) {
                Color.kadoBackground.ignoresSafeArea()
                content
                if !activeHabits.isEmpty {
                    AddHabitButton { sheet = .newHabit }
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                }
            }
            // The title lives in the scroll content, at 40pt on the
            // display serif with the progress bar tucked under it — a
            // navigation bar can host neither that pairing nor that
            // size.
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: HabitRoute.self) { route in
                HabitDetailLoader(habitID: route.id)
            }
            .onAppear(perform: refreshTipNudge)
            // Re-asked after every sheet, because one of them is
            // the Tip Jar: a tip taken there retires the nudge, and
            // Today is already on screen so nothing else would
            // prompt it to look again.
            .sheet(item: $sheet, onDismiss: refreshTipNudge) { sheet in
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
        case .tipJar:
            NavigationStack {
                TipJarView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            // Not "Done": that key already exists in the
                            // catalog as a habit's completed-day label
                            // ("Fait" in French), which would read as
                            // nonsense on a dismiss button.
                            Button("Close") { self.sheet = nil }
                        }
                    }
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
            populated
        }
    }

    private var populated: some View {
        let (due, other) = sections
        return ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                // Sampled once and passed down: letting the guard and
                // the view each read `.now` lets them straddle the
                // rollover and leave an empty, space-taking row.
                let now = Date.now

                VStack(alignment: .leading, spacing: 8) {
                    TodayProgressHeader(
                        doneCount: doneCount(in: due),
                        scheduledCount: due.count
                    )
                    if TodayDayCaption.isBeforeRollover(dayBoundary, now: now) {
                        TodayDayCaption(boundary: dayBoundary, now: now)
                    }
                }

                if !due.isEmpty {
                    section("Scheduled today", rows: due, scheduled: true)
                }
                if !other.isEmpty {
                    section("Not scheduled today", rows: other, scheduled: false)
                }
                if showsTipNudge == true {
                    TipNudgeBanner(
                        onTip: { sheet = .tipJar },
                        onHide: hideTipNudge
                    )
                    .background(
                        RoundedRectangle(cornerRadius: KadoRadius.group, style: .continuous)
                            .fill(Color.kadoAccentTint)
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            // Enough clearance that the last row can scroll out from
            // under the floating add button.
            .padding(.bottom, 96)
        }
        .scrollContentBackground(.hidden)
        .refreshable {
            try? await Task.sleep(for: .seconds(1))
        }
    }

    private func section(
        _ title: LocalizedStringKey,
        rows: [TodayRow],
        scheduled: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            TodaySectionHeader(title: title)
            HabitCard {
                ForEach(rows) { item in
                    row(item, in: rows, scheduled: scheduled)
                }
            }
        }
    }

    @ViewBuilder
    private func row(_ item: TodayRow, in section: [TodayRow], scheduled: Bool) -> some View {
        let state = HabitRowState.resolve(
            habit: item.habit,
            completions: item.completions,
            calendar: calendar,
            asOf: today
        )
        let streak = streakCalculator.current(
            for: item.habit, completions: item.completions, asOf: today
        )
        let scorePercent = Int(
            (scoreCalculator.currentScore(
                for: item.habit, completions: item.completions, asOf: today
            ) * 100).rounded()
        )
        HabitRowView(
            habit: item.habit,
            state: state,
            meta: TodayRowMeta.line(
                habit: item.habit,
                state: state,
                streak: streak,
                scorePercent: scorePercent,
                nextDue: scheduled ? nil : nextDue(for: item),
                calendar: calendar,
                asOf: today
            ),
            isScheduledToday: scheduled,
            streak: streak,
            scorePercent: scorePercent,
            onToggle: canToggle(item) ? { toggle(item.id) } : nil,
            onCounterIncrement: isCounter(item) ? { incrementCounter(item.id) } : nil,
            onCounterDecrement: isCounter(item) ? { decrementCounter(item.id) } : nil,
            onTimerAddFiveMinutes: isTimer(item) ? { addFiveMinutes(item.id) } : nil,
            onLogSpecificValue: logSheetCallback(for: item),
            onOpenDetail: { path.append(HabitRoute(id: item.id)) },
            onMoveUp: canMove(item, in: section, by: -1)
                ? { move(item, in: section, by: -1) } : nil,
            onMoveDown: canMove(item, in: section, by: 1)
                ? { move(item, in: section, by: 1) } : nil,
            onEdit: { sheet = .editHabit(item.id) },
            onArchive: { confirmingArchiveOf = item.id }
        )
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

    /// How many of today's scheduled habits are done. Drives the
    /// progress bar, so it counts the same rows the bar's denominator
    /// does.
    private func doneCount(in due: [TodayRow]) -> Int {
        due.filter { item in
            HabitRowState.resolve(
                habit: item.habit,
                completions: item.completions,
                calendar: calendar,
                asOf: today
            ).status == .complete
        }.count
    }

    /// When the schedule next asks for a habit sitting in the
    /// "not scheduled today" section.
    private func nextDue(for item: TodayRow) -> Date? {
        NextDueDate.next(
            for: item.habit,
            after: today,
            completions: item.completions,
            calendar: calendar,
            evaluator: frequencyEvaluator
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

    private func canMove(_ item: TodayRow, in section: [TodayRow], by delta: Int) -> Bool {
        guard let index = section.firstIndex(where: { $0.id == item.id }) else { return false }
        return section.indices.contains(index + delta)
    }

    /// Moves a habit one place within its own section.
    ///
    /// Confined to the section on purpose: the two sections are derived
    /// from the schedule, not from `sortOrder`, so a row pushed across
    /// the boundary would snap straight back and read as a broken
    /// control.
    private func move(_ item: TodayRow, in section: [TodayRow], by delta: Int) {
        guard let index = section.firstIndex(where: { $0.id == item.id }),
              section.indices.contains(index + delta)
        else { return }

        var reordered = section
        reordered.swapAt(index, index + delta)

        let (due, other) = sections
        let isDueSection = section.first.map { first in
            due.contains { $0.id == first.id }
        } == true
        let finalOrder = isDueSection ? reordered + other : due + reordered

        let recordsByID = Dictionary(
            activeHabits.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        for (position, row) in finalOrder.enumerated() {
            recordsByID[row.id]?.sortOrder = position
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

    // MARK: - Tip nudge

    /// Asks the service whether the nudge belongs on screen. Every rule
    /// it applies is one-way, so this can only ever take the card away
    /// — a dismissed or already-tipped nudge never comes back.
    private func refreshTipNudge() {
        showsTipNudge = tipNudge.shouldShow()
    }

    private func hideTipNudge() {
        tipNudge.hide()
        withAnimation(reduceMotion ? nil : KadoMotion.base) {
            showsTipNudge = false
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

#Preview("Tip nudge") {
    TodayView()
        .modelContainer(PreviewContainer.shared)
        .environment(\.tipNudge, StubTipNudgeService())
}

#Preview("Tip nudge — Dark") {
    TodayView()
        .modelContainer(PreviewContainer.shared)
        .environment(\.tipNudge, StubTipNudgeService())
        .preferredColorScheme(.dark)
}

#Preview("Dark") {
    TodayView()
        .modelContainer(PreviewContainer.shared)
        .preferredColorScheme(.dark)
}
