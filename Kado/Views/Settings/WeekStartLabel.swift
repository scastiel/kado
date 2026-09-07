import Foundation
import KadoCore

/// Renders a "Week starts on" option the way the Settings picker
/// offers it.
///
/// `localeCalendar` must be a calendar whose `firstWeekday` still
/// comes from the region — `Calendar.current`, not the one in
/// `\.calendar`. The environment's copy already carries the user's
/// choice, so feeding it here would make the Automatic row describe
/// itself: pick Monday in a Sunday region and it would read
/// "Automatic (Monday)".
enum WeekStartLabel {
    static func text(for weekStart: WeekStart, localeCalendar: Calendar = .current) -> String {
        guard let weekday = weekStart.weekday else {
            let region = Weekday(rawValue: localeCalendar.firstWeekday)?.localizedFull ?? ""
            return String(localized: "Automatic (\(region))")
        }
        return weekday.localizedFull
    }
}
