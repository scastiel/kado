import Foundation

/// Current and best streak for a habit. See `docs/streak.md` for the
/// full algorithm and per-frequency semantics.
public protocol StreakCalculating: Sendable {
    /// Consecutive "due days" completed up to `date`. Today (or the
    /// habit's `archivedAt`) is a grace day — it doesn't break the
    /// streak if not yet completed.
    func current(for habit: Habit, completions: [Completion], asOf date: Date) -> Int

    /// Longest consecutive run in the habit's full history.
    func best(for habit: Habit, completions: [Completion], asOf date: Date) -> Int
}
