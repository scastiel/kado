import Observation
import KadoCore

/// Exposes the current CloudKit account status to views and services.
/// Implementations are `@Observable` so SwiftUI re-renders when the
/// status changes (e.g. the user signs in/out of iCloud while the
/// app is running).
///
/// The real implementation lives in `DefaultCloudAccountStatusObserver`
/// and wraps `CKContainer`. Tests and previews use
/// `MockCloudAccountStatusObserver` to drive each case
/// deterministically.
@MainActor
protocol CloudAccountStatusObserving: AnyObject, Observable {
    var status: CloudAccountStatus { get }

    /// Whether sync is actually working, derived from
    /// `NSPersistentCloudKitContainer`'s finished sync events. An
    /// `.available` account with `.failing` health means data is NOT
    /// reaching iCloud — the UI must not claim "Syncing with iCloud".
    var syncHealth: CloudSyncHealth { get }

    /// Re-query the backing provider. The default observer also
    /// refreshes automatically on `.CKAccountChanged` notifications;
    /// this method is the manual hook for tests and first-launch
    /// warm-up.
    func refresh() async
}
