import Foundation
import UserNotifications
@testable import Kado
import KadoCore

/// In-memory `UserNotificationCenterProtocol` used by scheduler
/// tests. Records every call and serves a configurable
/// `authorizationStatus`. No actual notifications are posted.
///
/// `@unchecked Sendable`: tests drive the fake sequentially from a
/// single task, so no cross-thread access occurs. The fake
/// deliberately avoids `NSLock` because its non-scoped `lock`/`unlock`
/// are disallowed from async contexts under Swift 6 mode.
final class FakeUserNotificationCenter: UserNotificationCenterProtocol, @unchecked Sendable {
    private(set) var pending: [UNNotificationRequest] = []
    private(set) var registeredCategories: Set<UNNotificationCategory> = []
    private(set) var authorizationRequests: [UNAuthorizationOptions] = []

    var stubbedAuthorizationStatus: UNAuthorizationStatus = .notDetermined
    var stubbedGrantedOnRequest: Bool = true
    var stubbedStatusAfterRequest: UNAuthorizationStatus = .authorized

    func add(_ request: UNNotificationRequest) async throws {
        pending.removeAll { $0.identifier == request.identifier }
        pending.append(request)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) async {
        let drop = Set(identifiers)
        pending.removeAll { drop.contains($0.identifier) }
    }

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        pending
    }

    func setNotificationCategories(_ categories: Set<UNNotificationCategory>) async {
        registeredCategories = categories
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        stubbedAuthorizationStatus
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        authorizationRequests.append(options)
        stubbedAuthorizationStatus = stubbedStatusAfterRequest
        return stubbedGrantedOnRequest
    }
}
