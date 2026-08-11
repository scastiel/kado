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

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = calendar.locale ?? .current
        formatter.setLocalizedDateFormatFromTemplate("jmm")
        return formatter.string(from: date)
    }
}
