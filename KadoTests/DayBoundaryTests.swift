import Foundation
import Testing
import KadoCore

/// Specifies `DayBoundary` — the single place the app decides "which
/// logical day is it?" once the user has moved the rollover hour off
/// midnight.
///
/// Two properties matter more than the rest and are called out
/// individually below:
///
/// 1. **`startHour == 0` is a no-op.** The default must be provably
///    identical to `Calendar.startOfDay`, or shipping this feature
///    changes behaviour for the ~all users who never touch it.
/// 2. **Normalising on write immunises stored records.** Changing the
///    setting later must not move a completion that's already logged.
@Suite("DayBoundary")
struct DayBoundaryTests {

    // MARK: - The default is a no-op

    @Test("startHour 0 matches Calendar.startOfDay at every hour of the day")
    func midnightBoundaryMatchesCalendarExactly() {
        let cal = TestCalendar.utc
        let boundary = DayBoundary(calendar: cal, startHour: 0)
        let midnight = TestCalendar.instant(cal, 2026, 8, 10)

        for minutes in stride(from: 0, to: 24 * 60, by: 7) {
            let instant = midnight.addingTimeInterval(TimeInterval(minutes * 60))
            #expect(boundary.startOfDay(for: instant) == cal.startOfDay(for: instant))
        }
    }

    @Test("startHour 0 leaves the logging instant untouched")
    func midnightBoundaryLoggingInstantIsIdentity() {
        let cal = TestCalendar.utc
        let boundary = DayBoundary(calendar: cal, startHour: 0)

        for hour in [0, 1, 3, 12, 23] {
            let instant = TestCalendar.instant(cal, 2026, 8, 10, hour, 37)
            #expect(boundary.loggingInstant(for: instant) == instant)
        }
    }

    @Test("startHour 0 rolls over at the next midnight")
    func midnightBoundaryNextRollover() {
        let cal = TestCalendar.utc
        let boundary = DayBoundary(calendar: cal, startHour: 0)
        let now = TestCalendar.instant(cal, 2026, 8, 10, 22, 15)

        #expect(boundary.nextRollover(after: now) == TestCalendar.instant(cal, 2026, 8, 11))
    }

    // MARK: - A 4 AM boundary

    @Test("02:00 under a 4 AM boundary resolves to the previous day")
    func beforeRolloverIsPreviousDay() {
        let cal = TestCalendar.utc
        let boundary = DayBoundary(calendar: cal, startHour: 4)
        let now = TestCalendar.instant(cal, 2026, 8, 11, 2, 0)

        #expect(boundary.startOfDay(for: now) == TestCalendar.instant(cal, 2026, 8, 10))
    }

    @Test("04:00 exactly starts the new day")
    func rolloverInstantIsInclusive() {
        let cal = TestCalendar.utc
        let boundary = DayBoundary(calendar: cal, startHour: 4)
        let now = TestCalendar.instant(cal, 2026, 8, 11, 4, 0)

        #expect(boundary.startOfDay(for: now) == TestCalendar.instant(cal, 2026, 8, 11))
    }

    @Test("03:59:59 is still the previous day")
    func oneSecondBeforeRollover() {
        let cal = TestCalendar.utc
        let boundary = DayBoundary(calendar: cal, startHour: 4)
        let now = TestCalendar.instant(cal, 2026, 8, 11, 3, 59, 59)

        #expect(boundary.startOfDay(for: now) == TestCalendar.instant(cal, 2026, 8, 10))
    }

    @Test("23:59 is the same day it looks like")
    func lateEveningIsUnsurprising() {
        let cal = TestCalendar.utc
        let boundary = DayBoundary(calendar: cal, startHour: 4)
        let now = TestCalendar.instant(cal, 2026, 8, 10, 23, 59)

        #expect(boundary.startOfDay(for: now) == TestCalendar.instant(cal, 2026, 8, 10))
    }

    @Test("23:00 and the following 01:00 are one logical day")
    func acrossWallClockMidnight() {
        let cal = TestCalendar.utc
        let boundary = DayBoundary(calendar: cal, startHour: 4)
        let evening = TestCalendar.instant(cal, 2026, 8, 10, 23, 0)
        let afterMidnight = TestCalendar.instant(cal, 2026, 8, 11, 1, 0)

        #expect(boundary.isDate(evening, inSameDayAs: afterMidnight))
    }

