import Testing
import Foundation
@testable import Kado
import KadoCore

@Suite("OverviewMatrix")
@MainActor
struct OverviewMatrixTests {
    private let calendar = TestCalendar.utc
    private let today = TestCalendar.day(0) // 2026-04-13, a Monday

    private var frequencyEvaluator: DefaultFrequencyEvaluator {
        DefaultFrequencyEvaluator(calendar: calendar)
    }

    /// `count` consecutive day-anchors starting at `TestCalendar.day(start)`.
    /// Each entry is `startOfDay` so comparisons against today are stable.
    private func days(offset start: Int, count: Int) -> [Date] {
        (0..<count).map { TestCalendar.day(start + $0) }
            .map { calendar.startOfDay(for: $0) }
    }

    @Test("Empty habit list yields empty matrix")
    func emptyHabits() {
        let result = OverviewMatrix.compute(
            habits: [],
            completions: [],
            days: days(offset: -6, count: 7),
            today: today,
            calendar: calendar,
            frequencyEvaluator: frequencyEvaluator
        )
        #expect(result.isEmpty)
    }

    @Test("Matrix emits one row per non-archived habit, sorted by sortOrder")
    func rowOrder() {
        let first = Habit(
            name: "First",
            frequency: .daily,
            type: .binary,
            createdAt: TestCalendar.day(-5),
            sortOrder: 0
        )
        let second = Habit(
            name: "Second",
            frequency: .daily,
            type: .binary,
            createdAt: TestCalendar.day(-10),
            sortOrder: 1
        )
        // Pass second first to verify the matrix re-sorts by sortOrder.
        let result = OverviewMatrix.compute(
            habits: [second, first],
            completions: [],
            days: days(offset: -6, count: 7),
            today: today,
            calendar: calendar,
            frequencyEvaluator: frequencyEvaluator
        )
        #expect(result.map { $0.habit.id } == [first.id, second.id])
    }

    @Test("Archived habits are excluded")
    func archivedExcluded() {
        let active = Habit(
            name: "Active",
            frequency: .daily,
            type: .binary,
            createdAt: TestCalendar.day(-10)
        )
        let archived = Habit(
            name: "Archived",
            frequency: .daily,
            type: .binary,
            createdAt: TestCalendar.day(-10),
            archivedAt: TestCalendar.day(-2)
        )
        let result = OverviewMatrix.compute(
            habits: [active, archived],
            completions: [],
            days: days(offset: -6, count: 7),
            today: today,
            calendar: calendar,
            frequencyEvaluator: frequencyEvaluator
        )
        #expect(result.count == 1)
        #expect(result.first?.habit.id == active.id)
    }

    @Test("Cell is .future for days beyond today")
    func futureCells() throws {
        let habit = Habit(
            name: "Habit",
            frequency: .daily,
            type: .binary,
            createdAt: TestCalendar.day(-10)
        )
        let result = OverviewMatrix.compute(
            habits: [habit],
            completions: [],
            days: days(offset: 1, count: 3),
            today: today,
            calendar: calendar,
            frequencyEvaluator: frequencyEvaluator
        )
        let row = try #require(result.first)
        #expect(row.days.allSatisfy { $0 == .future })
    }

    @Test("Cell is .notDue when FrequencyEvaluator says the day is not due")
    func notDueCells() throws {
        // specific-days habit that only runs on Monday; 2026-04-13 is a Monday.
        let habit = Habit(
            name: "Gym",
            frequency: .specificDays([.monday]),
            type: .binary,
            createdAt: TestCalendar.day(-10)
        )
        let dayRange = days(offset: -6, count: 7) // Tue..Mon
        let result = OverviewMatrix.compute(
            habits: [habit],
            completions: [],
            days: dayRange,
            today: today,
            calendar: calendar,
            frequencyEvaluator: frequencyEvaluator
        )
        let row = try #require(result.first)
        // Only today (Monday) is due; the prior six days are not-due.
        let scoredCount = row.days.filter {
            if case .scored = $0 { return true } else { return false }
        }.count
        let notDueCount = row.days.filter { $0 == .notDue }.count
        #expect(scoredCount == 1)
        #expect(notDueCount == 6)
    }

