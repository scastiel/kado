import Foundation

/// Single source of truth for the "Habit colours" preference.
///
/// Mirrors ``WeekStartDefaults``: stored in `UserDefaults` rather than
/// on a `@Model` so the SwiftData — and therefore CloudKit Production
/// — schema stays untouched, and in the App Group suite because the
/// widget extension reads it too, to paint its tiles in the same
/// theme. Per-device, which suits a display preference: two devices
/// disagreeing changes how habits look there, never what they are.
nonisolated public enum HabitThemeDefaults {
    public static let key = "kado.habitTheme"

    public static let defaultValue: HabitTheme = .kado

    /// UserDefaults suite shared between the main app and the widget
    /// extension. Returns `.standard` when the App Group suite can't
    /// be opened so the app still launches.
    nonisolated(unsafe) public static let sharedDefaults: UserDefaults = {
        UserDefaults(suiteName: SharedStore.appGroupID) ?? .standard
    }()

    /// Reads the stored choice. An unset key, or a raw value written
    /// by a future build with more themes, both resolve to
    /// ``HabitTheme/kado`` rather than trapping.
    public static func theme(in defaults: UserDefaults = sharedDefaults) -> HabitTheme {
        defaults.string(forKey: key).flatMap(HabitTheme.init(rawValue:)) ?? defaultValue
    }

    public static func setTheme(_ theme: HabitTheme, in defaults: UserDefaults = sharedDefaults) {
        defaults.set(theme.rawValue, forKey: key)
    }
}
