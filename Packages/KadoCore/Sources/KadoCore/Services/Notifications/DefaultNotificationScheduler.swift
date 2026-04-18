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
        await clearAllOwnedRequests()
        let today = calendar.startOfDay(for: now())
        for habit in habits where habit.remindersEnabled && habit.archivedAt == nil {
            let habitCompletions = completions.filter { $0.habitID == habit.id }
            let streak = streakCalculator.current(for: habit, completions: habitCompletions, asOf: now())
            for offset in 0..<Self.windowDays {
                guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
                guard frequencyEvaluator.isDue(habit: habit, on: day, completions: habitCompletions) else { continue }
                let request = makeRequest(habit: habit, day: day, streak: streak)
                try? await center.add(request)
            }
        }
    }

    public func cancel(habitID: UUID) async {
        let pending = await center.pendingNotificationRequests()
        let prefix = Self.identifierPrefix + habitID.uuidString + "."
        let matches = pending
            .map(\.identifier)
            .filter { $0.hasPrefix(prefix) }
        await center.removePendingNotificationRequests(withIdentifiers: matches)
    }

    public func requestAuthorizationIfNeeded() async -> UNAuthorizationStatus {
        let current = await center.authorizationStatus()
        guard current == .notDetermined else { return current }
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        return await center.authorizationStatus()
    }

    // MARK: - Internals

    private func clearAllOwnedRequests() async {
        let pending = await center.pendingNotificationRequests()
        let ours = pending
            .map(\.identifier)
            .filter { $0.hasPrefix(Self.identifierPrefix) }
        guard !ours.isEmpty else { return }
        await center.removePendingNotificationRequests(withIdentifiers: ours)
    }

    private func makeRequest(habit: Habit, day: Date, streak: Int) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        // Title is the habit name — that's what the user asked to be
        // reminded of. Body (when present) augments with a streak
        // nudge. Keeping title + body non-redundant avoids iOS
        // stacking "Meditate" over "Meditate."
        content.title = habit.name
        if let bodyText = composeBody(streak: streak) {
            content.body = bodyText
        }
        content.categoryIdentifier = Self.categoryIdentifier
        content.userInfo = ["habitID": habit.id.uuidString]
        content.sound = .default

        var components = calendar.dateComponents([.year, .month, .day], from: day)
        components.hour = habit.reminderHour
        components.minute = habit.reminderMinute
        components.timeZone = calendar.timeZone
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let identifier = Self.identifierPrefix + habit.id.uuidString + "." + dayFormatter.string(from: day)
        return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    }

    private func composeBody(streak: Int) -> String? {
        guard streak > 0 else { return nil }
        let format = String(
            localized: "notifications.body.streak",
            defaultValue: "%lld day streak — keep it going",
            comment: "Reminder banner body when a habit has an active streak. Argument: streak length in days."
        )
        return String(format: format, streak)
    }

    private var dayFormatter: DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = calendar.timeZone
        return f
    }
}
