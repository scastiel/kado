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

    /// How this cell should be drawn: one row of the grid is a single
    /// hue at four intensities, so rows stay comparable at a glance.
    ///
    /// Replaces a continuous `0.2...1.0` opacity ramp. A smooth ramp
    /// encodes more than the eye can read back off a 30pt tile, and
    /// its 0.2 floor forced missed days to be drawn in the habit's own
    /// hue — which made a missed day and a barely-started day the same
    /// picture. Discrete steps, plus a *neutral* fill for a missed day,
    /// separate the two states that actually matter.
    public var appearance: CellAppearance {
        switch self {
        case .future:
            return .empty
        case .notDue:
            return .notScheduled
        case .scored(let value):
            guard value > 0 else { return .missed }
            if value >= 1 { return .hue(opacity: 1, ringed: false) }
            if value >= 0.5 { return .hue(opacity: KadoTint.tilePartial, ringed: false) }
            return .hue(opacity: KadoTint.tileLight, ringed: false)
        case .offSchedule:
            // Deliberately flat rather than tiered. The ring is the
            // only thing saying "you logged this on a day nothing was
            // asked of you", and a full-hue fill under a full-hue ring
            // is invisible — so the interior stays pale at every value
            // and the ring carries the signal. The exact value is a tap
            // away in the cell popover.
            return .hue(opacity: KadoTint.tileLight, ringed: true)
        }
    }
}

/// The drawn form of one Overview tile. Pure presentation, resolved
/// from ``DayCell`` — kept as its own type so the ramp can be asserted
/// in tests without rendering a view.
public enum CellAppearance: Equatable, Sendable {
    /// Beyond today. Nothing is drawn at all.
    case empty
    /// The schedule asked and nothing was logged. Neutral fill.
    case missed
    /// The schedule never asked. A ring, not a fill — so it can't be
    /// mistaken for a day that was missed.
    case notScheduled
    /// The habit's hue at `opacity`. `ringed` marks a day logged
    /// outside the schedule.
    case hue(opacity: Double, ringed: Bool)
}

/// How much of the visible window the user actually logged —
/// the number behind Overview's "34 of 47 scheduled days logged".
public struct OverviewSummary: Equatable, Sendable {
    /// Scheduled days in the window that carry any progress.
    public let loggedDays: Int
    /// Days the schedule asked for, across every habit in the window.
    public let scheduledDays: Int

    public init(loggedDays: Int, scheduledDays: Int) {
        self.loggedDays = loggedDays
        self.scheduledDays = scheduledDays
    }
}

/// Turns habits + completions + a day range into matrix rows.
/// Stateless; the View computes a fresh matrix per render.
public enum OverviewMatrix {

    /// Aggregates the trailing `lastDays` columns of `rows`.
    ///
    /// Counts **scheduled days only**: `.notDue` and `.future` are not
    /// days the user was asked for, and `.offSchedule` is credit for a
    /// day the schedule never claimed — including any of them would
    /// make the denominator meaningless. A bonus run therefore doesn't
    /// improve the ratio, which is the right trade: the line measures
    /// adherence to the schedule, not total effort.
    public static func summary(for rows: [MatrixRow], lastDays: Int) -> OverviewSummary {
        var logged = 0
        var scheduled = 0
        for row in rows {
            for cell in row.days.suffix(max(lastDays, 0)) {
                guard case .scored(let value) = cell else { continue }
                scheduled += 1
                if value > 0 { logged += 1 }
            }
        }
        return OverviewSummary(loggedDays: logged, scheduledDays: scheduled)
    }
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
