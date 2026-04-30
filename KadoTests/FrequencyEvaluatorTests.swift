import Testing
import Foundation
@testable import Kado
import KadoCore

@Suite("FrequencyEvaluator")
struct FrequencyEvaluatorTests {
    let evaluator = DefaultFrequencyEvaluator(calendar: TestCalendar.utc)

    // MARK: Lifecycle bounds

    @Test("Day before createdAt with no completions is not due")
    func notDueBeforeCreatedNoCompletions() {
        let habit = makeHabit(.daily, createdOffset: 0)
        #expect(!evaluator.isDue(habit: habit, on: TestCalendar.day(-1), completions: []))
    }

    @Test("Day before createdAt with a completion on that day is due")
    func dueBeforeCreatedWithCompletion() {
        let habit = makeHabit(.daily, createdOffset: 0)
        let completions = [Completion(habitID: habit.id, date: TestCalendar.day(-1))]
        #expect(evaluator.isDue(habit: habit, on: TestCalendar.day(-1), completions: completions))
    }

    @Test("Day before effective start is not due")
    func notDueBeforeEffectiveStart() {
        let habit = makeHabit(.daily, createdOffset: 0)
        let completions = [Completion(habitID: habit.id, date: TestCalendar.day(-3))]
        #expect(!evaluator.isDue(habit: habit, on: TestCalendar.day(-5), completions: completions))
    }

    @Test("Day after archivedAt is never due")
    func notDueAfterArchived() {
        let habit = makeHabit(.daily, createdOffset: 0, archivedOffset: 5)
        #expect(!evaluator.isDue(habit: habit, on: TestCalendar.day(6), completions: []))
    }

    @Test("Day equal to archivedAt is still due")
    func dueOnArchivalDay() {
        let habit = makeHabit(.daily, createdOffset: 0, archivedOffset: 5)
        #expect(evaluator.isDue(habit: habit, on: TestCalendar.day(5), completions: []))
    }

    // MARK: .daily

    @Test("Daily habit is due every day")
    func dailyAlwaysDue() {
        let habit = makeHabit(.daily, createdOffset: 0)
        for offset in 0..<14 {
            #expect(evaluator.isDue(habit: habit, on: TestCalendar.day(offset), completions: []))
        }
    }

    // MARK: .specificDays

    @Test("Specific-days habit is due only on listed weekdays")
    func specificDaysOnly() {
        // Day 0 is Monday. Pattern: Mon=0, Tue=1, …, Sun=6.
        let habit = makeHabit(
            .specificDays([.monday, .wednesday, .friday]),
            createdOffset: 0
        )
        let expected: [(offset: Int, due: Bool)] = [
            (0, true),   // Mon
            (1, false),  // Tue
            (2, true),   // Wed
            (3, false),  // Thu
            (4, true),   // Fri
            (5, false),  // Sat
            (6, false),  // Sun
            (7, true),   // Mon
        ]
        for (offset, due) in expected {
            #expect(
                evaluator.isDue(habit: habit, on: TestCalendar.day(offset), completions: []) == due,
                "offset \(offset) expected due=\(due)"
            )
        }
    }

    // MARK: .everyNDays

    @Test("Every-3-days habit is due on createdAt and every third day after")
    func everyNDaysCadence() {
        let habit = makeHabit(.everyNDays(3), createdOffset: 0)
        let dueOffsets: Set<Int> = [0, 3, 6, 9, 12]
        for offset in 0...12 {
            let isDue = evaluator.isDue(habit: habit, on: TestCalendar.day(offset), completions: [])
            #expect(isDue == dueOffsets.contains(offset), "offset \(offset)")
        }
    }

    // MARK: .daysPerWeek (trailing 7-day rolling window)

    @Test("3-per-week habit is due when trailing 7-day window has zero completions")
    func daysPerWeekDueWhenEmpty() {
        let habit = makeHabit(.daysPerWeek(3), createdOffset: 0)
        #expect(evaluator.isDue(habit: habit, on: TestCalendar.day(7), completions: []))
    }

    @Test("3-per-week habit is not due once 3 completions exist in the trailing window")
    func daysPerWeekRollingQuota() {
        let habit = makeHabit(.daysPerWeek(3), createdOffset: 0)
        let completions = [
            Completion(habitID: habit.id, date: TestCalendar.day(1)),
            Completion(habitID: habit.id, date: TestCalendar.day(3)),
            Completion(habitID: habit.id, date: TestCalendar.day(5)),
        ]
        // Day 5: window is days -1...5, three completions present → not due.
        #expect(!evaluator.isDue(habit: habit, on: TestCalendar.day(5), completions: completions))
        // Day 7: window is days 1...7, still three completions → not due.
        #expect(!evaluator.isDue(habit: habit, on: TestCalendar.day(7), completions: completions))
        // Day 8: window is days 2...8, day 1 falls out → only two completions → due.
        #expect(evaluator.isDue(habit: habit, on: TestCalendar.day(8), completions: completions))
    }

    @Test("daysPerWeek ignores completions for unrelated habits")
    func daysPerWeekIgnoresOtherHabits() {
        let habit = makeHabit(.daysPerWeek(3), createdOffset: 0)
        let otherID = UUID()
        let completions = (1...3).map {
            Completion(habitID: otherID, date: TestCalendar.day($0))
        }
        #expect(evaluator.isDue(habit: habit, on: TestCalendar.day(5), completions: completions))
    }

    // MARK: Backdate — everyNDays with negative deltas

    @Test("everyNDays: 6 days before creation (cycle-aligned) is due when backdated")
    func everyNDaysBackdateAligned() {
        let habit = makeHabit(.everyNDays(3), createdOffset: 0)
        let completions = [Completion(habitID: habit.id, date: TestCalendar.day(-6))]
        #expect(evaluator.isDue(habit: habit, on: TestCalendar.day(-6), completions: completions))
    }

    @Test("everyNDays: 5 days before creation (not aligned) is not due")
    func everyNDaysBackdateNotAligned() {
        let habit = makeHabit(.everyNDays(3), createdOffset: 0)
        let completions = [Completion(habitID: habit.id, date: TestCalendar.day(-6))]
        #expect(!evaluator.isDue(habit: habit, on: TestCalendar.day(-5), completions: completions))
    }

    @Test("Negative habit: day before createdAt is never due even with completion")
    func negativeNotDueBeforeCreation() {
        let habit = Habit(
            name: "No smoking",
            frequency: .daily,
            type: .negative,
            createdAt: TestCalendar.day(0)
        )
        let completions = [Completion(habitID: habit.id, date: TestCalendar.day(-2))]
        #expect(!evaluator.isDue(habit: habit, on: TestCalendar.day(-2), completions: completions))
    }

    // MARK: Helpers

    private func makeHabit(
        _ frequency: Frequency,
        createdOffset: Int,
        archivedOffset: Int? = nil
    ) -> Habit {
        Habit(
            name: "Test",
            frequency: frequency,
            type: .binary,
            createdAt: TestCalendar.day(createdOffset),
            archivedAt: archivedOffset.map(TestCalendar.day)
        )
    }
}
