import Foundation
import SwiftData
import Testing
@testable import Kado
import KadoCore

@Suite("WidgetSnapshotBuilder")
@MainActor
struct WidgetSnapshotBuilderTests {
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: KadoSchemaV4.self)
        return try ModelContainer(
            for: schema,
            migrationPlan: KadoMigrationPlan.self,
            configurations: ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true
            )
        )
    }

    @Test("Empty container produces an empty snapshot")
    func emptyContainerEmptySnapshot() throws {
        let container = try makeContainer()
        let snapshot = WidgetSnapshotBuilder.build(from: container.mainContext)
        #expect(snapshot.habits.isEmpty)
        #expect(snapshot.today.isEmpty)
        #expect(snapshot.totalDueToday == 0)
        #expect(snapshot.completedToday == 0)
        #expect(snapshot.matrix.isEmpty)
    }

    @Test("Archived habits are excluded from habits, today, and matrix")
    func archivedExcluded() throws {
        let container = try makeContainer()
        let active = HabitRecord(name: "Active", frequency: .daily, type: .binary)
        let archived = HabitRecord(
            name: "Archived",
            frequency: .daily,
            type: .binary,
            archivedAt: .now
        )
        container.mainContext.insert(active)
        container.mainContext.insert(archived)
        try container.mainContext.save()

        let snapshot = WidgetSnapshotBuilder.build(from: container.mainContext)
        #expect(snapshot.habits.map(\.name) == ["Active"])
        #expect(snapshot.today.map(\.habit.name) == ["Active"])
        #expect(snapshot.matrix.map(\.habit.name) == ["Active"])
    }

    @Test("completedToday counts habits with status == .complete")
    func completedCount() throws {
        let container = try makeContainer()
        let a = HabitRecord(name: "A", frequency: .daily, type: .binary)
        let b = HabitRecord(name: "B", frequency: .daily, type: .binary)
        container.mainContext.insert(a)
        container.mainContext.insert(b)
        container.mainContext.insert(CompletionRecord(date: .now, value: 1, habit: a))
        try container.mainContext.save()

        let snapshot = WidgetSnapshotBuilder.build(from: container.mainContext)
        #expect(snapshot.totalDueToday == 2)
        #expect(snapshot.completedToday == 1)
    }

    @Test("Counter target is preserved in the widget habit")
    func counterTargetPreserved() throws {
        let container = try makeContainer()
        let habit = HabitRecord(
            name: "Water",
            frequency: .daily,
            type: .counter(target: 8)
        )
        container.mainContext.insert(habit)
        try container.mainContext.save()

        let snapshot = WidgetSnapshotBuilder.build(from: container.mainContext)
        let row = try #require(snapshot.today.first)
        #expect(row.habit.typeKind == .counter)
        #expect(row.habit.target == 8)
    }

    @Test("Matrix spans the configured day window")
    func matrixWindow() throws {
        let container = try makeContainer()
        container.mainContext.insert(
            HabitRecord(name: "A", frequency: .daily, type: .binary)
        )
        try container.mainContext.save()

        let snapshot = WidgetSnapshotBuilder.build(
            from: container.mainContext,
            matrixWindowDays: 5
        )
        #expect(snapshot.matrixDays.count == 5)
        #expect(snapshot.matrix.first?.cells.count == 5)
    }

    // MARK: - Per-habit stats on WidgetHabit

    @Test("Snapshot exposes current streak on every habit")
    func habitCurrentStreak() throws {
        let container = try makeContainer()
        let calendar = TestCalendar.utc
        let today = TestCalendar.day(0)
        let habit = HabitRecord(
            name: "Meditate",
            frequency: .daily,
            type: .binary,
            createdAt: TestCalendar.day(-10)
        )
        container.mainContext.insert(habit)
        // Three consecutive days ending today.
        for offset in 0...2 {
            container.mainContext.insert(
                CompletionRecord(date: TestCalendar.day(-offset), value: 1, habit: habit)
            )
        }
        try container.mainContext.save()

        let snapshot = WidgetSnapshotBuilder.build(
            from: container.mainContext,
            asOf: today,
            calendar: calendar
        )
        let widgetHabit = try #require(snapshot.habits.first)
        #expect(widgetHabit.currentStreak == 3)
    }

    @Test("Snapshot exposes best streak across history")
    func habitBestStreak() throws {
        let container = try makeContainer()
        let calendar = TestCalendar.utc
        let today = TestCalendar.day(0)
        let habit = HabitRecord(
            name: "Stretch",
            frequency: .daily,
            type: .binary,
            createdAt: TestCalendar.day(-30)
        )
        container.mainContext.insert(habit)
        // Five-day streak in the past, then a gap, then one today.
        for offset in (10...14).reversed() {
            container.mainContext.insert(
                CompletionRecord(date: TestCalendar.day(-offset), value: 1, habit: habit)
            )
        }
        container.mainContext.insert(
            CompletionRecord(date: today, value: 1, habit: habit)
        )
        try container.mainContext.save()

        let snapshot = WidgetSnapshotBuilder.build(
            from: container.mainContext,
            asOf: today,
            calendar: calendar
        )
        let widgetHabit = try #require(snapshot.habits.first)
        #expect(widgetHabit.bestStreak == 5)
        #expect(widgetHabit.currentStreak == 1)
    }

    @Test("Snapshot exposes score as Double in [0, 1]")
    func habitScoreInRange() throws {
        let container = try makeContainer()
        let calendar = TestCalendar.utc
        let today = TestCalendar.day(0)
        let habit = HabitRecord(
            name: "Read",
            frequency: .daily,
            type: .binary,
            createdAt: TestCalendar.day(-20)
        )
        container.mainContext.insert(habit)
        // Ten perfect days — score should be high but ≤ 1.
        for offset in 0...9 {
            container.mainContext.insert(
                CompletionRecord(date: TestCalendar.day(-offset), value: 1, habit: habit)
            )
        }
        try container.mainContext.save()

        let snapshot = WidgetSnapshotBuilder.build(
            from: container.mainContext,
            asOf: today,
            calendar: calendar
        )
        let widgetHabit = try #require(snapshot.habits.first)
        #expect(widgetHabit.currentScore >= 0.0)
        #expect(widgetHabit.currentScore <= 1.0)
        #expect(widgetHabit.currentScore > 0.0, "any completions should push the score above zero")
    }

    @Test("Snapshot replicates stats into matrix and today nested habits")
    func statsReplicatedIntoNestedHabits() throws {
        let container = try makeContainer()
        let calendar = TestCalendar.utc
        let today = TestCalendar.day(0)
        let habit = HabitRecord(
            name: "Walk",
            frequency: .daily,
            type: .binary,
            createdAt: TestCalendar.day(-10)
        )
        container.mainContext.insert(habit)
        for offset in 0...4 {
            container.mainContext.insert(
                CompletionRecord(date: TestCalendar.day(-offset), value: 1, habit: habit)
            )
        }
        try container.mainContext.save()

        let snapshot = WidgetSnapshotBuilder.build(
            from: container.mainContext,
            asOf: today,
            calendar: calendar
        )
        let topLevel = try #require(snapshot.habits.first)
        let todayNested = try #require(snapshot.today.first?.habit)
        let matrixNested = try #require(snapshot.matrix.first?.habit)

        #expect(topLevel.currentStreak == todayNested.currentStreak)
        #expect(topLevel.currentStreak == matrixNested.currentStreak)
        #expect(topLevel.currentScore == matrixNested.currentScore)
    }

    /// The large widget renders the percentage off the matrix row's
    /// own habit, while the today widgets render the one the builder
    /// baked into `WidgetTodayRow`. Both go through
    /// `WidgetHabit.scorePercent`, so pin that they agree — a habit
    /// showing 71% on one tile and 70% on the next is the visible
    /// form of this drifting apart.
    @Test("Today rows and matrix rows round the same habit to the same percent")
    func scorePercentAgreesAcrossSurfaces() throws {
        let container = try makeContainer()
        let calendar = TestCalendar.utc
        let today = TestCalendar.day(0)
        let habit = HabitRecord(
            name: "Walk",
            frequency: .daily,
            type: .binary,
            createdAt: TestCalendar.day(-10)
        )
        container.mainContext.insert(habit)
        for offset in 0...6 {
            container.mainContext.insert(
                CompletionRecord(date: TestCalendar.day(-offset), value: 1, habit: habit)
            )
        }
        try container.mainContext.save()

        let snapshot = WidgetSnapshotBuilder.build(
            from: container.mainContext,
            asOf: today,
            calendar: calendar
        )
        let todayRow = try #require(snapshot.today.first)
        let matrixHabit = try #require(snapshot.matrix.first?.habit)

        #expect(todayRow.scorePercent == matrixHabit.scorePercent)
        // Not `todayRow.scorePercent == todayRow.habit.scorePercent`:
        // the builder stores that habit and derives the field from it,
        // so those are the same expression on the same value and the
        // assertion could never fail. Seven perfect days instead —
        // enough that a percent of zero would mean the stats never
        // reached the row at all.
        #expect(todayRow.scorePercent > 0)
    }

    @Test("scorePercent rounds to whole percent and clamps a score out of 0...1")
    func scorePercentRoundsAndClamps() {
        func habit(score: Double) -> WidgetHabit {
            WidgetHabit(
                id: UUID(),
                name: "Walk",
                color: .blue,
                icon: "figure.walk",
                typeKind: .binary,
                target: nil,
                currentScore: score
            )
        }

        #expect(habit(score: 0).scorePercent == 0)
        #expect(habit(score: 1).scorePercent == 100)
        #expect(habit(score: 0.704).scorePercent == 70)
        #expect(habit(score: 0.705).scorePercent == 71)
        // Values reach the widget through App Group JSON nothing
        // revalidates, so out-of-range input must not print "-300%".
        #expect(habit(score: -3).scorePercent == 0)
        #expect(habit(score: 12).scorePercent == 100)
    }

    // MARK: - Off-schedule completions (issue #57)

    @Test("A habit completed today past its weekly quota still appears in today's rows")
    func bonusCompletionStaysInTodayRows() throws {
        let container = try makeContainer()
        let calendar = TestCalendar.utc
        let today = TestCalendar.day(0)
        let habit = HabitRecord(
            name: "Run",
            frequency: .daysPerWeek(3),
            type: .binary,
            createdAt: TestCalendar.day(-30)
        )
        container.mainContext.insert(habit)
        // Quota already met by three earlier days in the window, then
        // a bonus run today. The habit must not vanish from the widget
        // the moment it is completed — and its tick must still count.
        for offset in [-3, -2, -1, 0] {
            container.mainContext.insert(
                CompletionRecord(date: TestCalendar.day(offset), value: 1, habit: habit)
            )
        }
        try container.mainContext.save()

        let snapshot = WidgetSnapshotBuilder.build(
            from: container.mainContext,
            asOf: today,
            calendar: calendar
        )
        #expect(snapshot.today.count == 1)
        #expect(snapshot.totalDueToday == 1)
        #expect(snapshot.completedToday == 1)
        #expect(snapshot.today.first?.status == .complete)
    }

    @Test("Matrix maps off-schedule completions through to the widget cell")
    func matrixCarriesOffScheduleCells() throws {
        let container = try makeContainer()
        let calendar = TestCalendar.utc
        let today = TestCalendar.day(0)
        // Monday-only habit; day 0 is a Monday, so day -2 (Saturday)
        // is off schedule but was logged anyway.
        let habit = HabitRecord(
            name: "Gym",
            frequency: .specificDays([.monday]),
            type: .binary,
            createdAt: TestCalendar.day(-30)
        )
        container.mainContext.insert(habit)
        container.mainContext.insert(
            CompletionRecord(date: TestCalendar.day(-2), value: 1, habit: habit)
        )
        try container.mainContext.save()

        let snapshot = WidgetSnapshotBuilder.build(
            from: container.mainContext,
            asOf: today,
            calendar: calendar,
            matrixWindowDays: 7
        )
        let cells = try #require(snapshot.matrix.first?.cells)
        #expect(cells[4] == .offSchedule(1.0))
        // The schedule is still legible around it: the untouched
        // Sunday stays neutral and Monday stays a scored miss.
        #expect(cells[5] == .notDue)
        #expect(cells[6] == .scored(0.0))
    }

    @Test("A negative habit counts as done until it slips")
    func negativeHabitCountsUntilItSlips() throws {
        let container = try makeContainer()
        let read = HabitRecord(name: "Read", frequency: .daily, type: .binary)
        let noSugar = HabitRecord(name: "No sugar", frequency: .daily, type: .negative)
        container.mainContext.insert(read)
        container.mainContext.insert(noSugar)
        container.mainContext.insert(CompletionRecord(date: .now, value: 1, habit: read))
        try container.mainContext.save()

        // Nothing recorded against "No sugar" is the win, so with the
        // book read the day is whole.
        let kept = WidgetSnapshotBuilder.build(from: container.mainContext)
        #expect(kept.dayProgress == DayProgress(completed: 2, total: 2))
        #expect(kept.dayProgress.isComplete)

        // A slip is a record — `.complete` on the row — but it takes
        // the day *away*, and must never read as the last habit done.
        container.mainContext.insert(CompletionRecord(date: .now, value: 1, habit: noSugar))
        try container.mainContext.save()

        let slipped = WidgetSnapshotBuilder.build(from: container.mainContext)
        #expect(slipped.today.first { $0.habit.name == "No sugar" }?.status == .complete)
        #expect(slipped.dayProgress == DayProgress(completed: 1, total: 2))
        #expect(!slipped.dayProgress.isComplete)
    }

    // MARK: - Upcoming days

    /// The series is what makes the widget roll over without the app:
    /// each day after the first is "that morning, nothing further
    /// logged". These pin what that means per habit shape — the due
    /// set moves, the ticks clear, and a streak answers for *that*
    /// morning rather than copying today's.

    @Test("A series covers consecutive logical days, each anchored on its own trailing matrix day")
    func seriesCoversConsecutiveDays() throws {
        let container = try makeContainer()
        let calendar = TestCalendar.utc
        container.mainContext.insert(HabitRecord(name: "A", frequency: .daily, type: .binary))
        try container.mainContext.save()

        let series = WidgetSnapshotBuilder.buildSeries(
            from: container.mainContext,
            asOf: TestCalendar.day(0),
            calendar: calendar,
            horizonDays: 7
        )
        let expected = (0..<7).map { calendar.startOfDay(for: TestCalendar.day($0)) }
        #expect(series.days.map(\.logicalDay) == expected)
        for day in series.days {
            #expect(day.matrixDays.last == day.logicalDay)
        }
    }

    @Test("Tomorrow starts clean: today's tick is gone and the row is back to none")
    func tomorrowStartsClean() throws {
        let container = try makeContainer()
        let calendar = TestCalendar.utc
        let habit = HabitRecord(
            name: "Water",
            frequency: .daily,
            type: .counter(target: 8),
            createdAt: TestCalendar.day(-10)
        )
        container.mainContext.insert(habit)
        container.mainContext.insert(CompletionRecord(date: TestCalendar.day(0), value: 8, habit: habit))
        try container.mainContext.save()

        let series = WidgetSnapshotBuilder.buildSeries(
            from: container.mainContext,
            asOf: TestCalendar.day(0),
            calendar: calendar,
            horizonDays: 2
        )
        let today = try #require(series.days.first)
        #expect(today.completedToday == 1)
        #expect(today.today.first?.status == .complete)

        let tomorrow = try #require(series.days.dropFirst().first)
        let row = try #require(tomorrow.today.first)
        #expect(tomorrow.completedToday == 0)
        #expect(tomorrow.totalDueToday == 1)
        #expect(row.status == .none)
        #expect(row.progress == 0.0)
        #expect(row.valueToday == nil)
    }

    @Test("A bonus completion keeps today's row but leaves tomorrow's")
    func bonusCompletionLeavesTomorrowsRows() throws {
        let container = try makeContainer()
        let calendar = TestCalendar.utc
        let habit = HabitRecord(
            name: "Run",
            frequency: .daysPerWeek(1),
            type: .binary,
            createdAt: TestCalendar.day(-30)
        )
        container.mainContext.insert(habit)
        container.mainContext.insert(CompletionRecord(date: TestCalendar.day(0), value: 1, habit: habit))
        try container.mainContext.save()

        let series = WidgetSnapshotBuilder.buildSeries(
            from: container.mainContext,
            asOf: TestCalendar.day(0),
            calendar: calendar,
            horizonDays: 2
        )
        // Today: quota met by today's run, kept by the "or logged" arm.
        #expect(series.days[0].today.map(\.habit.name) == ["Run"])
        // Tomorrow: the week's quota is met and nothing is logged, so
        // the widget must not ask for it.
        #expect(series.days[1].today.isEmpty)
        #expect(series.days[1].totalDueToday == 0)
    }

    @Test("A specific-days habit is absent today and present on its day tomorrow")
    func specificDaysAppearOnTheirDay() throws {
        let container = try makeContainer()
        let calendar = TestCalendar.utc
        // Day 0 is a Monday; a Tuesday-only habit is tomorrow's business.
        let habit = HabitRecord(
            name: "Gym",
            frequency: .specificDays([.tuesday]),
            type: .binary,
            createdAt: TestCalendar.day(-30)
        )
        container.mainContext.insert(habit)
        try container.mainContext.save()

        let series = WidgetSnapshotBuilder.buildSeries(
            from: container.mainContext,
            asOf: TestCalendar.day(0),
            calendar: calendar,
            horizonDays: 2
        )
        #expect(series.days[0].today.isEmpty)
        #expect(series.days[1].today.map(\.habit.name) == ["Gym"])
        #expect(series.days[1].totalDueToday == 1)
    }

    @Test("Tomorrow's streak is tomorrow morning's truth: alive if today was done, broken if not")
    func tomorrowsStreakReflectsTodaysOutcome() throws {
        let container = try makeContainer()
        let calendar = TestCalendar.utc
        let habit = HabitRecord(
            name: "Meditate",
            frequency: .daily,
            type: .binary,
            createdAt: TestCalendar.day(-10)
        )
        container.mainContext.insert(habit)
        container.mainContext.insert(CompletionRecord(date: TestCalendar.day(-1), value: 1, habit: habit))
        try container.mainContext.save()

        // Only yesterday done: as of tomorrow, today is a miss.
        let missed = WidgetSnapshotBuilder.buildSeries(
            from: container.mainContext,
            asOf: TestCalendar.day(0),
            calendar: calendar,
            horizonDays: 2
        )
        #expect(missed.days[0].habits.first?.currentStreak == 1)
        #expect(missed.days[1].habits.first?.currentStreak == 0)

        container.mainContext.insert(CompletionRecord(date: TestCalendar.day(0), value: 1, habit: habit))
        try container.mainContext.save()

        let kept = WidgetSnapshotBuilder.buildSeries(
            from: container.mainContext,
            asOf: TestCalendar.day(0),
            calendar: calendar,
            horizonDays: 2
        )
        #expect(kept.days[0].habits.first?.currentStreak == 2)
        #expect(kept.days[1].habits.first?.currentStreak == 2)
        #expect(kept.days[1].today.first?.streak == 2)
    }

    @Test("A negative habit is done tomorrow until it slips, as on Today")
    func negativeHabitIsDoneTomorrow() throws {
        let container = try makeContainer()
        let calendar = TestCalendar.utc
        container.mainContext.insert(
            HabitRecord(
                name: "No sugar",
                frequency: .daily,
                type: .negative,
                createdAt: TestCalendar.day(-10)
            )
        )
        try container.mainContext.save()

        let series = WidgetSnapshotBuilder.buildSeries(
            from: container.mainContext,
            asOf: TestCalendar.day(0),
            calendar: calendar,
            horizonDays: 2
        )
        #expect(series.days[1].dayProgress == DayProgress(completed: 1, total: 1))
    }
}
