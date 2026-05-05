import Foundation

/// One row of the Overview matrix: a habit plus its per-day cells.
public struct MatrixRow: Equatable, Sendable {
    public let habit: Habit
    public let days: [DayCell]

    public init(habit: Habit, days: [DayCell]) {
        self.habit = habit
        self.days = days
    }
}

/// Per-day state for the matrix. `.scored` carries the day's raw
/// completion value (0...1); `.notDue` covers pre-creation and
/// off-schedule days; `.future` is used for dates beyond today.
///
/// The value is intentionally NOT the EMA habit score. Daily habits
/// with partial completion would render as a uniform mid-tone under
/// EMA smoothing, hiding the per-day "did I do it?" pattern the user
/// expects to see. See `DailyValue` for the mapping.
public enum DayCell: Equatable, Sendable {
    case future
    case notDue
    case scored(Double)

    /// Opacity used to tint the habit color when rendering this cell.
    /// `nil` for non-scored cells (caller renders a neutral
    /// placeholder).
    ///
    /// Linear remap from `[0, 1]` value to `[0.2, 1.0]` opacity.
    /// The 0.2 floor keeps value-0 cells clearly colored — otherwise
    /// missed-due cells visually collapse into the gray of `.notDue`
    /// neighbors, losing the "scheduled but missed" signal.
    public var colorOpacity: Double? {
        switch self {
        case .future, .notDue:
            return nil
        case .scored(let s):
            let clamped = max(0.0, min(1.0, s))
            return 0.2 + 0.8 * clamped
        }
    }
}

/// Turns habits + completions + a day range into matrix rows.
/// Stateless; the View computes a fresh matrix per render.
public enum OverviewMatrix {
    public static func compute(
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
            .sorted { $0.sortOrder < $1.sortOrder }

        return activeHabits.map { habit in
            let habitCompletions = completions.filter { $0.habitID == habit.id }
            let completionsByDay = Dictionary(grouping: habitCompletions) {
                calendar.startOfDay(for: $0.date)
            }
            let effectiveStartDay = calendar.startOfDay(
                for: habit.effectiveStart(completions: habitCompletions, calendar: calendar)
            )

            let cells = days.map { day -> DayCell in
                if day > todayStart { return .future }
                if day < effectiveStartDay { return .notDue }
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
