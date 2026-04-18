import Foundation
import Testing
import UserNotifications
@testable import Kado
import KadoCore

@Suite("NotificationManager.route")
@MainActor
struct NotificationManagerRoutingTests {
    @Test("Complete identifier with a valid habit UUID routes to .complete")
    func completeWithValidID() {
        let id = UUID()
        let decision = NotificationManager.route(
            actionIdentifier: NotificationManager.completeActionIdentifier,
            userInfo: ["habitID": id.uuidString]
        )
        #expect(decision == .complete(id))
    }

    @Test("Complete identifier without a habit id falls back to .unknown")
    func completeWithoutID() {
        let decision = NotificationManager.route(
            actionIdentifier: NotificationManager.completeActionIdentifier,
            userInfo: [:]
        )
        #expect(decision == .unknown)
    }

    @Test("Complete identifier with a non-UUID payload falls back to .unknown")
    func completeWithBadID() {
        let decision = NotificationManager.route(
            actionIdentifier: NotificationManager.completeActionIdentifier,
            userInfo: ["habitID": "not-a-uuid"]
        )
        #expect(decision == .unknown)
    }

    @Test("Skip identifier routes to .skip")
    func skipRoute() {
        let decision = NotificationManager.route(
            actionIdentifier: NotificationManager.skipActionIdentifier,
            userInfo: ["habitID": UUID().uuidString]
        )
        #expect(decision == .skip)
    }

    @Test("Default action (banner tap) routes to .openApp")
    func defaultTapRoute() {
        let decision = NotificationManager.route(
            actionIdentifier: UNNotificationDefaultActionIdentifier,
            userInfo: ["habitID": UUID().uuidString]
        )
        #expect(decision == .openApp)
    }

    @Test("Dismiss action routes to .skip")
    func dismissRoute() {
        let decision = NotificationManager.route(
            actionIdentifier: UNNotificationDismissActionIdentifier,
            userInfo: [:]
        )
        #expect(decision == .skip)
    }

    @Test("Unknown action identifier falls back to .unknown")
    func unknownRoute() {
        let decision = NotificationManager.route(
            actionIdentifier: "kado.action.future",
            userInfo: [:]
        )
        #expect(decision == .unknown)
    }
}
