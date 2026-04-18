import Foundation

/// One row of the Overview matrix: a habit plus its per-day cells.
struct MatrixRow: Equatable, Sendable {
    let habit: Habit
    let days: [DayCell]
}

/// Per-day state for the matrix. `.scored` carries the day's raw
/// completion value (0...1); `.notDue` covers pre-creation and
/// off-schedule days; `.future` is used for dates beyond today.
///
/// The value is intentionally NOT the EMA habit score. Daily habits
/// with partial completion would render as a uniform mid-tone under
/// EMA smoothing, hiding the per-day "did I do it?" pattern the user
/// expects to see. See `DailyValue` for the mapping.
enum DayCell: Equatable, Sendable {
    case future
    case notDue
    case scored(Double)

    /// Opacity used to tint the habit color when rendering this cell.
    /// `nil` for non-scored cells (caller renders a neutral
    /// placeholder). The 0.08 floor keeps score-near-zero days
    /// perceptible against the cell background.
    var colorOpacity: Double? {
        switch self {
        case .future, .notDue: nil
        case .scored(let s): max(0.08, min(1.0, s))
        }
    }
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
        frequencyEvaluator: any FrequencyEvaluating
    ) -> [MatrixRow] {
        let todayStart = calendar.startOfDay(for: today)
        let activeHabits = habits
            .filter { $0.archivedAt == nil }
            .sorted { $0.createdAt < $1.createdAt }

        return activeHabits.map { habit in
            let habitCompletions = completions.filter { $0.habitID == habit.id }
            let completionsByDay = Dictionary(grouping: habitCompletions) {
                calendar.startOfDay(for: $0.date)
            }
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
                let value = DailyValue.compute(
                    for: habit,
                    completionsOnDay: completionsByDay[day] ?? []
                )
                return .scored(value)
            }
            return MatrixRow(habit: habit, days: cells)
        }
    }
}
