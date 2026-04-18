import Foundation
import Observation
import SwiftData
import UserNotifications
import WidgetKit
import KadoCore

/// Owns the `UNUserNotificationCenterDelegate` and routes banner
/// actions (`Complete` / `Skip`) in-process, without the relaunch
/// that an `AppIntent`-backed action would force.
///
/// Wiring:
/// - `KadoApp` constructs one per launch, registers the
///   `kado.habit` category with its actions, and sets the
///   delegate on `UNUserNotificationCenter.current()`.
/// - When the user taps **Complete**, the manager reaches the live
///   SwiftData container via `ActiveContainer.shared.get()` — the
///   same path `CompleteHabitIntent` uses — and toggles today via
///   `CompletionToggler`.
/// - After any mutation, it rebuilds the widget snapshot and asks
///   the scheduler to `rescheduleAll` so the now-completed day's
///   remaining requests go away.
///
/// Pure routing lives in `Self.route(actionIdentifier:userInfo:)`
/// so it's unit-testable without having to fabricate a real
/// `UNNotificationResponse` (which has no public init).
@MainActor
@Observable
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let completeActionIdentifier = "kado.action.complete"
    static let skipActionIdentifier = "kado.action.skip"

    let scheduler: any NotificationScheduling
    let calendar: Calendar

    init(
        scheduler: any NotificationScheduling,
        calendar: Calendar = .current
    ) {
        self.scheduler = scheduler
        self.calendar = calendar
        super.init()
    }

    /// Installs the delegate and registers the `kado.habit` category.
    /// Idempotent — calling twice in the same process is safe.
    func configure() async {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        let complete = UNNotificationAction(
            identifier: Self.completeActionIdentifier,
            title: String(localized: "Complete"),
            options: [.authenticationRequired]
        )
        let skip = UNNotificationAction(
            identifier: Self.skipActionIdentifier,
            title: String(localized: "Skip"),
            options: []
        )
        let category = UNNotificationCategory(
            identifier: DefaultNotificationScheduler.categoryIdentifier,
            actions: [complete, skip],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category])
    }

    // MARK: - Routing

    enum Decision: Equatable {
        case complete(UUID)
        case skip
        case openApp
        case unknown
    }

    /// Pure function extracting what the delegate should do from the
    /// action identifier + payload. No I/O, no SwiftData — cheap to
    /// test exhaustively.
    static func route(
        actionIdentifier: String,
        userInfo: [AnyHashable: Any]
    ) -> Decision {
        let idString = userInfo["habitID"] as? String ?? ""
        let habitID = UUID(uuidString: idString)

        switch actionIdentifier {
        case completeActionIdentifier:
            return habitID.map(Decision.complete) ?? .unknown
        case skipActionIdentifier:
            return .skip
        case UNNotificationDefaultActionIdentifier:
            return .openApp
        case UNNotificationDismissActionIdentifier:
            return .skip
        default:
            return .unknown
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping @Sendable (UNNotificationPresentationOptions) -> Void
    ) {
        // Show the banner even while the app is foregrounded —
        // otherwise the user dismisses it without seeing why their
        // own reminder fired.
        completionHandler([.banner, .sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping @Sendable () -> Void
    ) {
        let actionID = response.actionIdentifier
        let userInfo = response.notification.request.content.userInfo

        Task { @MainActor in
            let decision = Self.route(actionIdentifier: actionID, userInfo: userInfo)
            switch decision {
            case .complete(let habitID):
                await self.handleComplete(habitID: habitID)
            case .skip, .openApp, .unknown:
                break
            }
            completionHandler()
        }
    }

    // MARK: - Complete handling

    private func handleComplete(habitID: UUID) async {
        guard let container = try? ActiveContainer.shared.get() else { return }
        let context = container.mainContext
        guard let record = fetchHabit(id: habitID, in: context) else { return }
        guard record.archivedAt == nil else { return }
        // Reuse the intent's pure core so binary/negative vs
        // counter/timer semantics stay in lockstep. Counter/timer
        // habits can't be meaningfully toggled from a banner — the
        // user still gets to tap the banner to open the app.
        _ = try? CompleteHabitIntent.apply(
            habitID: habitID,
            in: context,
            calendar: calendar,
            now: .now
        )
        WidgetSnapshotBuilder.rebuildAndWrite(using: context)
        WidgetCenter.shared.reloadAllTimelines()

        let habits = try? context.fetch(FetchDescriptor<HabitRecord>())
        let completions = try? context.fetch(FetchDescriptor<CompletionRecord>())
        await scheduler.rescheduleAll(
            habits: (habits ?? []).map(\.snapshot),
            completions: (completions ?? []).map(\.snapshot)
        )
    }

    private func fetchHabit(id: UUID, in context: ModelContext) -> HabitRecord? {
        let descriptor = FetchDescriptor<HabitRecord>()
        return (try? context.fetch(descriptor))?.first(where: { $0.id == id })
    }
}
