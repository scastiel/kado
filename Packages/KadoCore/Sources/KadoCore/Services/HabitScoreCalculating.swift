import Foundation

/// Computes Kadō's habit score — an exponential moving average of
/// per-day completion values, in `[0.0, 1.0]`. See
/// `docs/habit-score.md` for the algorithm spec.
public protocol HabitScoreCalculating: Sendable {
    /// Score as of `date`, computed from the habit's full history.
    func currentScore(
        for habit: Habit,
        completions: [Completion],
        asOf date: Date
    ) -> Double

    /// Score for every day in `startDate ... endDate`. Useful for
    /// graphs. The series includes one entry per day, even on
    /// non-due days (where the score carries forward unchanged).
    func scoreHistory(
        for habit: Habit,
        completions: [Completion],
        from startDate: Date,
        to endDate: Date
    ) -> [DailyScore]
}
