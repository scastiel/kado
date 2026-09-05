import Foundation

/// Cycle math for `.everyNDays(n)`.
///
/// The interval is measured from the last day the habit was **actually
/// done**, not from a fixed grid pinned to `createdAt`. Doing the habit
/// early restarts the clock, so an every-2-days habit completed Monday
/// and again Tuesday is next due Thursday — Wednesday was never asked
/// for and is not a miss.
///
/// The fixed-grid reading punished the user for being early: it kept
/// insisting on Wednesday, scored it as missed, and broke the streak of
/// someone who had just done the habit the day before.
///
/// Two properties this keeps:
///
/// - **Monotonic in the day itself.** Only completions *strictly
///   before* the day under test can move the anchor, so logging a day
///   never rewrites whether that same day was due. See the caveat on
///   `FrequencyEvaluating.isDue` about days *after* it.
/// - **A miss doesn't reschedule.** Only a completion re-anchors, so
///   skipping a due day leaves the cycle where it was and the day stays
///   a miss (offsets `anchor + n`, `anchor + 2n`, … as before).
///
/// Before the first completion the cycle is anchored to `createdAt`,
/// which is what makes a brand-new habit due on the day it was created.
///
/// **Working ahead removes due days**, which is why the score and the
/// streak measure a day that is due *or* done rather than due alone —
/// see `FrequencyEvaluating.isCounted`. Measured on due days only, a
/// habit done every single day on an every-2-days cadence is never due
/// after its first day and scores near zero for perfect adherence.
public enum EveryNDaysCycle {

    /// Does the `interval`-day cycle running from `anchorDay` land on
    /// `day`? Days before the anchor are answered on the same modular
    /// grid, which is what lets a backdated completion sit on-cycle.
    public static func isDue(
        interval: Int,
        on day: Date,
        anchoredAt anchorDay: Date,
        calendar: Calendar
    ) -> Bool {
        guard interval > 0 else { return false }
        let delta = calendar.dateComponents([.day], from: anchorDay, to: day).day ?? 0
        return ((delta % interval) + interval) % interval == 0
    }

    /// Is `completion` work that re-anchors `habit`'s cycle?
    ///
    /// The single definition both anchor lookups below filter on. Two
    /// copies of a schedule rule drifting apart is what issue #57 was,
    /// and the linear and sorted paths here feed different callers —
    /// the streak walker versus the score, grid and calendar — so a
    /// divergence would render two different due-day sets for one
    /// habit.
    public static func isAnchor(_ completion: Completion, for habit: Habit) -> Bool {
        completion.habitID == habit.id && completion.value > 0 && canReanchor(habit)
    }

    /// The day the cycle restarts from when evaluating `day`: the most
    /// recent completed day strictly before it, or the habit's creation
    /// day when the habit has never been done before then.
    ///
    /// Scans `completions` once. Callers that walk a habit's whole
    /// lifetime a day at a time should hoist `anchorCandidates(for:…)`
    /// out of the loop and use the sorted overload instead.
    public static func anchorDay(
        for habit: Habit,
        before day: Date,
        completions: [Completion],
        calendar: Calendar
    ) -> Date {
        let createdDay = calendar.startOfDay(for: habit.createdAt)
        guard canReanchor(habit) else { return createdDay }

        var latest: Date?
        for completion in completions where isAnchor(completion, for: habit) {
            let completionDay = calendar.startOfDay(for: completion.date)
            guard completionDay < day else { continue }
            if latest == nil || completionDay > latest! { latest = completionDay }
        }
        return latest ?? createdDay
    }

    /// Same answer as `anchorDay(for:before:completions:calendar:)`,
    /// against a pre-built ascending list of completed days. `O(log n)`
    /// per day rather than `O(completions)`.
    public static func anchorDay(
        before day: Date,
        in sortedCompletedDays: [Date],
        fallback createdDay: Date
    ) -> Date {
        // Last element strictly less than `day`.
        var low = 0
        var high = sortedCompletedDays.count
        while low < high {
            let mid = low + (high - low) / 2
            if sortedCompletedDays[mid] < day {
                low = mid + 1
            } else {
                high = mid
            }
        }
        return low > 0 ? sortedCompletedDays[low - 1] : createdDay
    }

    /// The days that may re-anchor `habit`'s cycle, ascending and
    /// de-duplicated, ready for the sorted `anchorDay` overload.
    public static func anchorCandidates(
        for habit: Habit,
        completions: [Completion],
        calendar: Calendar
    ) -> [Date] {
        guard canReanchor(habit) else { return [] }
        let days = Set(
            completions
                .lazy
                .filter { isAnchor($0, for: habit) }
                .map { calendar.startOfDay(for: $0.date) }
        )
        return days.sorted()
    }

    /// Same, for a caller that has already reduced the habit's
    /// completions to a set of day-start `Date`s — which is exactly
    /// what the streak walkers build for their completed-day lookup.
    /// Rebuilding it from `[Completion]` would repeat that whole
    /// filter + map + `startOfDay` pass.
    public static func anchorCandidates(
        for habit: Habit,
        completedDays: Set<Date>
    ) -> [Date] {
        guard canReanchor(habit) else { return [] }
        return completedDays.sorted()
    }

    /// Whether a record on this habit represents work that moves the
    /// cycle. False for `.negative`, where a record means the user
    /// *broke* the habit — a slip must not push the next check-in out.
    /// `Habit.effectiveStart` draws the same line.
    public static func canReanchor(_ habit: Habit) -> Bool {
        if case .negative = habit.type { return false }
        return true
    }
}
