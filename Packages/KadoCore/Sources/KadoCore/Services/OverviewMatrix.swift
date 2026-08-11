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
/// completion value (0...1) for a day the schedule asked for;
/// `.offSchedule` carries the same value for a day it didn't;
/// `.notDue` covers pre-creation and unlogged off-schedule days;
/// `.future` is used for dates beyond today.
///
/// The value is intentionally NOT the EMA habit score. Daily habits
/// with partial completion would render as a uniform mid-tone under
/// EMA smoothing, hiding the per-day "did I do it?" pattern the user
/// expects to see. See `DailyValue` for the mapping.
public enum DayCell: Equatable, Sendable {
    case future
    case notDue
    case scored(Double)
    /// The user logged something on a day the schedule didn't ask
    /// for — a bonus run past a weekly quota, or a back-filled day.
    /// Kept distinct from `.scored` so the grid can still show the
    /// shape of the schedule instead of flattening it (issue #57).
    case offSchedule(Double)

    /// Opacity used to tint the habit color when rendering this cell.
    /// `nil` for cells with no value (caller renders a neutral
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
        case .scored(let s), .offSchedule(let s):
            let clamped = max(0.0, min(1.0, s))
            return 0.2 + 0.8 * clamped
        }
    }

    /// Opacity for the border that marks an off-schedule cell. `nil`
    /// for every other case.
    ///
    /// Floored at 0.6 rather than reusing `colorOpacity`. The border
    /// is the *only* thing saying "you logged this", and scaling it
    /// by the day's value would undo the whole point for low values:
    /// a negative habit's off-schedule slip is `.offSchedule(0.0)`,
    /// which at `colorOpacity` would draw at 0.2 — fainter than the
    /// neutral `.notDue` fill beside it. A logged day must never read
    /// quieter than an empty one. The pale interior still carries the
    /// value.
    public var borderOpacity: Double? {
        guard case .offSchedule(let s) = self else { return nil }
        let clamped = max(0.0, min(1.0, s))
        return 0.6 + 0.4 * clamped
    }

    /// Interior tint for an off-schedule cell — deliberately faint so
    /// the border carries the signal.
    public var offScheduleFillOpacity: Double? {
        guard case .offSchedule = self else { return nil }
        return (colorOpacity ?? 0) * 0.25
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

                let completionsOnDay = completionsByDay[day] ?? []
                if frequencyEvaluator.isDue(
                    habit: habit,
                    on: day,
                    completions: habitCompletions
                ) {
                    return .scored(
                        DailyValue.compute(for: habit, completionsOnDay: completionsOnDay)
                    )
                }
                // Off-schedule, but the user logged something anyway.
                // Resolving this *after* the schedule check is what
                // fixes issue #57: a recorded completion must never
                // render as "not scheduled".
                //
                // Presence of a record is the test, not `value` —
                // for a negative habit a record means a slip, which
                // maps to a value of 0.
                if completionsOnDay.contains(where: { $0.value > 0 }) {
                    return .offSchedule(
                        DailyValue.compute(for: habit, completionsOnDay: completionsOnDay)
                    )
                }
                // The common case for a sparse schedule — no value
                // computed, since nothing consumes it.
                return .notDue
            }
            return MatrixRow(habit: habit, days: cells)
        }
    }
}
