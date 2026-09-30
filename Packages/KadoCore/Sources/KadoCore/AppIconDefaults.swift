import Foundation

/// Single source of truth for the "App icon" preference.
///
/// Mirrors ``HabitThemeDefaults``, but in `.standard`: nothing outside
/// the app reads it, since only the app can change its icon. The system
/// keeps its own record of the icon it shows
/// (`UIApplication.alternateIconName`); this one is the user's *pick*,
/// which outlives a lapsed Supporter pack so a restore can put it back.
nonisolated public enum AppIconDefaults {
    public static let key = "kado.appIcon"

    public static let defaultValue: AppIcon = .kado

    /// Reads the stored choice. An unset key, or a raw value written by
    /// a future build with more icons, both resolve to
    /// ``AppIcon/kado`` rather than trapping.
    public static func icon(in defaults: UserDefaults = .standard) -> AppIcon {
        defaults.string(forKey: key).flatMap(AppIcon.init(rawValue:)) ?? defaultValue
    }

    public static func setIcon(_ icon: AppIcon, in defaults: UserDefaults = .standard) {
        defaults.set(icon.rawValue, forKey: key)
    }
}
