import Foundation

/// Decides whether a habit is "due" on a given calendar day, given
/// its frequency, lifecycle (`createdAt` / `archivedAt`), and — for
/// flexible schedules like `.daysPerWeek` — its recent completion
/// history.
public protocol FrequencyEvaluating: Sendable {
    func isDue(habit: Habit, on date: Date, completions: [Completion]) -> Bool
}
