import Foundation

/// Single source of truth for the "Day starts at" preference — the
/// hour at which Kadō rolls over to the next day.
///
/// Mirrors ``DevModeDefaults``: the value lives in the App Group
/// suite so the widget extension can read it if it ever needs to,
/// and falls back to `.standard` when the entitlement isn't active.
///
/// The preference is deliberately **not** a `@Model` property. Storing
/// it in `UserDefaults` keeps the SwiftData schema — and therefore the
/// CloudKit Production schema — untouched. It also means the setting
/// is device-local; two devices disagreeing causes no corruption,
/// because a completion's day is fixed by whichever device wrote it
/// (see ``DayBoundary``).
nonisolated public enum DayStartDefaults {
    public static let key = "kado.dayStartHour"

    /// Hours the Settings picker offers — every hour of the day.
    ///
    /// The first cut stopped at 6 AM on the premise that the cutoff
    /// sits inside the user's sleep. An overnight worker's sleep is in
    /// the daytime and their day starts when they wake, mid-afternoon,
    /// so the cap was exactly wrong for the person it was meant to
    /// serve (#93). ``DayBoundary`` clamps to the same `0...23`, so the
    /// two can't disagree.
    public static let allowedHours = 0...23

    /// Midnight — today's behaviour, and what every user gets until
    /// they deliberately change it.
    public static let defaultHour = 0

    /// UserDefaults suite shared between the main app and the widget
    /// extension. Returns `.standard` when the App Group suite can't
    /// be opened so the app still launches.
    nonisolated(unsafe) public static let sharedDefaults: UserDefaults = {
        UserDefaults(suiteName: SharedStore.appGroupID) ?? .standard
    }()

    /// Reads the stored hour, clamped into ``allowedHours``. An unset
    /// key, a stray write from another process, or anything nonsensical
    /// all resolve to a usable hour rather than trapping.
    public static func hour(in defaults: UserDefaults = sharedDefaults) -> Int {
        guard defaults.object(forKey: key) != nil else { return defaultHour }
        return clamp(defaults.integer(forKey: key))
    }

    public static func setHour(_ hour: Int, in defaults: UserDefaults = sharedDefaults) {
        defaults.set(clamp(hour), forKey: key)
    }

    public static func clamp(_ hour: Int) -> Int {
        min(max(hour, allowedHours.lowerBound), allowedHours.upperBound)
    }

    /// The user's current day boundary, for code that has no SwiftUI
    /// `Environment` to read `\.dayBoundary` from — App Intents, the
    /// notification-action handler, and the widget snapshot builder.
    ///
    /// Views should use `@Environment(\.dayBoundary)` instead: it
    /// re-evaluates the body when the setting changes, which reading
    /// `UserDefaults` directly does not.
    public static func boundary(
        calendar: Calendar = .current,
        in defaults: UserDefaults = sharedDefaults
    ) -> DayBoundary {
        DayBoundary(calendar: calendar, startHour: hour(in: defaults))
    }
}
