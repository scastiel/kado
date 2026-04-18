import Foundation
import UserNotifications

/// Schedules local reminder notifications for habits. Keeps the
/// pending set coherent with SwiftData state by clearing and
/// re-registering on every lifecycle / mutation hook.
///
/// Implementations must be idempotent: calling `rescheduleAll` twice
/// in a row produces the same pending set as calling it once.
public protocol NotificationScheduling: Sendable {
    /// Rebuild the pending set for the given snapshot of habits and
    /// their recent completions. Callers pass everything the
    /// scheduler needs; the scheduler never fetches from SwiftData
    /// directly.
    func rescheduleAll(habits: [Habit], completions: [Completion]) async

    /// Drop all pending requests for a single habit. Used on
    /// archive / delete where the caller doesn't want to supply a
    /// full habit list.
    func cancel(habitID: UUID) async

    /// Request banner/alert authorization when the current status is
    /// `.notDetermined`. Returns the resulting status (or the
    /// pre-existing one if already decided).
    func requestAuthorizationIfNeeded() async -> UNAuthorizationStatus
}
