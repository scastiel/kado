import Foundation
import UserNotifications

/// Production `NotificationScheduling` implementation. Composes a
/// `UserNotificationCenterProtocol` with the domain's frequency
/// evaluator and streak calculator to derive the next 7 days of due
/// reminders.
///
/// `nonisolated` so the service can be constructed off-MainActor.
/// Each method is `async` and the underlying center does its own
/// locking, so no actor isolation is required here.
public final class DefaultNotificationScheduler: NotificationScheduling, @unchecked Sendable {
    /// Identifier prefix for all pending requests we own. Lets us
    /// filter-and-remove without touching unrelated notifications
    /// the app might register for in the future.
    public static let identifierPrefix = "kado.reminder."

    /// Category identifier for the habit-reminder actions. The
    /// `NotificationManager` in the main app registers matching
    /// `UNNotificationCategory` actions under this ID.
    public static let categoryIdentifier = "kado.habit"

    /// Number of future days pre-registered per habit. Capped to stay
    /// under iOS's 64-pending-request ceiling with ~9 habits; beyond
    /// that the scheduler still keeps the nearest-in-time requests
    /// and leans on the `.active` transition to top up.
    public static let windowDays = 7

    let center: any UserNotificationCenterProtocol
    let frequencyEvaluator: any FrequencyEvaluating
    let streakCalculator: any StreakCalculating
    let calendar: Calendar

    /// Clock injection for tests; production uses `Date.init`.
    let now: @Sendable () -> Date

    public init(
        center: any UserNotificationCenterProtocol,
        frequencyEvaluator: any FrequencyEvaluating = DefaultFrequencyEvaluator(),
        streakCalculator: any StreakCalculating = DefaultStreakCalculator(),
        calendar: Calendar = .current,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.center = center
        self.frequencyEvaluator = frequencyEvaluator
        self.streakCalculator = streakCalculator
        self.calendar = calendar
        self.now = now
    }

    public func rescheduleAll(habits: [Habit], completions: [Completion]) async {
        // Implementation lands in Task 3 (TDD).
    }

    public func cancel(habitID: UUID) async {
        // Implementation lands in Task 3 (TDD).
    }

    public func requestAuthorizationIfNeeded() async -> UNAuthorizationStatus {
        // Implementation lands in Task 3 (TDD).
        await center.authorizationStatus()
    }
}
