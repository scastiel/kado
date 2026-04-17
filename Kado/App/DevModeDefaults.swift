import Foundation

/// Single source of truth for the `UserDefaults` keys that gate the
/// in-app dev mode. Kept in one place so the flag and the "has
/// confirmed the consequences" marker can never drift between the
/// root view, the Settings section, and the sync-status section.
nonisolated enum DevModeDefaults {
    static let key = "kado.devMode"
    static let hasConfirmedKey = "kado.devMode.hasConfirmed"
}
