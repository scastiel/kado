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
}
