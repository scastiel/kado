import Foundation

/// Answers the two questions a habit's schedule can be asked about a
/// given calendar day. Both respect the habit's lifecycle
/// (`createdAt` / `archivedAt`) and, for flexible schedules like
/// `.daysPerWeek`, its recent completion history.
///
/// The two differ **only** for `.daysPerWeek`. `.daily` and
/// `.specificDays` ignore completions outright; `.everyNDays` reads
/// only the ones *strictly before* the day it is asked about, because
/// its cycle restarts from the last day the habit was done (see
/// `EveryNDaysCycle`). So all three answer both questions identically.
///
/// Keeping them apart matters: collapsing them into a single `isDue`
/// is what let a completed day render as "not scheduled" in the
/// Overview grid, and froze the habit score of a user who met their
/// weekly target every week (issue #57).
public protocol FrequencyEvaluating: Sendable {
    /// Did the schedule ask for this habit on `date`?
    ///
    /// **Monotonic in `date` itself**: what is logged *on* `date` never
    /// changes the answer. Performing a habit must not retroactively
    /// decide that same day was never required — otherwise back-filling
    /// a day makes it disappear from the grid, and hitting a weekly
    /// target stops the score from advancing.
    ///
    /// It is **not** monotonic in days that follow, and deliberately so
    /// for the two completion-driven schedules. Back-filling day 1 of
    /// an `.everyNDays(2)` habit re-anchors its cycle and turns day 2
    /// from due into not-due, clearing the miss that day 2 had been
    /// carrying; `.daysPerWeek` shifts its rolling window the same way.
    /// That is the point of both — a schedule that answers "was this
    /// asked for?" from history has to be allowed to change its mind
    /// when the history changes.
    ///
    /// For `.daysPerWeek(n)`, counts completions over the six days
    /// *before* `date` and reports whether the quota still had room.
    ///
    /// For `.everyNDays(n)`, measures the interval from the last day
    /// the habit was done before `date`, falling back to its creation
    /// day. Only a completion re-anchors the cycle, so a skipped due
    /// day stays a miss.
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
    /// Should `date`'s outcome feed the habit's score and streak?
    ///
    /// `isDue` for every schedule except `.everyNDays`, which also
    /// counts a day the user did the habit on anyway.
    ///
    /// That exception is load-bearing rather than generous. An
    /// `.everyNDays` cycle re-anchors on each completion, so working
    /// ahead *removes* due days: a habit on an every-2-days cadence
    /// done every single day is never due after its first day. Measured
    /// on due days alone its score would sit near zero and its streak
    /// at 1 for flawless adherence — strictly worse than doing less
    /// work. Counting the days actually done restores the monotonicity
    /// that matters to a user: more work never scores worse.
    ///
    /// A fixed schedule keeps the opposite rule. Running on a Tuesday
    /// is not part of a Monday-only habit, and `.daysPerWeek` already
    /// expresses "extra is fine" through its rolling quota.
    public func isCounted(
        habit: Habit,
        on date: Date,
        completions: [Completion],
        calendar: Calendar
    ) -> Bool {
        guard case .everyNDays = habit.frequency else {
            return isDue(habit: habit, on: date, completions: completions)
        }
        return isDueOrLogged(
            habit: habit,
            on: date,
            completions: completions,
            calendar: calendar
        )
    }

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
