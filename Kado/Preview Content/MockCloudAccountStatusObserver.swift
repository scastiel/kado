import Observation

/// Test-/preview-only observer that returns a fixed `CloudAccountStatus`.
///
/// Lives in `Preview Content/` so it ships only with Debug builds. The
/// Settings previews drive each status case through this type; tests
/// reuse it via `@testable import Kado`.
@MainActor
@Observable
final class MockCloudAccountStatusObserver: CloudAccountStatusObserving {
    var status: CloudAccountStatus

    init(status: CloudAccountStatus = .couldNotDetermine) {
        self.status = status
    }

    func refresh() async {
        // no-op; the seed is the source of truth
    }
}
