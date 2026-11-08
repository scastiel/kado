import Testing
import Foundation
@testable import Kado
import KadoCore

@Suite("HardDayTally")
struct HardDayTallyTests {
    private let calendar = TestCalendar.utc

    /// April 2026, the month `TestCalendar.day(0)` (the 13th) sits in.
    private var april: DateInterval {
        calendar.dateInterval(of: .month, for: TestCalendar.day(0))!
    }

    private func habit(_ type: HabitType = .binary) -> Habit {
        Habit(name: "Meditate", frequency: .daily, type: type, createdAt: TestCalendar.day(-60))
    }

    private func completion(_ habit: Habit, _ offset: Int, value: Double = 1, note: String? = nil) -> Completion {
        Completion(habitID: habit.id, date: TestCalendar.day(offset), value: value, note: note)
    }

    @Test("Splits the month's done days into full days and hard days")
    func splitsFullAndHard() {
        let h = habit()
        let completions = [
            completion(h, 0),
            completion(h, -1, value: HardDay.value),
            completion(h, -2),
            completion(h, -3, value: HardDay.value),
            completion(h, -4),
        ]
        let tally = HardDayTally.tally(habit: h, completions: completions, in: april, calendar: calendar)
        #expect(tally == HardDayTally(fullDays: 3, hardDays: 2))
    }

    @Test("Ignores other months, other habits and note-only records")
    func ignoresOutsiders() {
        let h = habit()
        let other = habit()
        let completions = [
            completion(h, 0, value: HardDay.value),
            completion(h, -13, value: HardDay.value), // March 31st
            completion(h, 18, value: HardDay.value),  // May 1st
            completion(other, -1, value: HardDay.value),
            completion(h, -2, value: 0, note: "Sick"),
        ]
        let tally = HardDayTally.tally(habit: h, completions: completions, in: april, calendar: calendar)
        #expect(tally == HardDayTally(fullDays: 0, hardDays: 1))
    }

    @Test("A day with two records counts once, as full when either record is")
    func duplicateDayCountsOnce() {
        let h = habit()
        let completions = [
            completion(h, 0, value: HardDay.value),
            completion(h, 0),
            completion(h, -1, value: HardDay.value),
            completion(h, -1, value: HardDay.value),
        ]
        let tally = HardDayTally.tally(habit: h, completions: completions, in: april, calendar: calendar)
        #expect(tally == HardDayTally(fullDays: 1, hardDays: 1))
    }

    @Test("Counters, timers and negative habits have no hard days to tally")
    func otherTypesTallyNothing() {
        for type in [HabitType.counter(target: 8), .timer(targetSeconds: 600), .negative] {
            let h = habit(type)
            let tally = HardDayTally.tally(
                habit: h,
                completions: [completion(h, 0, value: HardDay.value)],
                in: april,
                calendar: calendar
            )
            #expect(tally == HardDayTally(fullDays: 0, hardDays: 0))
        }
    }
}
