import Testing
import Foundation
@testable import Kado
import KadoCore

@Suite("StreakCalculator")
@MainActor
struct StreakCalculatorTests {
    private let calendar = TestCalendar.utc
    private var asOf: Date { TestCalendar.day(0) }

    private func habit(
        frequency: Frequency = .daily,
        type: HabitType = .binary,
        createdAtOffset: Int = -60,
        archivedAtOffset: Int? = nil
    ) -> Habit {
        Habit(
            id: UUID(),
            name: "Test",
            frequency: frequency,
            type: type,
            createdAt: TestCalendar.day(createdAtOffset),
            archivedAt: archivedAtOffset.map { TestCalendar.day($0) }
        )
    }

    private func completion(for habit: Habit, dayOffset: Int) -> Completion {
        Completion(
            id: UUID(),
            habitID: habit.id,
            date: TestCalendar.day(dayOffset)
        )
    }

    private func calculator() -> DefaultStreakCalculator {
        DefaultStreakCalculator(calendar: calendar)
    }

    // MARK: - Empty / trivial

    @Test("No completions yields current 0 and best 0")
    func emptyHistory() {
        let h = habit()
        let calc = calculator()
        #expect(calc.current(for: h, completions: [], asOf: asOf) == 0)
        #expect(calc.best(for: h, completions: [], asOf: asOf) == 0)
    }

    @Test("Habit created today with no completion yields current 0 (grace not yet counted)")
    func createdTodayNoCompletion() {
        let h = habit(createdAtOffset: 0)
        let calc = calculator()
        #expect(calc.current(for: h, completions: [], asOf: asOf) == 0)
        #expect(calc.best(for: h, completions: [], asOf: asOf) == 0)
    }

    @Test("Habit created today and completed today yields current 1 and best 1")
    func createdAndCompletedToday() {
        let h = habit(createdAtOffset: 0)
        let completions = [completion(for: h, dayOffset: 0)]
        let calc = calculator()
        #expect(calc.current(for: h, completions: completions, asOf: asOf) == 1)
        #expect(calc.best(for: h, completions: completions, asOf: asOf) == 1)
    }

    // MARK: - Daily

    @Test("10 consecutive daily completions yields current 10 and best 10")
    func tenConsecutiveDays() {
        let h = habit()
        let completions = (0...9).map { completion(for: h, dayOffset: -$0) }
        let calc = calculator()
        #expect(calc.current(for: h, completions: completions, asOf: asOf) == 10)
        #expect(calc.best(for: h, completions: completions, asOf: asOf) == 10)
    }

    @Test("Today uncomplete is a grace day — yesterday's streak carries")
    func todayGraceDay() {
        let h = habit()
        // 5 days completed, days -1 through -5, today (0) not yet
        let completions = (1...5).map { completion(for: h, dayOffset: -$0) }
        let calc = calculator()
        #expect(calc.current(for: h, completions: completions, asOf: asOf) == 5)
    }

    @Test("Yesterday uncomplete breaks the current streak")
    func yesterdayBreaks() {
        let h = habit()
        // Completed today, nothing day-1, then 3 completions days -2..-4
        let completions = [
            completion(for: h, dayOffset: 0),
            completion(for: h, dayOffset: -2),
            completion(for: h, dayOffset: -3),
            completion(for: h, dayOffset: -4),
        ]
        let calc = calculator()
        #expect(calc.current(for: h, completions: completions, asOf: asOf) == 1)
        #expect(calc.best(for: h, completions: completions, asOf: asOf) == 3)
    }

    // MARK: - .specificDays

    @Test(".specificDays skips non-matching weekdays without breaking")
    func specificDaysSkipsNonDue() {
        // Reference day 2026-04-13 is Monday. Mon/Wed/Fri schedule.
        // Due days in the past 2 weeks (from today=Mon Apr 13):
        //   Apr 13 (Mon, today), Apr 10 (Fri), Apr 8 (Wed),
        //   Apr 6 (Mon), Apr 3 (Fri), Apr 1 (Wed)
        let h = habit(frequency: .specificDays([.monday, .wednesday, .friday]))
        let dueOffsets = [0, -3, -5, -7, -10, -12]
        let completions = dueOffsets.map { completion(for: h, dayOffset: $0) }
        let calc = calculator()
        #expect(calc.current(for: h, completions: completions, asOf: asOf) == 6)
    }

    @Test(".specificDays breaks on a missed due day")
    func specificDaysBreaks() {
        let h = habit(frequency: .specificDays([.monday, .wednesday, .friday]))
        // Completed today (Mon 13), Fri (10), miss Wed (8), Mon (6), Fri (3)
        let completions = [0, -3, -7, -10].map { completion(for: h, dayOffset: $0) }
        let calc = calculator()
        #expect(calc.current(for: h, completions: completions, asOf: asOf) == 2)
    }

    // MARK: - .everyNDays

