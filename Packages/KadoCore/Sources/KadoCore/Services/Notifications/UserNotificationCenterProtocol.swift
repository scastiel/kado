import Foundation
import UserNotifications

/// System-API seam over `UNUserNotificationCenter`. Tests substitute
/// an in-memory fake; production wires `UNUserNotificationCenter.current()`
/// via an extension in the main app.
///
/// Only the methods we actually use are exposed — keep the surface
/// minimal so the fake stays cheap to maintain.
public protocol UserNotificationCenterProtocol: Sendable {
    func add(_ request: UNNotificationRequest) async throws
    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) async
    func pendingNotificationRequests() async -> [UNNotificationRequest]
    func setNotificationCategories(_ categories: Set<UNNotificationCategory>) async
    func authorizationStatus() async -> UNAuthorizationStatus
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
}
