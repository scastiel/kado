import Foundation

/// Single source of truth for the `UserDefaults` keys that gate the
/// in-app dev mode. Kept in one place so the flag and the "has
/// confirmed the consequences" marker can never drift between the
/// root view, the Settings section, and the sync-status section.
///
/// The values live in the App Group suite so the widget extension
/// can see the same flag and swap its `ModelContainer` URL
/// accordingly. Falls back to `.standard` on dev builds where the
/// App Group entitlement isn't yet active.
nonisolated public enum DevModeDefaults {
    public static let key = "kado.devMode"
    public static let hasConfirmedKey = "kado.devMode.hasConfirmed"

    /// UserDefaults suite shared between the main app and the widget
    /// extension. Returns `.standard` when the App Group suite can't
    /// be opened so the app still launches.
    nonisolated(unsafe) public static let sharedDefaults: UserDefaults = {
        UserDefaults(suiteName: SharedStore.appGroupID) ?? .standard
    }()

    /// Copy values from one UserDefaults instance to another for the
    /// keys owned by this enum. Never overwrites existing values in
    /// the destination. No-op when source and destination are the
    /// same instance (the App Group entitlement isn't active yet).
    public static func migrate(from source: UserDefaults, to destination: UserDefaults) {
        guard source !== destination else { return }
        for key in [key, hasConfirmedKey] {
            guard destination.object(forKey: key) == nil else { continue }
            if let value = source.object(forKey: key) {
                destination.set(value, forKey: key)
            }
        }
    }

    /// Copy any pre-existing values from `.standard` into the shared
    /// suite so users who toggled dev mode before the App Group
    /// rollout don't lose their state on update.
    public static func migrateFromStandardIfNeeded() {
        migrate(from: .standard, to: sharedDefaults)
    }
}
