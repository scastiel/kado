import Foundation
import UserNotifications
import KadoCore

/// Production `UserNotificationCenterProtocol` adapter wrapping
/// `UNUserNotificationCenter.current()`. Lives in the main app target
/// (not `KadoCore`) because the center is `@MainActor`-hostile
/// enough to warrant local bridging rather than a platform shim in
/// the shared package.
///
/// All methods forward to the real center; the async wrappers bridge
/// completion-handler APIs where needed. `@unchecked Sendable` is
/// safe because `UNUserNotificationCenter` is documented as
/// thread-safe and the adapter holds no additional state.
struct LiveUserNotificationCenter: UserNotificationCenterProtocol, @unchecked Sendable {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func add(_ request: UNNotificationRequest) async throws {
        try await center.add(request)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) async {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        await center.pendingNotificationRequests()
    }

    func setNotificationCategories(_ categories: Set<UNNotificationCategory>) async {
        center.setNotificationCategories(categories)
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        try await center.requestAuthorization(options: options)
    }
}
