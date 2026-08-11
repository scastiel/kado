import Foundation
import KadoCore

/// Deterministic calendar + reference date for service tests. Pinned
/// to UTC and Gregorian so day arithmetic is reproducible regardless
/// of the host machine's locale or timezone.
enum TestCalendar {
    static let utc: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        cal.firstWeekday = 1
        return cal
    }()

    /// 2026-04-13 12:00 UTC — a Monday. All `day(_:)` offsets pivot
    /// around this anchor.
    static let referenceDate: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 4
        components.day = 13
        components.hour = 12
        components.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: components)!
    }()

    static func day(_ offset: Int) -> Date {
        utc.date(byAdding: .day, value: offset, to: referenceDate)!
    }

    /// Europe/Paris — the DST-crossing zone used whenever day
    /// arithmetic has to survive a spring-forward or fall-back.
    /// 2026 transitions: **2026-03-29** (02:00 → 03:00, the day is 23
    /// hours long and 02:00-02:59 never happens) and **2026-10-25**
    /// (03:00 → 02:00, the day is 25 hours long and 02:00-02:59
    /// happens twice).
    static let paris: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Paris")!
        cal.firstWeekday = 2
        return cal
    }()

    /// America/Havana — a zone whose DST transition happens **at
    /// midnight** (2026-03-08: 00:00 → 01:00), so the day's first
    /// instant is 01:00 and `startOfDay` arithmetic that assumes
    /// midnight exists silently drifts by an hour. Paris can't catch
    /// this class: its transitions are at 02:00/03:00.
    static let havana: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Havana")!
        cal.firstWeekday = 2
        return cal
    }()

    /// Builds an exact wall-clock instant in `calendar`'s time zone.
    /// Traps on a time that doesn't exist (e.g. 02:30 on a
    /// spring-forward day) — that's a test-authoring mistake, and a
    /// loud failure beats a silently adjusted expectation.
    static func instant(
        _ calendar: Calendar,
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int = 0,
        _ minute: Int = 0,
        _ second: Int = 0
    ) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second
        components.timeZone = calendar.timeZone
        return calendar.date(from: components)!
    }
}
