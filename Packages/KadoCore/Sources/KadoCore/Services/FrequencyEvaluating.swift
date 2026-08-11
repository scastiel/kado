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
