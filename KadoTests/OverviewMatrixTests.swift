import Testing
import Foundation
@testable import Kado

@Suite("OverviewMatrix")
@MainActor
struct OverviewMatrixTests {
    private let calendar = TestCalendar.utc
    private let today = TestCalendar.day(0) // 2026-04-13, a Monday

    private var scoreCalculator: DefaultHabitScoreCalculator {
        DefaultHabitScoreCalculator(calendar: calendar)
    }

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
            scoreCalculator: scoreCalculator,
            frequencyEvaluator: frequencyEvaluator
        )
        #expect(result.isEmpty)
    }

    @Test("Matrix emits one row per non-archived habit, sorted by createdAt")
    func rowOrder() {
        let older = Habit(
            name: "Older",
            frequency: .daily,
            type: .binary,
            createdAt: TestCalendar.day(-10)
        )
        let newer = Habit(
            name: "Newer",
            frequency: .daily,
            type: .binary,
            createdAt: TestCalendar.day(-5)
        )
        // Pass newer first to verify the matrix re-sorts by createdAt.
        let result = OverviewMatrix.compute(
            habits: [newer, older],
            completions: [],
            days: days(offset: -6, count: 7),
            today: today,
            calendar: calendar,
            scoreCalculator: scoreCalculator,
            frequencyEvaluator: frequencyEvaluator
        )
        #expect(result.map { $0.habit.id } == [older.id, newer.id])
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
            scoreCalculator: scoreCalculator,
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
            scoreCalculator: scoreCalculator,
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
            scoreCalculator: scoreCalculator,
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

    @Test("Cell is .scored(s) where s matches scoreHistory on due days")
    func scoredMatchesHistory() throws {
        let habit = Habit(
            name: "Read",
            frequency: .daily,
            type: .binary,
            createdAt: TestCalendar.day(-10)
        )
        let completion = Completion(
            habitID: habit.id,
            date: TestCalendar.day(-3),
            value: 1
        )
        let dayRange = days(offset: -6, count: 7)

        let result = OverviewMatrix.compute(
            habits: [habit],
            completions: [completion],
            days: dayRange,
            today: today,
            calendar: calendar,
            scoreCalculator: scoreCalculator,
            frequencyEvaluator: frequencyEvaluator
        )
        let row = try #require(result.first)

        // Independent computation from scoreHistory to compare against.
        let history = scoreCalculator.scoreHistory(
            for: habit,
            completions: [completion],
            from: try #require(dayRange.first),
            to: try #require(dayRange.last)
        )
        let expected = Dictionary(uniqueKeysWithValues: history.map { ($0.date, $0.score) })

        for (day, cell) in zip(dayRange, row.days) {
            if case .scored(let s) = cell {
                #expect(s == expected[day] ?? 0.0)
            }
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
            scoreCalculator: scoreCalculator,
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

    // MARK: - colorOpacity

    @Test("DayCell.colorOpacity is nil for future and notDue")
    func opacityNilForNonScored() {
        #expect(DayCell.future.colorOpacity == nil)
        #expect(DayCell.notDue.colorOpacity == nil)
    }

    @Test("DayCell.colorOpacity clamps scored to [0.08, 1.0]")
    func opacityClampsScored() {
        #expect(DayCell.scored(0.0).colorOpacity == 0.08)
        #expect(DayCell.scored(-1.0).colorOpacity == 0.08)
        #expect(DayCell.scored(0.5).colorOpacity == 0.5)
        #expect(DayCell.scored(1.0).colorOpacity == 1.0)
        #expect(DayCell.scored(2.0).colorOpacity == 1.0)
    }
}
