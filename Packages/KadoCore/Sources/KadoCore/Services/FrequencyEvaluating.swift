import Foundation

/// Answers the two questions a habit's schedule can be asked about a
/// given calendar day. Both respect the habit's lifecycle
/// (`createdAt` / `archivedAt`) and, for flexible schedules like
/// `.daysPerWeek`, its recent completion history.
///
/// The two differ **only** for `.daysPerWeek`. Fixed schedules
/// (`.daily`, `.specificDays`, `.everyNDays`) ignore completions
/// entirely, so they answer both identically.
///
/// Keeping them apart matters: collapsing them into a single `isDue`
/// is what let a completed day render as "not scheduled" in the
/// Overview grid, and froze the habit score of a user who met their
/// weekly target every week (issue #57).
public protocol FrequencyEvaluating: Sendable {
    /// Did the schedule ask for this habit on `date`?
    ///
    /// **Monotonic**: what is logged *on* `date` never changes the
    /// answer. Performing a habit must not retroactively decide the
    /// day was never required — otherwise back-filling a day makes it
    /// disappear from the grid, and hitting a weekly target stops the
    /// score from advancing.
    ///
    /// For `.daysPerWeek(n)`, counts completions over the six days
    /// *before* `date` and reports whether the quota still had room.
    ///
    /// This is the right question for anything retrospective:
    /// rendering a grid or calendar, scoring, sectioning a list.
    func isDue(habit: Habit, on date: Date, completions: [Completion]) -> Bool

    /// Does this habit still need doing on `date`, counting what has
    /// already been logged on `date` itself?
    ///
    /// Deliberately **not** monotonic — logging the fifth run of a
    /// five-per-week target is exactly what should silence the rest
    /// of the week.
    ///
    /// This is the right question for anything prospective: reminder
    /// scheduling, "what's left today".
    func isOutstanding(habit: Habit, on date: Date, completions: [Completion]) -> Bool
}

extension FrequencyEvaluating {
    /// Should this habit appear in a Today-style list on `date`? The
    /// schedule asks for it, or the user logged real progress on it
    /// that day anyway — so a habit doesn't vanish the moment a
    /// rolling weekly quota saturates.
    ///
    /// Lives on the protocol rather than being written out at each
    /// call site: the Today tab and the widget snapshot both need it,
    /// and a second copy of a schedule rule is exactly what let the
    /// grid and the calendar drift apart in issue #57.
    ///
    /// `.negative` habits are excluded from the second arm. A record
    /// on a negative habit means the user *broke* it, so a slip on a
    /// day the schedule never covered is not a reason to surface the
    /// row — and `HabitRowState` would resolve that row to
    /// `.complete`, crediting the user for the day they slipped.
    public func isDueOrLogged(
        habit: Habit,
        on date: Date,
        completions: [Completion],
        calendar: Calendar
    ) -> Bool {
        if isDue(habit: habit, on: date, completions: completions) { return true }
        if case .negative = habit.type { return false }
        return completions.contains { completion in
            completion.habitID == habit.id
                && completion.value > 0
                && calendar.isDate(completion.date, inSameDayAs: date)
        }
    }
}
