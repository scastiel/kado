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

    /// Re-query the backing provider. The default observer also
    /// refreshes automatically on `.CKAccountChanged` notifications;
    /// this method is the manual hook for tests and first-launch
    /// warm-up.
    func refresh() async
}
