import Foundation
import Testing
@testable import Kado
import KadoCore

/// The rules a widget's habit pick has to follow. All of them are
/// about what the *user* asked for surviving the trip through the App
/// Group snapshot — a pick is a list of ids written weeks ago against
/// habits that may since have been renamed, archived or deleted.
@Suite("WidgetHabitSelection")
struct WidgetHabitSelectionTests {

    // MARK: - Fixtures

    private func habit(_ name: String, id: UUID = UUID()) -> WidgetHabit {
        WidgetHabit(
            id: id,
            name: name,
            color: .blue,
            icon: "circle",
            typeKind: .binary,
            target: nil
        )
    }

    private func todayRow(_ habit: WidgetHabit) -> WidgetTodayRow {
        WidgetTodayRow(
            habit: habit,
            status: .none,
            progress: 0,
            valueToday: nil,
            streak: 0,
            scorePercent: 0
        )
    }

    private func snapshot(_ habits: [WidgetHabit]) -> WidgetSnapshot {
        WidgetSnapshot(
            generatedAt: .now,
            habits: habits,
            today: habits.map(todayRow),
            totalDueToday: habits.count,
            completedToday: 0,
            matrix: habits.map { WidgetMatrixRow(habit: $0, cells: []) },
            matrixDays: []
        )
    }

    /// Five habits named A…E, in that order.
    private func fixture() -> (WidgetSnapshot, [WidgetHabit]) {
        let habits = ["A", "B", "C", "D", "E"].map { habit($0) }
        return (snapshot(habits), habits)
    }

    // MARK: - No selection