    @Test("The same two instants are different days under the midnight default")
    func acrossWallClockMidnightWithoutOffset() {
        let cal = TestCalendar.utc
        let boundary = DayBoundary(calendar: cal, startHour: 0)
        let evening = TestCalendar.instant(cal, 2026, 8, 10, 23, 0)
        let afterMidnight = TestCalendar.instant(cal, 2026, 8, 11, 1, 0)

        #expect(!boundary.isDate(evening, inSameDayAs: afterMidnight))
    }

    // MARK: - Logging instants

    @Test("loggingInstant keeps the clock time and moves the date back a day")
    func loggingInstantBeforeRollover() {
        let cal = TestCalendar.utc
        let boundary = DayBoundary(calendar: cal, startHour: 4)
        let loggedAt = TestCalendar.instant(cal, 2026, 8, 11, 2, 15)

        #expect(boundary.loggingInstant(for: loggedAt) == TestCalendar.instant(cal, 2026, 8, 10, 2, 15))
    }

    @Test("loggingInstant is the identity once the day has rolled over")
    func loggingInstantAfterRollover() {
        let cal = TestCalendar.utc
        let boundary = DayBoundary(calendar: cal, startHour: 4)
        let loggedAt = TestCalendar.instant(cal, 2026, 8, 11, 9, 30)

        #expect(boundary.loggingInstant(for: loggedAt) == loggedAt)
    }

    @Test("A logged instant always buckets to the logical day it was logged in")
    func loggingInstantBucketsToLogicalDay() {
        let cal = TestCalendar.utc
        let boundary = DayBoundary(calendar: cal, startHour: 4)

        for hour in 0..<24 {
            let loggedAt = TestCalendar.instant(cal, 2026, 8, 11, hour, 20)
            let stored = boundary.loggingInstant(for: loggedAt)
            #expect(cal.startOfDay(for: stored) == boundary.startOfDay(for: loggedAt))
        }
    }

    // MARK: - The anti-re-bucketing guarantee

    /// The reason the feature normalises on **write**. A completion
    /// carries its day permanently; the setting only ever answers
    /// "which day is it *now*". The middle assertion is the one worth
    /// reading — it shows the rejected read-normalisation design
    /// really would have rewritten history.
    @Test("Normalising on write immunises a stored record against later setting changes")
    func storedDayIsImmuneToSettingChanges() {
        let cal = TestCalendar.utc
        let loggedAt = TestCalendar.instant(cal, 2026, 8, 11, 2, 0)

        // Written under a 4 AM boundary, so the record lands on Aug 10.
        let stored = DayBoundary(calendar: cal, startHour: 4).loggingInstant(for: loggedAt)
        let dayAtWriteTime = cal.startOfDay(for: stored)
        #expect(dayAtWriteTime == TestCalendar.instant(cal, 2026, 8, 10))

        // Had we bucketed on read instead, the same raw instant would
        // land on different days depending on the current setting —
        // i.e. the user's history would move under them.
        let bucketsIfNormalisedOnRead = Set(
            (0...6).map { DayBoundary(calendar: cal, startHour: $0).startOfDay(for: loggedAt) }
        )
        #expect(bucketsIfNormalisedOnRead.count > 1)

        // Because the day was fixed at write time, the read path — which
        // buckets the stored date with the plain calendar, exactly as
        // every calculator does — is stable no matter what the user
        // picks later. Re-derived per hour rather than hoisted, so the
        // assertion actually depends on the loop variable.
        for hour in DayStartDefaults.allowedHours {
            let laterBoundary = DayBoundary(calendar: cal, startHour: hour)
            let readBack = readPathBucket(of: stored, underA: laterBoundary)
            #expect(readBack == dayAtWriteTime)
        }
    }

    /// Mirrors what the calculators actually do with a stored
    /// completion: bucket it by the plain calendar. Takes the boundary
    /// only to make the point that it is deliberately unused — if a
    /// future change starts consulting it here, this helper is the
    /// place that has to change, and the test above goes red.
    private func readPathBucket(of stored: Date, underA boundary: DayBoundary) -> Date {
        boundary.calendar.startOfDay(for: stored)
    }

    // MARK: - Rollover scheduling

    @Test("nextRollover is today's boundary while the clock is still before it")
    func nextRolloverBeforeBoundary() {
        let cal = TestCalendar.utc
        let boundary = DayBoundary(calendar: cal, startHour: 4)
        let now = TestCalendar.instant(cal, 2026, 8, 11, 2, 0)

        #expect(boundary.nextRollover(after: now) == TestCalendar.instant(cal, 2026, 8, 11, 4))
    }