    @Test("Scored cells reflect the day's completion value (not the EMA score)")
    func scoredReflectsDailyValue() throws {
        // Daily binary habit with a completion exactly two days ago.
        let habit = Habit(
            name: "Read",
            frequency: .daily,
            type: .binary,
            createdAt: TestCalendar.day(-10)
        )
        let completion = Completion(
            habitID: habit.id,
            date: TestCalendar.day(-2),
            value: 1
        )
        let dayRange = days(offset: -4, count: 5) // -4..0

        let result = OverviewMatrix.compute(
            habits: [habit],
            completions: [completion],
            days: dayRange,
            today: today,
            calendar: calendar,
            frequencyEvaluator: frequencyEvaluator
        )
        let row = try #require(result.first)

        // The effective start is day -2 (the first completion), so
        // days -4 and -3 are .notDue. Day -2 is scored 1.0; days -1
        // and 0 are scored 0.0 (due but not completed).
        let values: [Double] = row.days.map { cell in
            if case .scored(let v) = cell { v } else { -1 }
        }
        #expect(values == [-1.0, -1.0, 1.0, 0.0, 0.0])
    }

    @Test("Counter habit scored cells use achieved/target fraction")
    func counterPartialValue() throws {
        let habit = Habit(
            name: "Drink water",
            frequency: .daily,
            type: .counter(target: 8),
            createdAt: TestCalendar.day(-5)
        )
        // Today: 6 of 8 → 0.75.
        let completion = Completion(
            habitID: habit.id,
            date: TestCalendar.day(0),
            value: 6
        )
        let result = OverviewMatrix.compute(
            habits: [habit],
            completions: [completion],
            days: days(offset: 0, count: 1),
            today: today,
            calendar: calendar,
            frequencyEvaluator: frequencyEvaluator
        )
        let row = try #require(result.first)
        let cell = try #require(row.days.first)
        if case .scored(let v) = cell {
            #expect(v == 0.75)
        } else {
            Issue.record("Expected .scored, got \(cell)")
        }
    }

