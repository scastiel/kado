import Foundation
import UserNotifications
import KadoCore

/// Test-/preview-only `NotificationScheduling` that records calls and
/// returns a configurable authorization status. Never touches the
/// real notification center, so previews and tests never emit banners.
///
/// Lives in `Preview Content/` so it ships only with Debug builds.
final class MockNotificationScheduler: NotificationScheduling, @unchecked Sendable {
    private(set) var rescheduleCalls: Int = 0
    private(set) var cancelCalls: [UUID] = []
    private(set) var authorizationRequested: Bool = false

    var stubbedStatus: UNAuthorizationStatus

    init(stubbedStatus: UNAuthorizationStatus = .notDetermined) {
        self.stubbedStatus = stubbedStatus
    }

    func rescheduleAll(habits: [Habit], completions: [Completion]) async {
        rescheduleCalls += 1
    }

    func cancel(habitID: UUID) async {
        cancelCalls.append(habitID)
    }

    func requestAuthorizationIfNeeded() async -> UNAuthorizationStatus {
        authorizationRequested = true
        return stubbedStatus
    }
}
