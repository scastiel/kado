import Foundation
import Testing
@testable import Kado
import KadoCore

/// Presentation-layer contracts for "Day starts at". Both suites below
/// exist because a screenshot caught the bug, not a test — these are
/// the regressions that keep them caught.
@Suite("Day-start presentation")
@MainActor
struct DayStartPresentationTests {

    // MARK: - Hour labels

    /// The bug: formatting the *rollover instant* rendered it in the
    /// device's time zone, so a UTC boundary at 04:00 displayed as
    /// "00:00" on a UTC-4 device. Labels are built from the hour in the
    /// boundary's own calendar, so the zone can't shift them.
    @Test("An hour label is the same in every time zone")
    func hourLabelIsTimeZoneStable() {
        for hour in DayStartDefaults.allowedHours where hour != 0 {
            var utc = Calendar(identifier: .gregorian)
            utc.timeZone = TimeZone(identifier: "UTC")!
            utc.locale = Locale(identifier: "en_US_POSIX")

            var tokyo = Calendar(identifier: .gregorian)
            tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")!
            tokyo.locale = Locale(identifier: "en_US_POSIX")

            #expect(
                DayStartHourLabel.text(for: hour, calendar: utc)
                    == DayStartHourLabel.text(for: hour, calendar: tokyo)
            )
        }
    }

    @Test("Midnight reads as a word, not a time")
    func midnightIsNamed() {
        #expect(DayStartHourLabel.text(for: 0) == String(localized: "Midnight"))
    }

    @Test("Every offerable hour has a distinct, non-empty label")
    func labelsAreDistinct() {
        let labels = DayStartDefaults.allowedHours.map { DayStartHourLabel.text(for: $0) }
        #expect(labels.allSatisfy { !$0.isEmpty })
        #expect(Set(labels).count == labels.count)
    }

    /// The picker used to stop at 6 AM, so no label ever had to say
    /// "PM" or reach a 24-hour clock's second half. Afternoon hours
    /// (#93) render through the same locale-negotiated template; this
    /// pins what that produces in a 12-hour and a 24-hour locale. The
    /// expected strings are pasted from a run, not hand-derived — which
    /// is how the `U+202F` narrow no-break space before "PM" got
    /// noticed: it prints as an ordinary space and fails an ordinary
    /// space.
    @Test("An afternoon hour reads as a time of day in both clock styles")
    func afternoonLabelFollowsTheLocaleClock() {
        var twelveHour = Calendar(identifier: .gregorian)
        twelveHour.timeZone = TimeZone(identifier: "UTC")!
        twelveHour.locale = Locale(identifier: "en_US_POSIX")

        var twentyFourHour = Calendar(identifier: .gregorian)
        twentyFourHour.timeZone = TimeZone(identifier: "UTC")!
        twentyFourHour.locale = Locale(identifier: "fr_FR")

        #expect(DayStartHourLabel.text(for: 14, calendar: twelveHour) == "2:00\u{202F}PM")
        #expect(DayStartHourLabel.text(for: 14, calendar: twentyFourHour) == "14:00")
    }

    // MARK: - The Today caption

    @Test("The caption is hidden under the midnight default")
    func captionHiddenWithoutAnOffset() {
        let boundary = DayBoundary(calendar: TestCalendar.utc, startHour: 0)
        for hour in 0..<24 {
            let now = TestCalendar.instant(TestCalendar.utc, 2026, 8, 11, hour, 30)
            #expect(!TodayDayCaption.isBeforeRollover(boundary, now: now))
        }
    }

    @Test("The caption shows only between midnight and the rollover")
    func captionShowsOnlyInsideTheWindow() {
        let boundary = DayBoundary(calendar: TestCalendar.utc, startHour: 4)
        for hour in 0..<24 {
            let now = TestCalendar.instant(TestCalendar.utc, 2026, 8, 11, hour, 30)
            #expect(TodayDayCaption.isBeforeRollover(boundary, now: now) == (hour < 4))
        }
    }

    /// With an afternoon rollover the window is most of the wall-clock
    /// day rather than a few night hours. The rule doesn't change: the
    /// caption shows exactly while the logical day trails the calendar
    /// one, whatever the hour.
    @Test("The caption window follows an afternoon rollover too")
    func captionWindowFollowsAnAfternoonRollover() {
        let boundary = DayBoundary(calendar: TestCalendar.utc, startHour: 14)
        for hour in 0..<24 {
            let now = TestCalendar.instant(TestCalendar.utc, 2026, 8, 11, hour, 30)
            #expect(TodayDayCaption.isBeforeRollover(boundary, now: now) == (hour < 14))
        }
    }

    @Test("The caption disappears exactly at the rollover instant")
    func captionEndsAtTheBoundary() {
        let boundary = DayBoundary(calendar: TestCalendar.utc, startHour: 4)
        let justBefore = TestCalendar.instant(TestCalendar.utc, 2026, 8, 11, 3, 59, 59)
        let atRollover = TestCalendar.instant(TestCalendar.utc, 2026, 8, 11, 4, 0, 0)

        #expect(TodayDayCaption.isBeforeRollover(boundary, now: justBefore))
        #expect(!TodayDayCaption.isBeforeRollover(boundary, now: atRollover))
    }
}
