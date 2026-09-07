import Foundation

extension Calendar {
    /// `Calendar.current` re-anchored on Sunday, for previews of the
    /// views whose layout follows `firstWeekday`.
    ///
    /// Previews render under the previewing Mac's own calendar, so on a
    /// Monday-first machine every one of them shows the order the app
    /// used to hard-code — the new state would be visible only by
    /// changing the machine's region. This is the one line that makes
    /// it previewable instead.
    static var sundayFirst: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 1
        return calendar
    }
}
