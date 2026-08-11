import Foundation
import SwiftUI

/// Renders a day-start hour the way the user picked it.
///
/// Shared between the Settings picker and Today's pre-rollover caption
/// so the two can't disagree — the caption saying "rolls over at 4 AM"
/// while Settings shows "05:00" would be worse than showing nothing.
///
/// Formats through the **injected calendar's** time zone rather than
/// `Date.formatted`'s device default. In production those match; the
/// discipline is what stops a UTC-pinned test or preview from quietly
/// rendering a shifted hour.
enum DayStartHourLabel {
    static func text(for hour: Int, calendar: Calendar = .current) -> String {
        // Midnight gets a word, not a number: it's the default, and
        // "12:00 AM" reads like something deliberately configured.
        guard hour != 0 else { return String(localized: "Midnight") }

        var components = DateComponents()
        components.year = 2000
        components.month = 1
        components.day = 1
        components.hour = hour
        guard let date = calendar.date(from: components) else { return "\(hour)" }

        return formatter(for: calendar).string(from: date)
    }

    /// `DateFormatter` is the most expensive Foundation object to build,
    /// and `setLocalizedDateFormatFromTemplate` runs ICU pattern
    /// negotiation on top. The Settings picker asks for seven labels per
    /// body evaluation, so the formatter is cached and only rebuilt when
    /// the locale or time zone actually changes.
    private static var cached: (key: String, formatter: DateFormatter)?

    private static func formatter(for calendar: Calendar) -> DateFormatter {
        let locale = calendar.locale ?? .current
        let key = "\(locale.identifier)|\(calendar.timeZone.identifier)"
        if let cached, cached.key == key { return cached.formatter }

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("jmm")
        cached = (key, formatter)
        return formatter
    }
}
