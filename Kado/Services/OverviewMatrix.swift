import Foundation

/// One row of the Overview matrix: a habit plus its per-day cells.
struct MatrixRow: Equatable, Sendable {
    let habit: Habit
    let days: [DayCell]
}

/// Per-day state for the matrix. `.scored` carries the EMA score on
/// that day (0...1); `.notDue` covers pre-creation and off-schedule
/// days; `.future` is used for dates beyond today.
enum DayCell: Equatable, Sendable {
    case future
    case notDue
    case scored(Double)
}

/// Turns habits + completions + a day range into matrix rows.
/// Stateless; the View computes a fresh matrix per render.
enum OverviewMatrix {
    static func compute(
        habits: [Habit],
        completions: [Completion],
        days: [Date],
        today: Date,
        calendar: Calendar,
        scoreCalculator: any HabitScoreCalculating,
        frequencyEvaluator: any FrequencyEvaluating
    ) -> [MatrixRow] {
        // Stub — implementation lands in the follow-up commit.
        []
    }
}
