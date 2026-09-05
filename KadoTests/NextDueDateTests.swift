import Testing
import Foundation
@testable import Kado
import KadoCore

@Suite("NextDueDate")
struct NextDueDateTests {
    private let calendar = TestCalendar.utc
    private let evaluator = DefaultFrequencyEvaluator(calendar: TestCalendar.utc)
    /// 2026-04-13, a Monday.
    private let today = TestCalendar.day(0)

    private func habit(
        _ frequency: Frequency,
        createdDaysAgo: Int = 30,
        archived: Bool = false
    ) -> Habit {
        Habit(
            name: "H",
            frequency: frequency,
            type: .binary,
            createdAt: TestCalendar.day(-createdDaysAgo),
            archivedAt: archived ? TestCalendar.day(-1) : nil
        )
    }

    private func next(_ habit: Habit, completions: [Completion] = []) -> Date? {
        NextDueDate.next(
            for: habit,
            after: today,
            completions: completions,
            calendar: calendar,
            evaluator: evaluator
        )
    }

    @Test("A daily habit is next due tomorrow")
    func dailyIsTomorrow() throws {
        let result = try #require(next(habit(.daily)))
        #expect(calendar.isDate(result, inSameDayAs: TestCalendar.day(1)))
    }

    @Test("A specific-days habit skips to its next listed weekday")
    func specificDaysSkipsAhead() throws {
        // Today is Monday; the habit runs Wednesdays and Fridays.
        let result = try #require(next(habit(.specificDays([.wednesday, .friday]))))
        #expect(calendar.isDate(result, inSameDayAs: TestCalendar.day(2)))
        #expect(calendar.component(.weekday, from: result) == Weekday.wednesday.rawValue)
    }

    @Test("A weekly habit due only today wraps to the same weekday next week")
    func wrapsToNextWeek() throws {
        let result = try #require(next(habit(.specificDays([.monday]))))
        #expect(calendar.isDate(result, inSameDayAs: TestCalendar.day(7)))
    }

    @Test("Always strictly after the reference day, never today")
    func neverReturnsToday() throws {
        // The caption says "next", so returning today would be a lie
        // even for a habit the schedule asks for every single day.
        let result = try #require(next(habit(.daily)))
        #expect(!calendar.isDate(result, inSameDayAs: today))
        #expect(result > today)
    }

    @Test("An every-N-days cycle counts from the last completion")
    func everyNDaysFromLastCompletion() throws {
        let subject = habit(.everyNDays(3))
        // Done today, so the cycle re-anchors here and the next due day
        // is three days out rather than three days from creation.
        let completions = [
            Completion(habitID: subject.id, date: today, value: 1)
        ]
        let result = try #require(next(subject, completions: completions))
        #expect(calendar.isDate(result, inSameDayAs: TestCalendar.day(3)))
    }

    @Test("An archived habit has no next due date")
    func archivedIsNil() {
        #expect(next(habit(.daily, archived: true)) == nil)
    }

    @Test("Nothing inside the horizon means nil rather than a wrong date")
    func beyondHorizonIsNil() {
        let subject = habit(.everyNDays(400))
        let completions = [Completion(habitID: subject.id, date: today, value: 1)]
        let result = NextDueDate.next(
            for: subject,
            after: today,
            completions: completions,
            calendar: calendar,
            evaluator: evaluator
        )
        #expect(result == nil)
    }

    @Test("Steps by calendar days across a DST boundary")
    func survivesDST() throws {
        // Havana's 2026-03-08 transition happens *at midnight*, so the
        // day starts at 01:00. Stepping by 86 400 seconds instead of by
        // calendar days would drift an hour and land on the wrong day.
        let havana = TestCalendar.havana
        let evaluator = DefaultFrequencyEvaluator(calendar: havana)
        let start = TestCalendar.instant(havana, 2026, 3, 6, 12)
        let subject = Habit(
            name: "H",
            frequency: .daily,
            type: .binary,
            createdAt: TestCalendar.instant(havana, 2026, 2, 1, 12)
        )

        var cursor = start
        for offset in 1...4 {
            let result = try #require(
                NextDueDate.next(
                    for: subject,
                    after: cursor,
                    completions: [],
                    calendar: havana,
                    evaluator: evaluator
                )
            )
            let expected = havana.date(byAdding: .day, value: offset, to: havana.startOfDay(for: start))!
            #expect(havana.isDate(result, inSameDayAs: expected))
            cursor = result
        }
    }
}
