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
        let todayStart = calendar.startOfDay(for: today)
        let activeHabits = habits
            .filter { $0.archivedAt == nil }
            .sorted { $0.createdAt < $1.createdAt }

        guard let firstDay = days.first, let lastDay = days.last else {
            return activeHabits.map { MatrixRow(habit: $0, days: []) }
        }

        return activeHabits.map { habit in
            let habitCompletions = completions.filter { $0.habitID == habit.id }
            let history = scoreCalculator.scoreHistory(
                for: habit,
                completions: habitCompletions,
                from: firstDay,
                to: lastDay
            )
            let scoreByDay = Dictionary(
                uniqueKeysWithValues: history.map { ($0.date, $0.score) }
            )
            let habitCreatedStart = calendar.startOfDay(for: habit.createdAt)

            let cells = days.map { day -> DayCell in
                if day > todayStart { return .future }
                if day < habitCreatedStart { return .notDue }
                if !frequencyEvaluator.isDue(
                    habit: habit,
                    on: day,
                    completions: habitCompletions
                ) {
                    return .notDue
                }
                return .scored(scoreByDay[day] ?? 0.0)
            }
            return MatrixRow(habit: habit, days: cells)
        }
    }
}
