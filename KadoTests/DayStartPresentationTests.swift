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

    @Test("The caption disappears exactly at the rollover instant")
    func captionEndsAtTheBoundary() {
        let boundary = DayBoundary(calendar: TestCalendar.utc, startHour: 4)
        let justBefore = TestCalendar.instant(TestCalendar.utc, 2026, 8, 11, 3, 59, 59)
        let atRollover = TestCalendar.instant(TestCalendar.utc, 2026, 8, 11, 4, 0, 0)

        #expect(TodayDayCaption.isBeforeRollover(boundary, now: justBefore))
        #expect(!TodayDayCaption.isBeforeRollover(boundary, now: atRollover))
    }
}
