import Testing
import Foundation
import KadoCore

@Suite("Habit.effectiveStart")
struct HabitEffectiveStartTests {
    private let calendar = TestCalendar.utc

    private func habit(
        type: HabitType = .binary,
        createdAtOffset: Int = 0
    ) -> Habit {
        Habit(
            name: "Test",
            frequency: .daily,
            type: type,
            createdAt: TestCalendar.day(createdAtOffset)
        )
    }

    private func completion(for habit: Habit, dayOffset: Int, value: Double = 1.0) -> Completion {
        Completion(habitID: habit.id, date: TestCalendar.day(dayOffset), value: value)
    }

    @Test("No completions returns createdAt")
    func noCompletions() {
        let h = habit(createdAtOffset: 0)
        let start = h.effectiveStart(completions: [], calendar: calendar)
        #expect(calendar.isDate(start, inSameDayAs: TestCalendar.day(0)))
    }

    @Test("First completion before createdAt returns completion date")
    func completionBeforeCreation() {
        let h = habit(createdAtOffset: 0)
        let comps = [completion(for: h, dayOffset: -3)]
        let start = h.effectiveStart(completions: comps, calendar: calendar)
        #expect(calendar.isDate(start, inSameDayAs: TestCalendar.day(-3)))
    }

    @Test("First completion after createdAt returns first completion date")
    func completionAfterCreation() {
        let h = habit(createdAtOffset: 0)
        let comps = [completion(for: h, dayOffset: 5)]
        let start = h.effectiveStart(completions: comps, calendar: calendar)
        #expect(calendar.isDate(start, inSameDayAs: TestCalendar.day(5)))
    }

    @Test("Multiple completions returns the earliest")
    func multipleCompletions() {
        let h = habit(createdAtOffset: 0)
        let comps = [
            completion(for: h, dayOffset: -1),
            completion(for: h, dayOffset: -5),
            completion(for: h, dayOffset: 2),
        ]
        let start = h.effectiveStart(completions: comps, calendar: calendar)
        #expect(calendar.isDate(start, inSameDayAs: TestCalendar.day(-5)))
    }

    @Test("Negative habit always returns createdAt regardless of completions")
    func negativeHabitKeepsCreatedAt() {
        let h = habit(type: .negative, createdAtOffset: 0)
        let comps = [completion(for: h, dayOffset: -5)]
        let start = h.effectiveStart(completions: comps, calendar: calendar)
        #expect(calendar.isDate(start, inSameDayAs: TestCalendar.day(0)))
    }

    @Test("Zero-value completions are ignored")
    func zeroValueIgnored() {
        let h = habit(createdAtOffset: 0)
        let comps = [
            completion(for: h, dayOffset: -5, value: 0),
            completion(for: h, dayOffset: 2, value: 1),
        ]
        let start = h.effectiveStart(completions: comps, calendar: calendar)
        #expect(calendar.isDate(start, inSameDayAs: TestCalendar.day(2)))
    }

    @Test("Only completions for this habit are considered")
    func filtersByHabitID() {
        let h = habit(createdAtOffset: 0)
        let other = Habit(name: "Other", frequency: .daily, type: .binary, createdAt: TestCalendar.day(-10))
        let comps = [
            Completion(habitID: other.id, date: TestCalendar.day(-8)),
            completion(for: h, dayOffset: 3),
        ]
        let start = h.effectiveStart(completions: comps, calendar: calendar)
        #expect(calendar.isDate(start, inSameDayAs: TestCalendar.day(3)))
    }

    // MARK: - isBeforeStart / loggingBackdatesStart (issue #104)

    @Test("Days before the effective start are before start; the start day itself is not")
    func isBeforeStartBoundary() {
        let h = habit(createdAtOffset: -2)
        #expect(h.isBeforeStart(TestCalendar.day(-3), completions: [], calendar: calendar))
        #expect(!h.isBeforeStart(TestCalendar.day(-2), completions: [], calendar: calendar))
        #expect(!h.isBeforeStart(TestCalendar.day(0), completions: [], calendar: calendar))
    }

    @Test("isBeforeStart compares calendar days, not instants")
    func isBeforeStartIgnoresTimeOfDay() {
        // Created at noon; that day's midnight is an earlier instant
        // but the creation day, not a day before it.
        let h = habit(createdAtOffset: -2)
        let midnight = calendar.startOfDay(for: TestCalendar.day(-2))
        #expect(!h.isBeforeStart(midnight, completions: [], calendar: calendar))
    }

    @Test("A backdated completion moves the before-start boundary with it")
    func isBeforeStartFollowsBackdate() {
        let h = habit(createdAtOffset: 0)
        let comps = [completion(for: h, dayOffset: -4)]
        #expect(!h.isBeforeStart(TestCalendar.day(-4), completions: comps, calendar: calendar))
        #expect(h.isBeforeStart(TestCalendar.day(-5), completions: comps, calendar: calendar))
    }

    @Test("Logging before the start backdates a positive habit")
    func loggingBackdatesPositiveHabit() {
        for type: HabitType in [.binary, .counter(target: 3), .timer(targetSeconds: 600)] {
            let h = habit(type: type, createdAtOffset: 0)
            #expect(
                h.loggingBackdatesStart(on: TestCalendar.day(-3), completions: [], calendar: calendar),
                "\(type)"
            )
            #expect(
                !h.loggingBackdatesStart(on: TestCalendar.day(0), completions: [], calendar: calendar),
                "\(type)"
            )
        }
    }

    @Test("Logging before the start never backdates a negative habit")
    func loggingNeverBackdatesNegativeHabit() {
        // A negative habit's start stays at `createdAt` whatever it logs.
        let h = habit(type: .negative, createdAtOffset: 0)
        #expect(h.isBeforeStart(TestCalendar.day(-3), completions: [], calendar: calendar))
        #expect(!h.loggingBackdatesStart(on: TestCalendar.day(-3), completions: [], calendar: calendar))
    }
}
