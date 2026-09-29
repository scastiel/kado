import Foundation

/// A cosmetic choice some of whose options need the Supporter pack — a
/// habit colour theme, an app icon.
///
/// The stored preference is never rewritten when the pack lapses.
/// Whatever reads it resolves it through ``effective(preferred:isSupporter:)``
/// instead, so a refunded or revoked purchase shows ``freeFallback``
/// until the pack comes back (a restore, a re-purchase), and then the
/// user's own pick again, with nothing lost in between. Habits only
/// store their slot, so no habit data is touched either way.
///
/// Adopting it is one conformance:
///
/// ```swift
/// extension HabitTheme: SupporterGated {
///     public var requiresSupporterPack: Bool { self != .kado && self != .classic }
///     public static let freeFallback = HabitTheme.kado
/// }
/// ```
nonisolated public protocol SupporterGated: Equatable {
    /// Whether this option needs the Supporter pack. Must be `false`
    /// for ``freeFallback``.
    var requiresSupporterPack: Bool { get }

    /// What a paid option resolves to without the pack. Always free.
    static var freeFallback: Self { get }
}

extension SupporterGated {
    /// The option to actually render: the user's pick, unless it needs
    /// a pack they no longer (or never) owned.
    public static func effective(preferred: Self, isSupporter: Bool) -> Self {
        preferred.isLocked(isSupporter: isSupporter) ? freeFallback : preferred
    }

    /// The same, reading ownership from the App Group mirror — for the
    /// widget extension and anything else with no StoreKit observer.
    /// Views in the app use the `isSupporter` of `\.supporterPack`
    /// instead, which redraws when it changes.
    public static func effective(
        preferred: Self,
        in defaults: UserDefaults = SupporterDefaults.sharedDefaults
    ) -> Self {
        effective(preferred: preferred, isSupporter: SupporterDefaults.isSupporter(in: defaults))
    }

    /// Whether a picker should show this option with a lock.
    public func isLocked(isSupporter: Bool) -> Bool {
        requiresSupporterPack && !isSupporter
    }
}
