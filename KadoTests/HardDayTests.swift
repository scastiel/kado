import Testing
import Foundation
@testable import Kado
import KadoCore

@Suite("HardDay")
struct HardDayTests {
    @Test("A yes/no habit's value strictly between nothing and a full day is a hard day")
    func binaryValuesBetweenZeroAndOne() {
        #expect(HardDay.isHardDay(value: HardDay.value, for: .binary))
        #expect(HardDay.isHardDay(value: 0.25, for: .binary))
        #expect(!HardDay.isHardDay(value: 1, for: .binary))
        #expect(!HardDay.isHardDay(value: 2, for: .binary))
        #expect(!HardDay.isHardDay(value: 0, for: .binary), "a note-only record is not a hard day")
    }

    @Test("Only yes/no habits have hard days")
    func otherTypesNever() {
        #expect(!HardDay.isHardDay(value: HardDay.value, for: .negative))
        #expect(!HardDay.isHardDay(value: HardDay.value, for: .counter(target: 8)))
        #expect(!HardDay.isHardDay(value: HardDay.value, for: .timer(targetSeconds: 600)))
    }

    @Test("A hard day's daily value is HardDay.value, a full day's is 1")
    func dailyValue() {
        let habit = Habit(name: "Meditate", frequency: .daily, type: .binary, createdAt: TestCalendar.day(-5))
        let hard = Completion(habitID: habit.id, date: TestCalendar.day(0), value: HardDay.value)
        let full = Completion(habitID: habit.id, date: TestCalendar.day(0))
        #expect(DailyValue.compute(for: habit, completionsOnDay: [hard]) == HardDay.value)
        #expect(DailyValue.compute(for: habit, completionsOnDay: [full]) == 1.0)
        #expect(DailyValue.compute(for: habit, completionsOnDay: [hard, full]) == 1.0)
        #expect(DailyValue.compute(for: habit, completionsOnDay: []) == 0.0)
    }

    @Test("The Overview draws a hard day as a scored cell at its value, lighter than a full day")
    func overviewCell() throws {
        let calendar = TestCalendar.utc
        let habit = Habit(name: "Meditate", frequency: .daily, type: .binary, createdAt: TestCalendar.day(-5))
        let days = [TestCalendar.day(-1), TestCalendar.day(0)].map { calendar.startOfDay(for: $0) }
        let rows = OverviewMatrix.compute(
            habits: [habit],
            completions: [
                Completion(habitID: habit.id, date: TestCalendar.day(-1), value: HardDay.value),
                Completion(habitID: habit.id, date: TestCalendar.day(0)),
            ],
            days: days,
            today: TestCalendar.day(0),
            calendar: calendar,
            frequencyEvaluator: DefaultFrequencyEvaluator(calendar: calendar)
        )
        let cells = try #require(rows.first?.days)
        #expect(cells == [.scored(HardDay.value), .scored(1.0)])
        #expect(try #require(cells[0].colorOpacity) < (try #require(cells[1].colorOpacity)))
    }
}
