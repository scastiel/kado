import Foundation
import KadoCore

/// The five CloudKit account states the app cares about, mapped 1:1
/// from `CKAccountStatus`. Declaring our own enum keeps views free
/// of CloudKit imports and lets a future Apple-added case trigger a
/// compile error at the mapping site rather than degrade silently.
enum CloudAccountStatus: Equatable, Sendable {
    /// iCloud is signed in, CloudKit is usable. Data syncs.
    case available

    /// No iCloud account signed in on the device. Local-only.
    case noAccount

    /// iCloud is restricted by Screen Time, MDM, or parental
    /// controls. Local-only until the restriction is lifted.
    case restricted

    /// CloudKit could not determine status yet (pre-first-refresh
    /// or a transient lookup failure). Treated as "checking…" in
    /// the UI.
    case couldNotDetermine

    /// Account is signed in but CloudKit is temporarily unreachable
    /// (server-side or network). Usually recovers without user
    /// action.
    case temporarilyUnavailable
}
