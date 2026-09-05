import Foundation

/// When will the schedule next ask for this habit?
///
/// Today's "not scheduled today" section answers that on every row —
/// a habit sitting there with no date reads as dormant rather than as
/// waiting. There is no closed form that covers all four frequencies
/// (`.daysPerWeek` and `.everyNDays` both answer from completion
/// history), so this walks forward a day at a time and asks the
/// evaluator, which keeps the one definition of "due" in one place.
public enum NextDueDate {

    /// How far ahead to look before giving up. A habit on
    /// `.everyNDays(30)` done today is 30 days out, and
    /// `.specificDays` is at most 7 — so anything past this horizon is
    /// a schedule no reasonable UI should be putting a date on.
    public static let horizonDays = 60

    /// The first day strictly after `date` that the schedule asks for,
    /// or `nil` if none falls inside ``horizonDays``.
    ///
    /// Walks days rather than seconds: a `Calendar` day is 23 or 25
    /// hours twice a year, and stepping by 86 400 would drift past a
    /// DST boundary and skip or repeat a day.
    public static func next(
        for habit: Habit,
        after date: Date,
        completions: [Completion],
        calendar: Calendar,
        evaluator: any FrequencyEvaluating,
        horizonDays: Int = horizonDays
    ) -> Date? {
        guard habit.archivedAt == nil else { return nil }
        let start = calendar.startOfDay(for: date)
        for offset in 1...max(horizonDays, 1) {
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else {
                return nil
            }
            if evaluator.isDue(habit: habit, on: day, completions: completions) {
                return day
            }
        }
        return nil
    }
}
