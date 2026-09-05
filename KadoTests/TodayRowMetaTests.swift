import Testing
import Foundation
@testable import Kado
import KadoCore

/// The Today caption has to say the *most useful* fact in one short
/// line, so what these tests pin is the **priority** between competing
/// facts, not the wording — the wording is the catalog's job.
@Suite("TodayRowMeta")
struct TodayRowMetaTests {
    private let calendar = TestCalendar.utc
    /// 2026-04-13, a Monday.
    private let today = TestCalendar.day(0)

    private func habit(_ type: HabitType, frequency: Frequency = .daily) -> Habit {
        Habit(name: "H", frequency: frequency, type: type, createdAt: TestCalendar.day(-30))
    }

    private func lead(
        _ habit: Habit,
        state: HabitRowState,
        streak: Int = 0,
        nextDue: Date? = nil
    ) -> String? {
        TodayRowMeta.lead(
            habit: habit,
            state: state,
            streak: streak,
            nextDue: nextDue,
            calendar: calendar,
            asOf: today
        )
    }

    private static let none = HabitRowState(status: .none, progress: 0, valueToday: nil)
    private static let done = HabitRowState(status: .complete, progress: 1, valueToday: 1)

    // MARK: - Priority

    @Test("A next-due date outranks every other fact")
    func nextDueWins() throws {
        // A habit in the "not scheduled today" section might also have a
        // streak and today's progress. When it comes round again is the
        // only one of those the user can act on.
        let counter = habit(.counter(target: 8))
        let state = HabitRowState(status: .partial, progress: 0.5, valueToday: 4)
        let withDate = try #require(
            lead(counter, state: state, streak: 9, nextDue: TestCalendar.day(1))
        )
        let withoutDate = try #require(lead(counter, state: state, streak: 9))
        #expect(withDate != withoutDate)
        #expect(!withDate.contains("4/8"))
    }

    @Test("A slip outranks the streak it replaced")
    func slipWins() throws {
        let negative = habit(.negative)
        let slipped = try #require(lead(negative, state: Self.done, streak: 0))
        let clean = lead(negative, state: Self.none, streak: 6)
        // Slipped today reports the reset; a clean day reports the
        // streak, so the two must differ.
        #expect(slipped != clean)
        #expect(clean != nil)
    }

    // MARK: - Per-type content

    @Test("Counter and timer lead with today's progress, not a streak")
    func progressLeads() throws {
        let counter = habit(.counter(target: 8))
        let counterLead = try #require(
            lead(counter, state: HabitRowState(status: .partial, progress: 0.5, valueToday: 4), streak: 9)
        )
        #expect(counterLead.contains("4/8"))
        #expect(!counterLead.contains("9"))

        let timer = habit(.timer(targetSeconds: 1800))
        let timerLead = try #require(
            lead(timer, state: HabitRowState(status: .partial, progress: 0.66, valueToday: 1200), streak: 9)
        )
        #expect(timerLead.contains("20/30"))
    }

    @Test("Timer minutes round down, so an unmet target never reads as met")
    func timerRoundsDown() throws {
        let timer = habit(.timer(targetSeconds: 1800))
        // 29:59 elapsed. Rounding up would print "30/30 min" beside a
        // control that still says the habit isn't done.
        let text = try #require(
            lead(timer, state: HabitRowState(status: .partial, progress: 0.99, valueToday: 1799), streak: 0)
        )
        #expect(text.contains("29/30"))
    }

    @Test("A binary habit leads with its streak, and stays quiet without one")
    func binaryStreak() throws {
        let binary = habit(.binary)
        #expect(lead(binary, state: Self.none, streak: 0) == nil)
        let text = try #require(lead(binary, state: Self.none, streak: 2))
        #expect(text.contains("2"))
    }

    @Test("A counter at zero still shows 0/target rather than nothing")
    func counterAtZero() throws {
        let counter = habit(.counter(target: 8))
        let text = try #require(lead(counter, state: Self.none, streak: 0))
        #expect(text.contains("0/8"))
    }

    // MARK: - Next-due wording

    @Test("Inside a week the date is a weekday name; beyond it, a date")
    func nextDueWording() throws {
        let binary = habit(.binary)
        // Today is Monday, so day(7) is the following Monday — still
        // unambiguous as a weekday. Day 8 is not.
        let withinWeek = try #require(lead(binary, state: Self.none, nextDue: TestCalendar.day(7)))
        let beyondWeek = try #require(lead(binary, state: Self.none, nextDue: TestCalendar.day(8)))
        #expect(withinWeek != beyondWeek)

        let monday = try #require(Weekday(rawValue: calendar.component(.weekday, from: TestCalendar.day(7))))
        #expect(withinWeek.localizedCaseInsensitiveContains(monday.localizedFull))
        // A date beyond the week must not claim a bare weekday name,
        // which would be ambiguous.
        let tuesday = try #require(Weekday(rawValue: calendar.component(.weekday, from: TestCalendar.day(8))))
        #expect(!beyondWeek.localizedCaseInsensitiveContains(tuesday.localizedFull))
    }

    // MARK: - Composition

    @Test("The full line is lead, separator, score — and score alone when there is no lead")
    func lineComposition() {
        let binary = habit(.binary)
        func line(streak: Int) -> String {
            TodayRowMeta.line(
                habit: binary,
                state: Self.none,
                streak: streak,
                scorePercent: 43,
                nextDue: nil,
                calendar: calendar,
                asOf: today
            )
        }

        let score = TodayRowMeta.percent(43)
        #expect(line(streak: 0) == score)

        let withStreak = line(streak: 2)
        #expect(withStreak.hasSuffix(score))
        #expect(withStreak.contains(" · "))
        // Composed from exactly the two halves, nothing else.
        let expectedLead = TodayRowMeta.lead(
            habit: binary, state: Self.none, streak: 2,
            nextDue: nil, calendar: calendar, asOf: today
        )
        #expect(withStreak == "\(expectedLead ?? "") · \(score)")
    }

    @Test("The score always carries its percent sign")
    func percentFormatting() {
        #expect(TodayRowMeta.percent(0).contains("0"))
        #expect(TodayRowMeta.percent(43).contains("43"))
        #expect(TodayRowMeta.percent(100).contains("%"))
    }
}
