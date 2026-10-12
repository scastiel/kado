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
///
/// In a regular-width window — the iPad, and the iPhone Duo's inner
/// display, which reports regular in both directions under the phone
/// idiom — the list and the selected habit's detail sit side by side
/// (`splitLayout`), rather than a phone list stretched across the
/// whole screen with its detail pushed over it (issue #140).
struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.frequencyEvaluator) private var frequencyEvaluator
    @Environment(\.streakCalculator) private var streakCalculator
    @Environment(\.habitScoreCalculator) private var scoreCalculator
    @Environment(\.reviewPromptService) private var reviewPromptService
    @Environment(\.tipNudge) private var tipNudge
    @Environment(\.appearanceAnnouncement) private var appearanceAnnouncement
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.calendar) private var calendar
    @Environment(\.today) private var today
    @Environment(\.dayBoundary) private var dayBoundary
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @Query(
        filter: #Predicate<HabitRecord> { $0.archivedAt == nil },
        sort: \HabitRecord.sortOrder
    )
    private var activeHabits: [HabitRecord]

    @State private var path = NavigationPath()
    /// The habit picked in the split layout's list, by id like
    /// everything else here. `nil` until one is picked, and left stale
    /// when that habit leaves the list: `TodayRow.selection` reads both
    /// as "the first row".
    @State private var selectedHabitID: UUID?
    @State private var sheet: TodaySheet?
    @State private var confirmingArchiveOf: UUID?
    /// The latest `−` / `+` / `+5m` tap, for the haptic. Recorded by
    /// the mutation rather than observed on the row: a row keyed on
    /// its own value ticks when the day rolls over or a sync lands,
    /// and misses the tap that moves it between sections (a new
    /// `ForEach` identity sees no old → new).
    @State private var quickLog: QuickLogEvent?

    /// The card in the slot at the bottom of the list, if any — the
    /// Appearance announcement or the tip nudge, never both
    /// (`TodayCard`). Seeded in `.onAppear` rather than in the
    /// property's initial value, because `@State` is set up before the
    /// environment is injected and would capture the `@Entry` defaults
    /// instead of whatever the app injected (CLAUDE.md, SwiftUI
    /// section).
    @State private var card: TodayCard?

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
        /// Settings › Appearance, reached from the announcement card.
        /// A sheet for the same reason as the Tip Jar.
        case appearance

        var id: String {
            switch self {
            case .newHabit: "new"
            case .editHabit(let habitID): "edit-\(habitID)"
            case .logCounter(let habitID): "counter-\(habitID)"
            case .logTimer(let habitID): "timer-\(habitID)"
            case .tipJar: "tip-jar"
            case .appearance: "appearance"
            }
        }
    }

    var body: some View {
        Group {
            if usesSplitLayout {
                splitLayout
            } else {
                stackLayout
            }
        }
        .onAppear(perform: refreshCard)
        // Re-asked after every sheet, because two of them retire a
        // card: a tip taken in the Tip Jar retires the nudge, opening
        // Appearance retires the announcement, and Today is already on
        // screen so nothing else would prompt it to look again.
        .sheet(item: $sheet, onDismiss: refreshCard) { sheet in
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
            .accessibilityIdentifier(AccessibilityID.Today.archiveConfirmButton)
            Button(String(localized: "Cancel"), role: .cancel) {}
        } message: { _ in
            Text("Archived habits leave Today but keep their history. You can find them in Settings › Archived habits.")
        }
    }

    // MARK: - Layouts

    /// Side by side only when there is something to put on the side:
    /// with no habits, the empty state takes the whole window as it
    /// does on a phone.
    private var usesSplitLayout: Bool {
        horizontalSizeClass == .regular && !activeHabits.isEmpty
    }

    /// Compact width: the list, and a pushed detail.
    private var stackLayout: some View {
        NavigationStack(path: $path) {
            todayColumn
                .navigationDestination(for: HabitRoute.self) { route in
                    HabitDetailLoader(habitID: route.id)
                }
        }
    }

    /// Regular width: the list on the leading side and the selected
    /// habit's detail beside it, both always on screen.
    ///
    /// `.balanced` with the sidebar toggle removed: in portrait the
    /// automatic style floats the list *over* the detail, and a hidden
    /// list leaves no way to reach another habit.
    private var splitLayout: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            // A sidebar defaults to an inline title and the flat
            // `.sidebar` list style; both are pinned back to what the
            // phone shows (`content`), so the list reads the same at
            // either width. The iPad takes the large title; the Duo's
            // inner display (iOS 27.1) keeps the inline one regardless.
            todayColumn
                .navigationBarTitleDisplayMode(.large)
                .toolbar(removing: .sidebarToggle)
                // No narrower than a phone: a row is laid out for one,
                // and below that the trailing control squeezes the
                // name — French truncated on an iPad mini at 330pt.
                // The detail beside it is then about a phone wide too.
                .navigationSplitViewColumnWidth(min: 370, ideal: 400, max: 480)
        } detail: {
            NavigationStack {
                if let habitID = detailHabitID {
                    // Keyed by habit, so the detail's own state — the
                    // month its calendar shows — starts over when the
                    // selection moves instead of carrying across.
                    HabitDetailLoader(habitID: habitID)
                        .id(habitID)
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
    }

    private var todayColumn: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.kadoBackground.ignoresSafeArea())
            .navigationTitle(Text("Today"))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        sheet = .newHabit
                    } label: {
                        Label("New habit", systemImage: "plus")
                    }
                    .accessibilityIdentifier(AccessibilityID.Today.newHabitButton)
                }
            }
    }

    /// The habit the split layout's detail column shows — see
    /// `TodayRow.selection`.
    private var detailHabitID: UUID? {
        let (due, other) = sections
        return TodayRow.selection(picked: selectedHabitID, due: due, other: other)
    }

    /// The split layout's list selection. Reads through
    /// `detailHabitID`, so the highlighted row is always the one the
    /// detail column shows.
    private var selectionBinding: Binding<UUID?> {
        Binding(
            get: { detailHabitID },
            set: { if let habitID = $0 { selectedHabitID = habitID } }
        )
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
                    .toolbar { closeButton }
            }
        case .appearance:
            NavigationStack {
                AppearanceView()
                    .toolbar { closeButton }
            }
        }
    }

    private var closeButton: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            // Not "Done": that key already exists in the catalog as a
            // habit's completed-day label ("Fait" in French), which
            // would read as nonsense on a dismiss button.
            Button("Close") { self.sheet = nil }
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
            let selected = usesSplitLayout
                ? TodayRow.selection(picked: selectedHabitID, due: due, other: other)
                : nil
            List(selection: usesSplitLayout ? selectionBinding : nil) {
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
                        ForEach(due) { row($0, isSelected: $0.id == selected) }
                            .onMove { moveHabits(due, from: $0, to: $1) }
                    } header: {
                        Text("Scheduled")
                            .foregroundStyle(Color.kadoForegroundSecondary)
                    }
                }
                if !other.isEmpty {
                    Section {
                        ForEach(other) { row($0, isSelected: $0.id == selected) }
                            .onMove { moveHabits(other, from: $0, to: $1) }
                    } header: {
                        Text("Not scheduled today")
                            .foregroundStyle(Color.kadoForegroundSecondary)
                    } footer: {
                        Text("Tap to open detail, or long-press to edit or archive.")
                            .foregroundStyle(Color.kadoForegroundSecondary)
                    }
                }
                switch card {
                case .appearanceAnnouncement:
                    Section {
                        AppearanceAnnouncementBanner(
                            onOpen: { sheet = .appearance },
                            onHide: hideAppearanceAnnouncement
                        )
                        .todayNoticeCardRow()
                    }
                case .tipNudge:
                    Section {
                        TipNudgeBanner(
                            onTip: { sheet = .tipJar },
                            onHide: hideTipNudge
                        )
                        .todayNoticeCardRow()
                    }
                case nil:
                    EmptyView()
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.kadoBackground.ignoresSafeArea())
            .quickLogFeedback(quickLog)
            .refreshable {
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    @ViewBuilder
    private func row(_ item: TodayRow, isSelected: Bool) -> some View {
        let state = HabitRowState.resolve(
            habit: item.habit,
            completions: item.completions,
            calendar: calendar,
            asOf: today
        )
        let rowView = HabitRowView(
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
            onOpenDetail: { openDetail(item.id) },
            onEdit: { sheet = .editHabit(item.id) },
            onArchive: { confirmingArchiveOf = item.id }
        )
        Group {
            if usesSplitLayout {
                // Picked through the list's selection, which the tag
                // feeds — no link, and no chevron promising a push into
                // a detail that is already on screen beside the list.
                rowView.tag(item.id)
            } else {
                NavigationLink(value: HabitRoute(id: item.id)) { rowView }
            }
        }
        // A custom row fill replaces the system's selection highlight,
        // so the selected row has to draw its own.
        .listRowBackground(isSelected ? Color.kadoAccentTint : Color.kadoBackgroundSecondary)
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

    /// "Open detail" from a row's menu: pushes on a phone, and selects
    /// in the split layout, where the detail is already beside the list.
    private func openDetail(_ habitID: UUID) {
        if usesSplitLayout {
            selectedHabitID = habitID
        } else {
            path.append(HabitRoute(id: habitID))
        }
    }

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
        let logger = CompletionLogger(calendar: calendar)
        let before = logger.value(for: record, on: loggingInstant)
        logger.incrementCounter(for: record, on: loggingInstant, in: modelContext)
        recordQuickLog(for: record, from: before, to: before + 1)
        try? modelContext.save()
        WidgetReloader.reloadAll(using: modelContext)
        checkMilestones(for: record)
    }

    private func decrementCounter(_ habitID: UUID) {
        guard let record = record(for: habitID) else { return }
        let logger = CompletionLogger(calendar: calendar)
        let before = logger.value(for: record, on: loggingInstant)
        logger.decrementCounter(for: record, on: loggingInstant, in: modelContext)
        recordQuickLog(for: record, from: before, to: max(0, before - 1))
        try? modelContext.save()
        WidgetReloader.reloadAll(using: modelContext)
    }

    private func addFiveMinutes(_ habitID: UUID) {
        guard let record = record(for: habitID) else { return }
        let logger = CompletionLogger(calendar: calendar)
        let before = logger.value(for: record, on: loggingInstant)
        logger.incrementCounter(for: record, on: loggingInstant, by: 300, in: modelContext)
        recordQuickLog(for: record, from: before, to: before + 300)
        try? modelContext.save()
        WidgetReloader.reloadAll(using: modelContext)
        checkMilestones(for: record)
    }

    /// The step is known here exactly — `+1`, `−1` floored at zero,
    /// `+300` — so the haptic is derived from the mutation, not read
    /// back from a store that may still hold a just-deleted record.
    private func recordQuickLog(for record: HabitRecord, from old: Double, to new: Double) {
        guard let event = QuickLogEvent.next(after: quickLog, type: record.type, oldValue: old, newValue: new) else {
            return
        }
        quickLog = event
    }

    private func checkMilestones(for record: HabitRecord) {
        let snap = record.snapshot
        let comps = (record.completions ?? []).compactMap(\.snapshot)
        let streak = streakCalculator.current(for: snap, completions: comps, asOf: today)
        if streak == 7 || streak == 30 {
            reviewPromptService.recordMilestone(.streak(days: streak))
        }

        // Re-snapshotted after the save, so this sees the mutation that
        // just landed rather than the pre-tap rows. Through
        // `DayProgress` so "all done" means the same thing here as it
        // does for the confetti and the lock-screen ring — in
        // particular, a day with nothing scheduled is not a milestone.
        let due = sections.due
        let completed = due.filter { item in
            HabitRowState.resolve(
                habit: item.habit,
                completions: item.completions,
                calendar: calendar,
                asOf: today
            ).isDone(for: item.habit)
        }.count
        if DayProgress(completed: completed, total: due.count).isComplete {
            reviewPromptService.recordMilestone(.allHabitsComplete)
        }
    }

    // MARK: - Bottom card

    /// Asks both services what is due and lets `TodayCard` pick. Every
    /// rule either service applies is one-way, so a dismissed card
    /// never comes back.
    private func refreshCard() {
        card = TodayCard.resolve(
            announcementRetiredAt: appearanceAnnouncement.retiredAt(),
            tipNudgeDue: tipNudge.shouldShow(),
            now: .now,
            calendar: calendar
        )
    }

    private func hideTipNudge() {
        tipNudge.hide()
        withAnimation(reduceMotion ? nil : KadoMotion.base) {
            card = nil
        }
    }

    /// Takes the card away rather than re-resolving: the tip nudge
    /// isn't due until tomorrow anyway, and resolving would only say so.
    private func hideAppearanceAnnouncement() {
        appearanceAnnouncement.retire()
        withAnimation(reduceMotion ? nil : KadoMotion.base) {
            card = nil
        }
    }

    private func archive(_ habitID: UUID) {
        guard let record = record(for: habitID) else { return }
        HabitLifecycle().archive(record, at: loggingInstant, in: modelContext)
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

#Preview("Appearance announcement") {
    TodayView()
        .modelContainer(PreviewContainer.shared)
        .environment(\.appearanceAnnouncement, StubAppearanceAnnouncementService())
        .environment(\.tipNudge, StubTipNudgeService())
}

#Preview("Tip nudge") {
    TodayView()
        .modelContainer(PreviewContainer.shared)
        .environment(\.appearanceAnnouncement, StubAppearanceAnnouncementService(retiredAt: .distantPast))
        .environment(\.tipNudge, StubTipNudgeService())
}

#Preview("Tip nudge — Dark") {
    TodayView()
        .modelContainer(PreviewContainer.shared)
        .environment(\.appearanceAnnouncement, StubAppearanceAnnouncementService(retiredAt: .distantPast))
        .environment(\.tipNudge, StubTipNudgeService())
        .preferredColorScheme(.dark)
}

#Preview("Dark") {
    TodayView()
        .modelContainer(PreviewContainer.shared)
        .preferredColorScheme(.dark)
}
