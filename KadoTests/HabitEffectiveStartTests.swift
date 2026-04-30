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
}