    @Test(".everyNDays streak breaks on a missed due day")
    func everyNDaysBreaks() {
        // createdAt day -15. N=3. Due days: -15, -12, -9, -6, -3, 0 (today).
        let h = habit(frequency: .everyNDays(3), createdAtOffset: -15)
        // Complete today, -3, miss -6, complete -9, -12, -15
        let completions = [0, -3, -9, -12, -15].map { completion(for: h, dayOffset: $0) }
        let calc = calculator()
        #expect(calc.current(for: h, completions: completions, asOf: asOf) == 2)
        #expect(calc.best(for: h, completions: completions, asOf: asOf) == 3)
    }

    // MARK: - .daysPerWeek

    @Test(".daysPerWeek(3) counts qualifying weeks, current week is grace")
    func daysPerWeekQualifiesByCount() {
        // Reference 2026-04-13 is Monday. UTC calendar firstWeekday=1 (Sunday).
        // Current week = Sun Apr 12 ... Sat Apr 18. Contains Sun -1, Mon 0.
        // Previous week = Sun Apr 5 ... Sat Apr 11.
        // Week before = Sun Mar 29 ... Sat Apr 4.
        // Target: 3 per week. Qualify prev two weeks, current week has just today.
        let h = habit(frequency: .daysPerWeek(3), createdAtOffset: -30)
        let completions = [
            // Current week: only today — grace, still counts as non-breaking.
            completion(for: h, dayOffset: 0),
            // Previous week (Apr 5-11): Tue, Thu, Sat — qualifies (3).
            completion(for: h, dayOffset: -6), // Tue Apr 7
            completion(for: h, dayOffset: -4), // Thu Apr 9
            completion(for: h, dayOffset: -2), // Sat Apr 11
            // Week before (Mar 29-Apr 4): Mon, Wed, Fri — qualifies (3).
            completion(for: h, dayOffset: -13), // Tue Mar 31
            completion(for: h, dayOffset: -11), // Thu Apr 2
            completion(for: h, dayOffset: -9),  // Sat Apr 4
        ]
        let calc = calculator()
        // Current week (grace) + 2 qualifying past weeks = 3.
        #expect(calc.current(for: h, completions: completions, asOf: asOf) == 3)
    }

    @Test(".daysPerWeek(3) resets on a non-qualifying past week")
    func daysPerWeekResets() {
        let h = habit(frequency: .daysPerWeek(3), createdAtOffset: -30)
        let completions = [
            // Current week grace: 1 completion today.
            completion(for: h, dayOffset: 0),
            // Previous week: only 2 completions — below target, breaks streak.
            completion(for: h, dayOffset: -4),
            completion(for: h, dayOffset: -2),
            // Older week: 3 completions — would have been a qualifying week,
            // but the streak reset by the time we reach it.
            completion(for: h, dayOffset: -13),
            completion(for: h, dayOffset: -11),
            completion(for: h, dayOffset: -9),
        ]
        let calc = calculator()
        #expect(calc.current(for: h, completions: completions, asOf: asOf) == 1)
        // Best = 1: only one qualifying historical week. The end-week
        // grace doesn't revive a broken run, just prevents reset.
        #expect(calc.best(for: h, completions: completions, asOf: asOf) == 1)
    }

    // MARK: - Negative habits

    @Test("Negative habit streak counts days without completion")
    func negativeHabitStreak() {
        let h = habit(type: .negative)
        // Days -5, -3 have completions (= failures). Days 0, -1, -2, -4, -6, -7 clean.
        // Streak from today back: 0 clean, -1 clean, -2 clean, then -3 failure → break.
        // Current streak = 3.
        let completions = [
            completion(for: h, dayOffset: -3),
            completion(for: h, dayOffset: -5),
        ]
        let calc = calculator()
        #expect(calc.current(for: h, completions: completions, asOf: asOf) == 3)
    }

    // MARK: - Invariants

    @Test("Best is always greater than or equal to current")
    func bestGreaterThanOrEqualCurrent() {
        let h = habit()
        // Past best: 7 days. Now: 2 day current streak after 4-day gap.
        let completions = (0..<2).map { completion(for: h, dayOffset: -$0) }
            + (7..<14).map { completion(for: h, dayOffset: -$0) }
        let calc = calculator()
        let cur = calc.current(for: h, completions: completions, asOf: asOf)
        let best = calc.best(for: h, completions: completions, asOf: asOf)
        #expect(best >= cur)
        #expect(best == 7)
        #expect(cur == 2)
    }

    // MARK: - Archived

    @Test("Archived habit streak is computed as of archivedAt, not asOf")
    func archivedComputedAsOfArchiveDate() {
        // Habit archived 5 days ago. At that point streak was 10. Since then: nothing.
        let h = habit(archivedAtOffset: -5)
        let completions = (5..<15).map { completion(for: h, dayOffset: -$0) }
        let calc = calculator()
        // Grace day applies to archivedAt (day -5), not today.
        // Days -5, -6, ..., -14 all completed → streak 10.
        #expect(calc.current(for: h, completions: completions, asOf: asOf) == 10)
    }
}