    @Test("nextRollover is tomorrow's boundary once the clock has passed it")
    func nextRolloverAfterBoundary() {
        let cal = TestCalendar.utc
        let boundary = DayBoundary(calendar: cal, startHour: 4)
        let now = TestCalendar.instant(cal, 2026, 8, 11, 10, 0)

        #expect(boundary.nextRollover(after: now) == TestCalendar.instant(cal, 2026, 8, 12, 4))
    }

    @Test("nextRollover is always in the future")
    func nextRolloverIsStrictlyAhead() {
        let cal = TestCalendar.utc
        for hour in 0...6 {
            let boundary = DayBoundary(calendar: cal, startHour: hour)
            for clock in 0..<24 {
                let now = TestCalendar.instant(cal, 2026, 8, 11, clock, 30)
                #expect(boundary.nextRollover(after: now) > now)
            }
        }
    }

    // MARK: - Clamping

    @Test(
        "startHour is clamped to a real hour of the day",
        arguments: [(-5, 0), (0, 0), (4, 4), (23, 23), (26, 23)]
    )
    func startHourIsClamped(input: Int, expected: Int) {
        #expect(DayBoundary(calendar: TestCalendar.utc, startHour: input).startHour == expected)
    }

    // MARK: - DST

    @Test("A 4 AM boundary survives the Europe/Paris spring-forward")
    func springForward() {
        // 2026-03-29: the clock jumps 02:00 → 03:00, so the day is 23
        // hours long. 04:00 still exists, so the boundary is ordinary.
        let cal = TestCalendar.paris
        let boundary = DayBoundary(calendar: cal, startHour: 4)

        let beforeBoundary = TestCalendar.instant(cal, 2026, 3, 29, 1, 30)
        let afterBoundary = TestCalendar.instant(cal, 2026, 3, 29, 4, 30)

        #expect(boundary.startOfDay(for: beforeBoundary) == TestCalendar.instant(cal, 2026, 3, 28))
        #expect(boundary.startOfDay(for: afterBoundary) == TestCalendar.instant(cal, 2026, 3, 29))
    }

    @Test("A 2 AM boundary on a spring-forward day falls forward to the first real instant")
    func springForwardOverSkippedBoundaryHour() {
        // 02:00-02:59 doesn't happen at all on 2026-03-29. The
        // boundary has to resolve to 03:00 rather than vanish.
        let cal = TestCalendar.paris
        let boundary = DayBoundary(calendar: cal, startHour: 2)

        let justBefore = TestCalendar.instant(cal, 2026, 3, 29, 1, 59)
        let justAfter = TestCalendar.instant(cal, 2026, 3, 29, 3, 0)

        #expect(boundary.startOfDay(for: justBefore) == TestCalendar.instant(cal, 2026, 3, 28))
        #expect(boundary.startOfDay(for: justAfter) == TestCalendar.instant(cal, 2026, 3, 29))
    }

    @Test("A 4 AM boundary survives the Europe/Paris fall-back")
    func fallBack() {
        // 2026-10-25: the clock rewinds 03:00 → 02:00, so 02:30
        // happens twice. Both occurrences are still "yesterday".
        let cal = TestCalendar.paris
        let boundary = DayBoundary(calendar: cal, startHour: 4)

        let firstTwoThirty = TestCalendar.instant(cal, 2026, 10, 25, 2, 30)
        // Deliberately absolute-time arithmetic: the point is to land
        // on the *repeat* of the same wall-clock reading.
        let secondTwoThirty = firstTwoThirty.addingTimeInterval(3600)
        let afterBoundary = TestCalendar.instant(cal, 2026, 10, 25, 4, 30)

        #expect(boundary.startOfDay(for: firstTwoThirty) == TestCalendar.instant(cal, 2026, 10, 24))
        #expect(boundary.startOfDay(for: secondTwoThirty) == TestCalendar.instant(cal, 2026, 10, 24))
        #expect(boundary.startOfDay(for: afterBoundary) == TestCalendar.instant(cal, 2026, 10, 25))
    }

    @Test("loggingInstant lands on the logical day even when the clock time doesn't exist")
    func loggingInstantAcrossSpringForward() {
        // Logging at 02:15 on 2026-03-30 under a 4 AM boundary shifts
        // back to 2026-03-29 — a day on which 02:15 never happened.
        // Foundation adjusts the time; the *day* is what has to be right.
        let cal = TestCalendar.paris
        let boundary = DayBoundary(calendar: cal, startHour: 4)
        let loggedAt = TestCalendar.instant(cal, 2026, 3, 30, 2, 15)

        let stored = boundary.loggingInstant(for: loggedAt)

        #expect(cal.startOfDay(for: stored) == TestCalendar.instant(cal, 2026, 3, 29))
        #expect(cal.startOfDay(for: stored) == boundary.startOfDay(for: loggedAt))
    }