    /// The case every freshly added widget is in. It must not render
    /// blank, and it is also what a widget already on the Home Screen
    /// gets when a build swaps `StaticConfiguration` for
    /// `AppIntentConfiguration` under it — so "no pick" has to mean
    /// what the widget did before there was a pick at all.
    @Test("No selection shows every habit, up to the limit")
    func emptySelectionShowsEverything() {
        let (snap, habits) = fixture()
        #expect(
            WidgetHabitSelection.todayRows(from: snap, selecting: [], limit: 8)
                .map(\.habit.name) == habits.map(\.name)
        )
        #expect(
            WidgetHabitSelection.todayRows(from: snap, selecting: [], limit: 3)
                .map(\.habit.name) == ["A", "B", "C"]
        )
        #expect(
            WidgetHabitSelection.matrixRows(from: snap, selecting: [], limit: 3)
                .map(\.habit.name) == ["A", "B", "C"]
        )
    }

    // MARK: - Order

    /// Picking habits is an ordering gesture as much as a filtering
    /// one — the widget shows them the way they were chosen, not the
    /// way the app happens to sort them.
    @Test("A selection renders in pick order, not snapshot order")
    func selectionKeepsPickOrder() {
        let (snap, habits) = fixture()
        let picked = [habits[3].id, habits[0].id, habits[2].id]
        #expect(
            WidgetHabitSelection.todayRows(from: snap, selecting: picked, limit: 8)
                .map(\.habit.name) == ["D", "A", "C"]
        )
        #expect(
            WidgetHabitSelection.matrixRows(from: snap, selecting: picked, limit: 8)
                .map(\.habit.name) == ["D", "A", "C"]
        )
    }

    // MARK: - Stale ids

    /// A pick outlives the habits in it. An id with nothing behind it
    /// — archived, deleted — closes up rather than leaving a gap, and
    /// never costs one of the remaining slots. (Not due today is a
    /// different case: the habit still exists, and is kept, dimmed.)
    @Test("Ids with no row behind them are dropped, not left as holes")
    func staleIdsAreDropped() {
        let (snap, habits) = fixture()
        let picked = [UUID(), habits[1].id, UUID(), habits[4].id]
        #expect(
            WidgetHabitSelection.todayRows(from: snap, selecting: picked, limit: 8)
                .map(\.habit.name) == ["B", "E"]
        )
    }

    /// Every id gone is not the same as no pick at all: the user chose
    /// these habits, and none of them is showable, so the widget is
    /// empty and says so. Falling back to "all habits" here would
    /// silently hand back a tile full of habits they had excluded.
    @Test("A selection whose habits have all gone renders empty, not everything")
    func fullyStaleSelectionIsEmpty() {
        let (snap, _) = fixture()
        #expect(WidgetHabitSelection.todayRows(from: snap, selecting: [UUID()], limit: 8).isEmpty)
        #expect(WidgetHabitSelection.matrixRows(from: snap, selecting: [UUID()], limit: 8).isEmpty)
    }

    // MARK: - Limits

    @Test("A selection longer than the widget's capacity truncates to it")
    func selectionTruncatesToLimit() {
        let (snap, habits) = fixture()
        let picked = habits.map(\.id)
        #expect(
            WidgetHabitSelection.todayRows(from: snap, selecting: picked, limit: 2)
                .map(\.habit.name) == ["A", "B"]
        )
    }

    /// The picker has no notion of "already chosen", and a stored
    /// pick can be round-tripped oddly. A repeat must not burn a
    /// second slot on the same habit.
    @Test("A habit picked twice takes one slot")
    func duplicateIdsCollapse() {
        let (snap, habits) = fixture()
        let picked = [habits[0].id, habits[0].id, habits[1].id]
        #expect(
            WidgetHabitSelection.todayRows(from: snap, selecting: picked, limit: 8)
                .map(\.habit.name) == ["A", "B"]
        )
    }

    @Test("A zero or negative limit yields nothing rather than trapping")
    func nonPositiveLimitIsEmpty() {
        let (snap, habits) = fixture()
        #expect(WidgetHabitSelection.todayRows(from: snap, selecting: [], limit: 0).isEmpty)
        #expect(
            WidgetHabitSelection.todayRows(from: snap, selecting: [habits[0].id], limit: -1)
                .isEmpty
        )
    }

    // MARK: - The medium widget's summary

    /// With no pick the summary is the whole day, even when the tile
    /// can't fit it — eight of twelve rows still reports twelve,
    /// because that is the number the user is asking about.
    @Test("With no pick the summary counts the whole day, not just the visible rows")
    func progressWithoutPickCountsTheWholeDay() {
        let habits = (0..<12).map { habit("H\($0)") }
        let snap = WidgetSnapshot(
            generatedAt: .now,
            habits: habits,
            today: habits.map(todayRow),
            totalDueToday: 12,
            completedToday: 4,
            matrix: [],
            matrixDays: []
        )
        let progress = WidgetHabitSelection.progress(from: snap, selecting: [], limit: 8)
        #expect(progress.completed == 4)
        #expect(progress.total == 12)
    }

    /// With a pick it counts what the tile shows. Reporting the whole
    /// day here would summarise habits the widget deliberately hides.
    @Test("With a pick the summary counts only the picked rows")
    func progressWithPickCountsOnlyThePick() {
        let done = WidgetTodayRow(
            habit: habit("Done"),
            status: .complete,
            progress: 1,
            valueToday: 1,
            streak: 1,
            scorePercent: 100
        )
        let open = todayRow(habit("Open"))
        let extra = todayRow(habit("Extra"))
        let snap = WidgetSnapshot(
            generatedAt: .now,
            habits: [done.habit, open.habit, extra.habit],
            today: [done, open, extra],
            totalDueToday: 3,
            completedToday: 1,
            matrix: [],
            matrixDays: []
        )
        let progress = WidgetHabitSelection.progress(
            from: snap,
            selecting: [done.habit.id, open.habit.id],
            limit: 8
        )
        #expect(progress.completed == 1)
        #expect(progress.total == 2, "the unpicked third habit must not be counted")
    }

    /// The day's tally uses `HabitRowState.isDone`, where a negative
    /// habit's `.complete` is a *slip*. The picked summary has to count
    /// by the same rule, or "2 / 2 done" congratulates the user for
    /// giving in.
    @Test("A negative habit's slip is not done in the picked summary; its clean day is")
    func progressCountsNegativeHabitsByTheDayDoneRule() {
        let dont = WidgetHabit(
            id: UUID(), name: "No sugar", color: .red, icon: "nosign", typeKind: .negative, target: nil
        )
        let slipped = WidgetTodayRow(
            habit: dont, status: .complete, progress: 1, valueToday: 1, streak: 0, scorePercent: 40
        )
        let clean = todayRow(dont)

        let slippedDay = WidgetSnapshot(
            generatedAt: .now, habits: [dont], today: [slipped],
            totalDueToday: 1, completedToday: 0, matrix: [], matrixDays: []
        )
        #expect(
            WidgetHabitSelection.progress(from: slippedDay, selecting: [dont.id], limit: 5).completed == 0
        )

        let cleanDay = WidgetSnapshot(
            generatedAt: .now, habits: [dont], today: [clean],
            totalDueToday: 1, completedToday: 1, matrix: [], matrixDays: []
        )
        #expect(
            WidgetHabitSelection.progress(from: cleanDay, selecting: [dont.id], limit: 5).completed == 1
        )
    }

    // MARK: - Picked but not due today

    /// The case that reads as "my pick was lost": a habit chosen in the
    /// edit sheet that isn't scheduled today. It stays on the tile,
    /// marked not due, in its picked position — the user asked to see
    /// it, and a silent gap is indistinguishable from a broken pick.
    @Test("A picked habit that isn't due today is kept, marked not due, in pick order")
    func pickedNotDueHabitIsKeptAndMarked() {
        let (snap, habits) = fixture()
        let running = habit("Running")
        let withRunning = WidgetSnapshot(
            generatedAt: .now,
            habits: habits + [running],           // known to the app…
            today: snap.today,                     // …but not due today
            totalDueToday: snap.totalDueToday,
            completedToday: 0,
            matrix: snap.matrix,
            matrixDays: []
        )
        let rows = WidgetHabitSelection.todayRows(
            from: withRunning,
            selecting: [running.id, habits[1].id],
            limit: 5
        )
        #expect(rows.map(\.habit.name) == ["Running", "B"])
        #expect(rows.map(\.isDueToday) == [false, true])
        #expect(rows[0].status == .none)
    }

    /// Without a pick the tile is the day's to-do list, as it always
    /// was: nothing not-due is invented for it.
    @Test("With no pick, only due habits are shown — not-due ones are not invented")
    func noPickShowsOnlyDueRows() {
        let (snap, habits) = fixture()
        let running = habit("Running")
        let withRunning = WidgetSnapshot(
            generatedAt: .now,
            habits: habits + [running],
            today: snap.today,
            totalDueToday: snap.totalDueToday,
            completedToday: 0,
            matrix: snap.matrix,
            matrixDays: []
        )
        let rows = WidgetHabitSelection.todayRows(from: withRunning, selecting: [], limit: 8)
        #expect(rows.map(\.habit.name) == ["A", "B", "C", "D", "E"])
        #expect(rows.filter { !$0.isDueToday }.isEmpty)
    }

    /// A not-due pick isn't owed, so it is outside the summary: the
    /// count is over what is due among the pick, not over the pick.
    @Test("The picked summary counts only the due rows")
    func progressCountsOnlyDueRows() {
        let done = WidgetTodayRow(
            habit: habit("Done"), status: .complete, progress: 1, valueToday: 1, streak: 1, scorePercent: 100
        )
        let running = habit("Running")
        let snap = WidgetSnapshot(
            generatedAt: .now,
            habits: [done.habit, running],
            today: [done],
            totalDueToday: 1,
            completedToday: 1,
            matrix: [],
            matrixDays: []
        )
        let progress = WidgetHabitSelection.progress(
            from: snap, selecting: [running.id, done.habit.id], limit: 8
        )
        #expect(progress.completed == 1)
        #expect(progress.total == 1, "a habit that isn't due today is not owed")
    }

    /// The flag describes the read, not the record. The builder only
    /// ever writes due-or-logged rows, so a row decoded from the App
    /// Group file is due by definition — and a not-due row that
    /// somehow reached an encoder must not come back as not due.
    @Test("isDueToday is not persisted; a decoded row is due")
    func isDueTodayIsNotPersisted() throws {
        var row = todayRow(habit("A"))
        row.isDueToday = false
        let data = try JSONEncoder().encode(row)
        let decoded = try JSONDecoder().decode(WidgetTodayRow.self, from: data)
        #expect(decoded.isDueToday)
        #expect(decoded.habit.name == "A")
    }

    // MARK: - Resolving a stored pick

    /// `HabitEntityQuery.entities(for:)` is how AppIntents rebuilds a
    /// widget's stored pick on every reload, and it was the one seam in
    /// #76 with no coverage: the picker and the filter were each tested
    /// alone while the step between them re-sorted the user's choice.
    @Test("Resolution follows the requested order, not the snapshot's")
    func resolutionKeepsRequestedOrder() {
        let all = ["A", "B", "C", "D", "E"].map { habit($0) }
        let requested = [all[3].id, all[0].id, all[2].id]
        let resolved = WidgetHabitSelection.resolve(requested, in: all)
        #expect(resolved.map(\.name) == ["D", "A", "C"])
        #expect(resolved.map(\.id) == requested, "ids must come back in the order they went in")
    }

    /// A habit archived or deleted since the widget was configured takes
    /// only itself out. An empty result would reach the widget as "no
    /// pick", which means *show everything* — the choice ignored rather
    /// than reduced, with nothing on the tile to say so.
    @Test("An id with no habit behind it drops only itself")
    func missingIDDropsOnlyItself() {
        let all = ["A", "B", "C"].map { habit($0) }
        let resolved = WidgetHabitSelection.resolve([all[1].id, UUID(), all[0].id], in: all)
        #expect(resolved.map(\.name) == ["B", "A"])
    }

    @Test("A repeated id resolves once")
    func repeatedIDResolvesOnce() {
        let all = ["A", "B"].map { habit($0) }
        let resolved = WidgetHabitSelection.resolve([all[1].id, all[1].id, all[0].id], in: all)
        #expect(resolved.map(\.name) == ["B", "A"])
    }

    @Test("No identifiers, or no habits to resolve against, resolves to nothing")
    func emptyEitherSideResolvesEmpty() {
        let all = ["A"].map { habit($0) }
        #expect(WidgetHabitSelection.resolve([], in: all).isEmpty)
        #expect(WidgetHabitSelection.resolve(all.map(\.id), in: []).isEmpty)
    }

    // MARK: - The capacities themselves

    /// Pinned because they are a product decision, not an
    /// implementation detail — and because each is also written into a
    /// localized widget description the user reads in the gallery.
    @Test("The per-family capacities are 5 / 8 / 5")
    func capacities() {
        #expect(WidgetHabitLimit.small == 5)
        #expect(WidgetHabitLimit.medium == 8)
        #expect(WidgetHabitLimit.large == 5)
    }
}
