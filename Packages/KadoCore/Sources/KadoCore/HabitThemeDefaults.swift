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

    /// The theme to paint in outside the app: the stored pick, gated on
    /// the App Group's Supporter pack mirror, so a widget falls back to
    /// Kadō when the pack is refunded. What the widgets read — never
    /// ``theme(in:)`` on its own, which would keep painting a lapsed
    /// paid theme.
    public static func renderedTheme(
        in defaults: UserDefaults = sharedDefaults,
        supporterDefaults: UserDefaults = SupporterDefaults.sharedDefaults
    ) -> HabitTheme {
        HabitTheme.effective(preferred: theme(in: defaults), in: supporterDefaults)
    }

    public static func setTheme(_ theme: HabitTheme, in defaults: UserDefaults = sharedDefaults) {
        defaults.set(theme.rawValue, forKey: key)
    }
}
