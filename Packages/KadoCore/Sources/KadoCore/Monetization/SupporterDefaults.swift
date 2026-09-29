import Foundation

/// The App Group mirror of "does this device own the Supporter pack".
///
/// StoreKit is the source of truth, and only the main app observes it
/// (`DefaultSupporterPackStore`). The widget extension still has to
/// fall back from a paid theme the moment the pack is refunded, so the
/// app writes its answer here whenever it changes, and anything outside
/// the app reads it through ``SupporterGated/effective(preferred:in:)``
/// — never the raw preference on its own.
///
/// Mirrors ``DayStartDefaults``: the App Group suite, falling back to
/// `.standard` when the entitlement isn't active. A missing key means
/// "not a supporter", which is also the safe answer for a fresh
/// install whose StoreKit check hasn't run yet.
nonisolated public enum SupporterDefaults {
    public static let key = "kado.isSupporter"

    nonisolated(unsafe) public static let sharedDefaults: UserDefaults = {
        UserDefaults(suiteName: SharedStore.appGroupID) ?? .standard
    }()

    public static func isSupporter(in defaults: UserDefaults = sharedDefaults) -> Bool {
        defaults.bool(forKey: key)
    }

    public static func setSupporter(_ isSupporter: Bool, in defaults: UserDefaults = sharedDefaults) {
        defaults.set(isSupporter, forKey: key)
    }
}
