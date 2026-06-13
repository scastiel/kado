import CloudKit
import Foundation

/// Whether CloudKit sync is actually moving data, as opposed to the
/// account merely being signed in. `CKContainer.accountStatus()` says
/// nothing about sync health — an App Store build pointed at a
/// CloudKit Production environment with no deployed schema reports
/// `.available` while every import/export fails (issue #52). This
/// state is derived from `NSPersistentCloudKitContainer`'s finished
/// sync events instead.
nonisolated enum CloudSyncHealth: Equatable, Sendable {
    /// No sync event has finished yet (fresh launch, or sync never
    /// attempted). The UI treats this as healthy-until-proven-otherwise.
    case unknown

    /// The most recent finished sync event succeeded.
    case healthy

    /// The most recent finished sync event failed for a reason that
    /// won't resolve on its own (schema mismatch, quota exceeded,
    /// bad container…). Surfaced in Settings so "Syncing with iCloud"
    /// is never shown while sync is broken.
    case failing
}

/// Pure mapping from a finished `NSPersistentCloudKitContainer.Event`
/// outcome to a `CloudSyncHealth`. Kept as a free-standing enum (no
/// CloudKit event dependency) so the rules are unit-testable —
/// `NSPersistentCloudKitContainer.Event` has no public initializer.
nonisolated enum CloudSyncEventAssessor {
    /// Transient conditions that recover without user or developer
    /// action; they keep the previous assessment instead of flagging
    /// sync as broken while the user rides the subway.
    private static let transientCodes: Set<CKError.Code> = [
        .networkUnavailable,
        .networkFailure,
        .serviceUnavailable,
        .requestRateLimited,
        .zoneBusy,
        .accountTemporarilyUnavailable,
    ]

    static func health(
        after current: CloudSyncHealth,
        succeeded: Bool,
        error: Error?
    ) -> CloudSyncHealth {
        if succeeded { return .healthy }
        if let ckError = error as? CKError, transientCodes.contains(ckError.code) {
            return current
        }
        return .failing
    }
}