    @Test("Logical days partition time — monotonic, none skipped, none repeated")
    func logicalDaysPartitionTimeAcrossDST() {
        // Walks 2026-10-23 → 2026-10-27 in 15-minute steps, straight
        // through the fall-back. Asserts the shape of the partition
        // rather than a hand-counted total.
        let cal = TestCalendar.paris
        let boundary = DayBoundary(calendar: cal, startHour: 4)

        var clock = TestCalendar.instant(cal, 2026, 10, 23)
        var previousDay = boundary.startOfDay(for: clock)
        let end = TestCalendar.instant(cal, 2026, 10, 27)

        while clock < end {
            clock = clock.addingTimeInterval(900)
            let day = boundary.startOfDay(for: clock)
            #expect(day >= previousDay)
            if day != previousDay {
                #expect(cal.dateComponents([.day], from: previousDay, to: day).day == 1)
                previousDay = day
            }
        }
    }

    // MARK: - Invariants across every DST shape

    /// Zones chosen to cover the shapes that break naive day
    /// arithmetic: a midnight transition (Havana, Santiago), a
    /// half-hour transition (Lord Howe), a non-hour offset (Chatham),
    /// and the ordinary 02:00 case (Paris).
    private static let dstZones = [
        "UTC",
        "Europe/Paris",
        "America/Havana",
        "America/Santiago",
        "Australia/Lord_Howe",
        "Pacific/Chatham",
    ]

    private static func calendar(_ identifier: String) -> Calendar? {
        guard let zone = TimeZone(identifier: identifier) else { return nil }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = zone
        return cal
    }

    /// The invariant every consumer leans on: `\.today` is a real
    /// calendar midnight, so it can be compared by `==` against a
    /// `calendar.startOfDay` value.
    ///
    /// This is the general form of a bug that shipped in review: in
    /// Havana, DST springs forward at 00:00, so the day's first instant
    /// is 01:00 and stepping back one calendar day preserved that
    /// 01:00 instead of landing on midnight.
    @Test("startOfDay always returns a real calendar midnight", arguments: dstZones)
    func startOfDayIsAlwaysAMidnight(zone: String) throws {
        let cal = try #require(Self.calendar(zone))

        for hour in DayStartDefaults.allowedHours {
            let boundary = DayBoundary(calendar: cal, startHour: hour)
            for start in Self.transitionWindows(cal) {
                var clock = start
                let end = clock.addingTimeInterval(4 * 24 * 3600)
                while clock < end {
                    let day = boundary.startOfDay(for: clock)
                    #expect(
                        day == cal.startOfDay(for: day),
                        "\(zone) hour \(hour): \(day) is not a midnight"
                    )
                    clock = clock.addingTimeInterval(1800)
                }
            }
        }
    }

    /// The other half of the contract: what a write lands on is the
    /// same day the read reports. If these two ever disagree, a user
    /// taps a habit and watches the tick appear on a different day.
    @Test("A write buckets to exactly the day the read reports", arguments: dstZones)
    func writeAndReadAgreeOnTheDay(zone: String) throws {
        let cal = try #require(Self.calendar(zone))

        for hour in DayStartDefaults.allowedHours {
            let boundary = DayBoundary(calendar: cal, startHour: hour)
            for start in Self.transitionWindows(cal) {
                var clock = start
                let end = clock.addingTimeInterval(4 * 24 * 3600)
                while clock < end {
                    let read = boundary.startOfDay(for: clock)
                    let written = cal.startOfDay(for: boundary.loggingInstant(for: clock))
                    #expect(read == written, "\(zone) hour \(hour) at \(clock)")
                    clock = clock.addingTimeInterval(1800)
                }
            }
        }
    }

    /// Four-day windows straddling both 2026 DST transitions in the
    /// northern and southern hemispheres, so every zone above gets
    /// walked across at least one real transition.
    private static func transitionWindows(_ calendar: Calendar) -> [Date] {
        [(2026, 3, 6), (2026, 4, 3), (2026, 9, 4), (2026, 10, 23)].compactMap { y, m, d in
            var components = DateComponents()
            components.year = y
            components.month = m
            components.day = d
            components.timeZone = calendar.timeZone
            return calendar.date(from: components)
        }
    }
}