    @Test("Cell is .notDue on days before the habit was created")
    func preCreationIsNotDue() throws {
        let habit = Habit(
            name: "Habit",
            frequency: .daily,
            type: .binary,
            createdAt: TestCalendar.day(-2) // created 2 days ago
        )
        // Range goes back 5 days, past creation.
        let dayRange = days(offset: -5, count: 6) // -5 .. 0
        let result = OverviewMatrix.compute(
            habits: [habit],
            completions: [],
            days: dayRange,
            today: today,
            calendar: calendar,
            frequencyEvaluator: frequencyEvaluator
        )
        let row = try #require(result.first)
        let preCreation = row.days.prefix(3) // -5, -4, -3
        let postCreation = row.days.suffix(3) // -2, -1, 0
        #expect(preCreation.allSatisfy { $0 == .notDue })
        #expect(postCreation.allSatisfy {
            if case .scored = $0 { return true } else { return false }
        })
    }

    @Test("Pre-creation day with a backdated completion renders as .scored")
    func preCreationWithCompletionIsScored() throws {
        let habit = Habit(
            name: "Habit",
            frequency: .daily,
            type: .binary,
            createdAt: TestCalendar.day(-2)
        )
        let completions = [
            Completion(habitID: habit.id, date: TestCalendar.day(-4)),
        ]
        let dayRange = days(offset: -5, count: 6)
        let result = OverviewMatrix.compute(
            habits: [habit],
            completions: completions,
            days: dayRange,
            today: today,
            calendar: calendar,
            frequencyEvaluator: frequencyEvaluator
        )
        let row = try #require(result.first)
        let preEffective = row.days[0] // day -5: before effective start (-4)
        let atEffective = row.days[1]  // day -4: effective start, completed
        #expect(preEffective == .notDue)
        if case .scored(let v) = atEffective {
            #expect(v == 1.0)
        } else {
            Issue.record("Expected .scored at effective start, got \(atEffective)")
        }
    }

    // MARK: - Off-schedule completions (issue #57)

    @Test("A completion on a non-due day renders .offSchedule, never .notDue")
    func completionOnNonDueDayIsOffSchedule() throws {
        // Monday-only habit; day -6 .. day 0 is Tue..Mon. The user
        // logged the Saturday (day -2) anyway.
        let habit = Habit(
            name: "Gym",
            frequency: .specificDays([.monday]),
            type: .binary,
            createdAt: TestCalendar.day(-10)
        )
        let completions = [
            Completion(habitID: habit.id, date: TestCalendar.day(-2), value: 1)
        ]
        let result = OverviewMatrix.compute(
            habits: [habit],
            completions: completions,
            days: days(offset: -6, count: 7),
            today: today,
            calendar: calendar,
            frequencyEvaluator: frequencyEvaluator
        )
        let row = try #require(result.first)
        #expect(row.days[4] == .offSchedule(1.0))
        // The untouched non-Mondays stay grey; Monday stays scored.
        #expect(row.days[0] == .notDue)
        #expect(row.days[6] == .scored(0.0))
    }

    @Test("A back-filled daysPerWeek day is visible once the quota is already met")
    func backFilledDaysPerWeekDayIsVisible() throws {
        // The reported scenario: five completions inside the trailing
        // window, then one more back-filled behind them.
        let habit = Habit(
            name: "Run",
            frequency: .daysPerWeek(5),
            type: .binary,
            createdAt: TestCalendar.day(-30)
        )
        let completions = [-6, -5, -4, -3, -2, -1].map {
            Completion(habitID: habit.id, date: TestCalendar.day($0), value: 1)
        }
        let result = OverviewMatrix.compute(
            habits: [habit],
            completions: completions,
            days: days(offset: -6, count: 7),
            today: today,
            calendar: calendar,
            frequencyEvaluator: frequencyEvaluator
        )
        let row = try #require(result.first)
        // Every logged day reads as done — as `.scored` while the
        // quota still had room, as `.offSchedule` for the sixth.
        #expect(row.days[5] == .offSchedule(1.0))
        #expect(row.days.prefix(5).allSatisfy { $0 == .scored(1.0) })
        // Today has no completion and the quota is met → grey.
        #expect(row.days[6] == .notDue)
    }

    @Test("Off-schedule cells never hide a completion for any frequency")
    func noCompletionEverRendersNotDue() throws {
        let frequencies: [Frequency] = [
            .daily,
            .specificDays([.monday]),
            .everyNDays(4),
            .daysPerWeek(2),
        ]
        for frequency in frequencies {
            let habit = Habit(
                name: "H",
                frequency: frequency,
                type: .binary,
                createdAt: TestCalendar.day(-20)
            )
            let completions = (-6...0).map {
                Completion(habitID: habit.id, date: TestCalendar.day($0), value: 1)
            }
            let result = OverviewMatrix.compute(
                habits: [habit],
                completions: completions,
                days: days(offset: -6, count: 7),
                today: today,
                calendar: calendar,
                frequencyEvaluator: frequencyEvaluator
            )
            let row = try #require(result.first)
            #expect(!row.days.contains(.notDue), "\(frequency) hid a completed day")
        }
    }

    @Test("A negative habit's off-schedule slip carries value 0")
    func negativeOffScheduleSlip() throws {
        // Monday-only negative habit; a "completion" is a slip. The
        // slip lands on a Saturday the schedule doesn't cover.
        let habit = Habit(
            name: "No smoking",
            frequency: .specificDays([.monday]),
            type: .negative,
            createdAt: TestCalendar.day(-10)
        )
        let completions = [
            Completion(habitID: habit.id, date: TestCalendar.day(-2), value: 1)
        ]
        let result = OverviewMatrix.compute(
            habits: [habit],
            completions: completions,
            days: days(offset: -6, count: 7),
            today: today,
            calendar: calendar,
            frequencyEvaluator: frequencyEvaluator
        )
        let row = try #require(result.first)
        #expect(row.days[4] == .offSchedule(0.0))
        // A clean non-scheduled day stays grey rather than claiming
        // an off-schedule success.
        #expect(row.days[3] == .notDue)
    }

    // MARK: - Cell appearance

    @Test("Future days draw nothing at all")
    func futureIsEmpty() {
        #expect(DayCell.future.appearance == .empty)
    }

    @Test("A missed day is neutral, not a faint version of the habit hue")
    func missedIsNeutral() {
        // The previous continuous ramp floored scored cells at 0.2
        // opacity of the habit color, which made "scheduled and
        // skipped" and "barely started" the same picture. They are the
        // two states a grid most needs to tell apart.
        #expect(DayCell.scored(0.0).appearance == .missed)
        #expect(DayCell.scored(-1.0).appearance == .missed)
        #expect(DayCell.notDue.appearance == .notScheduled)
        #expect(DayCell.scored(0.0).appearance != DayCell.notDue.appearance)
    }

    @Test("Scored days step through three intensities of one hue")
    func scoredRamp() {
        #expect(DayCell.scored(0.1).appearance == .hue(opacity: KadoTint.tileLight, ringed: false))
        #expect(DayCell.scored(0.49).appearance == .hue(opacity: KadoTint.tileLight, ringed: false))
        #expect(DayCell.scored(0.5).appearance == .hue(opacity: KadoTint.tilePartial, ringed: false))
        #expect(DayCell.scored(0.99).appearance == .hue(opacity: KadoTint.tilePartial, ringed: false))
        #expect(DayCell.scored(1.0).appearance == .hue(opacity: 1, ringed: false))
        #expect(DayCell.scored(2.0).appearance == .hue(opacity: 1, ringed: false))
    }

    @Test("The ramp never decreases as the day's value rises")
    func rampIsMonotonic() throws {
        func opacity(_ value: Double) throws -> Double {
            switch DayCell.scored(value).appearance {
            case .hue(let opacity, _): return opacity
            case .missed: return 0
            default: throw TestFailure()
            }
        }
        let samples = stride(from: 0.0, through: 1.0, by: 0.05).map { $0 }
        for (lower, higher) in zip(samples, samples.dropFirst()) {
            #expect(try opacity(lower) <= opacity(higher))
        }
    }

    @Test("Only off-schedule cells are ringed, and they never fill solid")
    func offScheduleIsRingedAndPale() {
        // The ring is the only thing saying "you logged this on a day
        // nothing was asked of you". A solid fill under a solid ring is
        // invisible, so the interior stays pale at every value.
        for value in [0.0, 0.5, 1.0] {
            #expect(
                DayCell.offSchedule(value).appearance
                    == .hue(opacity: KadoTint.tileLight, ringed: true)
            )
        }
        for cell: DayCell in [.future, .notDue, .scored(0.0), .scored(1.0)] {
            if case .hue(_, ringed: true) = cell.appearance {
                Issue.record("\(cell) should not be ringed")
            }
        }
    }

    // MARK: - Summary

    @Test("Summary counts scheduled days only")
    func summaryCountsScheduledDaysOnly() {
        let habit = Habit(name: "H", frequency: .daily, type: .binary, createdAt: .now)
        let rows = [
            MatrixRow(habit: habit, days: [
                .scored(1.0), .scored(0.0), .scored(0.5),
                .notDue, .future, .offSchedule(1.0),
            ])
        ]
        let summary = OverviewMatrix.summary(for: rows, lastDays: 6)
        // notDue / future were never asked for; offSchedule is credit
        // for a day the schedule didn't claim. Counting any of them
        // would make the denominator meaningless.
        #expect(summary.scheduledDays == 3)
        #expect(summary.loggedDays == 2)
    }

    @Test("Summary aggregates across habits and honours the window")
    func summaryWindowAndAggregation() {
        let a = Habit(name: "A", frequency: .daily, type: .binary, createdAt: .now)
        let b = Habit(name: "B", frequency: .daily, type: .binary, createdAt: .now)
        let rows = [
            // Only the trailing three columns are in the window, so the
            // leading `.scored(1.0)` must not be counted.
            MatrixRow(habit: a, days: [.scored(1.0), .scored(1.0), .scored(0.0), .scored(1.0)]),
            MatrixRow(habit: b, days: [.scored(0.0), .scored(0.0), .scored(1.0), .scored(0.0)]),
        ]
        let summary = OverviewMatrix.summary(for: rows, lastDays: 3)
        #expect(summary.scheduledDays == 6)
        #expect(summary.loggedDays == 3)
    }

    @Test("An empty grid summarises as zero rather than trapping")
    func summaryEmpty() {
        #expect(OverviewMatrix.summary(for: [], lastDays: 10) == OverviewSummary(loggedDays: 0, scheduledDays: 0))

        let habit = Habit(name: "H", frequency: .daily, type: .binary, createdAt: .now)
        let rows = [MatrixRow(habit: habit, days: [.scored(1.0)])]
        // A window wider than the data, and one narrower than nothing.
        #expect(OverviewMatrix.summary(for: rows, lastDays: 99).scheduledDays == 1)
        #expect(OverviewMatrix.summary(for: rows, lastDays: 0).scheduledDays == 0)
        #expect(OverviewMatrix.summary(for: rows, lastDays: -5).scheduledDays == 0)
    }
}

/// Thrown by a test helper that reached a case its caller had already
/// ruled out — surfaces as a failure rather than a silent default.
private struct TestFailure: Error {}
