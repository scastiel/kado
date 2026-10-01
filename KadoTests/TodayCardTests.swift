import Testing
import Foundation
@testable import Kado

/// Today has one card slot and two cards that want it. The rule under
/// test: never both, the announcement first, and the tip nudge not on
/// the heels of the announcement — not the same day it was put away.
@Suite("TodayCard")
struct TodayCardTests {
    private let calendar = TestCalendar.utc

    @Test("The announcement takes the slot while it is due, even when the tip nudge is too")
    func announcementWinsTheSlot() {
        let card = TodayCard.resolve(
            announcementRetiredAt: nil,
            tipNudgeDue: true,
            now: TestCalendar.referenceDate,
            calendar: calendar
        )
        #expect(card == .appearanceAnnouncement)
    }

    @Test("The announcement shows on its own when the tip nudge isn't due")
    func announcementAlone() {
        let card = TodayCard.resolve(
            announcementRetiredAt: nil,
            tipNudgeDue: false,
            now: TestCalendar.referenceDate,
            calendar: calendar
        )
        #expect(card == .appearanceAnnouncement)
    }

    @Test("No tip nudge on the day the announcement was put away")
    func noTipSameDay() {
        // Dismissed at 08:00, Today looked at again at 23:00.
        let card = TodayCard.resolve(
            announcementRetiredAt: TestCalendar.instant(calendar, 2026, 4, 13, 8),
            tipNudgeDue: true,
            now: TestCalendar.instant(calendar, 2026, 4, 13, 23),
            calendar: calendar
        )
        #expect(card == nil)
    }

    @Test("The tip nudge takes the slot from the next day on")
    func tipNextDay() {
        // Calendar days, not 24 hours: 23:00 → 01:00 is a new day.
        let card = TodayCard.resolve(
            announcementRetiredAt: TestCalendar.instant(calendar, 2026, 4, 13, 23),
            tipNudgeDue: true,
            now: TestCalendar.instant(calendar, 2026, 4, 14, 1),
            calendar: calendar
        )
        #expect(card == .tipNudge)
    }

    @Test("Nothing once the announcement is put away and the tip nudge isn't due")
    func empty() {
        let card = TodayCard.resolve(
            announcementRetiredAt: TestCalendar.day(-30),
            tipNudgeDue: false,
            now: TestCalendar.referenceDate,
            calendar: calendar
        )
        #expect(card == nil)
    }

    @Test("The next-day rule follows the calendar's own day, across a midnight DST jump")
    func havanaMidnight() {
        // Havana, 2026-03-08: 00:00 never happens, the day opens at 01:00.
        let havana = TestCalendar.havana
        let card = TodayCard.resolve(
            announcementRetiredAt: TestCalendar.instant(havana, 2026, 3, 7, 23, 30),
            tipNudgeDue: true,
            now: TestCalendar.instant(havana, 2026, 3, 8, 1, 15),
            calendar: havana
        )
        #expect(card == .tipNudge)
    }
}
