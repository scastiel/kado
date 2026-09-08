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
    /// — archived, deleted, or simply not due today — closes up rather
    /// than leaving a gap, and never costs one of the remaining slots.
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
