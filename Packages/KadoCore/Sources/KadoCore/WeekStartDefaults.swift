import Foundation

/// The day a week starts on, as offered by Settings → Week.
///
/// Raw values are `Calendar.firstWeekday` values (1 = Sunday, 2 =
/// Monday), which makes ``firstWeekday(in:)`` a plain read for every
/// case but ``automatic``. Zero is free because no weekday uses it,
/// so it carries "follow the region" without a parallel flag.
nonisolated public enum WeekStart: Int, CaseIterable, Hashable, Codable, Sendable {
    /// Whatever the user's region says — the default, and what every
    /// user gets until they deliberately change it.
    case automatic = 0
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7
}

public extension WeekStart {
    /// The day this option pins to, or `nil` for ``automatic``.
    var weekday: Weekday? {
        Weekday(rawValue: rawValue)
    }

    /// Resolves to a `Calendar.firstWeekday` value. ``automatic``
    /// defers to `base`, whose `firstWeekday` Foundation already
    /// derives from the region — so "automatic" needs no locale table
    /// of its own.
    func firstWeekday(in base: Calendar = .current) -> Int {
        weekday?.rawValue ?? base.firstWeekday
    }

    /// `base` with this option applied. Everything else about the
    /// calendar — identity, time zone, locale — is left alone.
    func calendar(base: Calendar = .current) -> Calendar {
        var calendar = base
        calendar.firstWeekday = firstWeekday(in: base)
        return calendar
    }
}

/// Single source of truth for the "Week starts on" preference.
///
/// Mirrors ``DayStartDefaults``: stored in `UserDefaults` rather than
/// on a `@Model` so the SwiftData — and therefore CloudKit Production
/// — schema stays untouched, and in the App Group suite so an
/// extension can read it without a second store. Being device-local
/// is the right shape for a display preference: two devices
/// disagreeing changes nothing about the data, only about which
/// column Monday lands in.
nonisolated public enum WeekStartDefaults {
    public static let key = "kado.weekStart"

    public static let defaultValue: WeekStart = .automatic

    /// UserDefaults suite shared between the main app and the widget
    /// extension. Returns `.standard` when the App Group suite can't
    /// be opened so the app still launches.
    nonisolated(unsafe) public static let sharedDefaults: UserDefaults = {
        UserDefaults(suiteName: SharedStore.appGroupID) ?? .standard
    }()

    /// Reads the stored choice. An unset key, or a raw value written
    /// by a future build with more cases, both resolve to
    /// ``WeekStart/automatic`` rather than trapping.
    public static func weekStart(in defaults: UserDefaults = sharedDefaults) -> WeekStart {
        guard defaults.object(forKey: key) != nil else { return defaultValue }
        return WeekStart(rawValue: defaults.integer(forKey: key)) ?? defaultValue
    }

    public static func setWeekStart(_ weekStart: WeekStart, in defaults: UserDefaults = sharedDefaults) {
        defaults.set(weekStart.rawValue, forKey: key)
    }

    /// The calendar views should lay weeks out with, for code that has
    /// no SwiftUI `Environment` to read `\.calendar` from.
    ///
    /// Views should use `@Environment(\.calendar)` instead — `KadoApp`
    /// injects this at the root, and reading `UserDefaults` directly
    /// wouldn't re-evaluate the body when the setting changes.
    public static func calendar(
        base: Calendar = .current,
        in defaults: UserDefaults = sharedDefaults
    ) -> Calendar {
        weekStart(in: defaults).calendar(base: base)
    }
}
