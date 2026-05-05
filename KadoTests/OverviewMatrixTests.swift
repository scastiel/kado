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

    // MARK: - colorOpacity

    @Test("DayCell.colorOpacity is nil for future and notDue")
    func opacityNilForNonScored() {
        #expect(DayCell.future.colorOpacity == nil)
        #expect(DayCell.notDue.colorOpacity == nil)
    }

    @Test("DayCell.colorOpacity maps scored linearly to [0.2, 1.0]")
    func opacityMapsScoredLinearly() {
        func approx(_ cell: DayCell, _ expected: Double) -> Bool {
            guard let actual = cell.colorOpacity else { return false }
            return abs(actual - expected) < 1e-9
        }
        #expect(approx(.scored(0.0), 0.2))
        #expect(approx(.scored(-1.0), 0.2))
        #expect(approx(.scored(0.5), 0.6))
        #expect(approx(.scored(1.0), 1.0))
        #expect(approx(.scored(2.0), 1.0))
    }
}
