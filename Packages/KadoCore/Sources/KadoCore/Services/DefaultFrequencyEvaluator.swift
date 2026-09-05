import Foundation

public struct DefaultFrequencyEvaluator: FrequencyEvaluating {
    public let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public func isDue(habit: Habit, on date: Date, completions: [Completion]) -> Bool {
        evaluate(habit: habit, on: date, completions: completions, countingOwnDay: false)
    }

    public func isOutstanding(habit: Habit, on date: Date, completions: [Completion]) -> Bool {
        evaluate(habit: habit, on: date, completions: completions, countingOwnDay: true)
    }

    /// Shared body for both questions. `countingOwnDay` is the only
    /// difference, and it only reaches `.daysPerWeek` — every other
    /// frequency ignores `completions` outright.
    private func evaluate(
        habit: Habit,
        on date: Date,
        completions: [Completion],
        countingOwnDay: Bool
    ) -> Bool {
        let day = calendar.startOfDay(for: date)
        let effectiveStartDay = calendar.startOfDay(
            for: habit.effectiveStart(completions: completions, calendar: calendar)
        )
        guard day >= effectiveStartDay else { return false }
        if let archivedAt = habit.archivedAt {
            let archivedDay = calendar.startOfDay(for: archivedAt)
            guard day <= archivedDay else { return false }
        }

        switch habit.frequency {
        case .daily:
            return true

        case .specificDays(let weekdays):
            let weekdayInt = calendar.component(.weekday, from: day)
            guard let weekday = Weekday(rawValue: weekdayInt) else { return false }
            return weekdays.contains(weekday)

        case .everyNDays(let n):
            // Anchored to the last day the habit was done, not to a
            // fixed grid from `createdAt` — doing it early restarts
            // the clock. Only completions strictly before `day` are
            // read, so this stays monotonic and `isDue` /
            // `isOutstanding` still agree. See `EveryNDaysCycle`.
            return EveryNDaysCycle.isDue(
                interval: n,
                on: day,
                anchoredAt: EveryNDaysCycle.anchorDay(
                    for: habit,
                    before: day,
                    completions: completions,
                    calendar: calendar
                ),
                calendar: calendar
            )

        case .daysPerWeek(let target):
            guard target > 0 else { return false }
            let windowStart = calendar.date(byAdding: .day, value: -6, to: day)!
            // `isDue` stops at the day before, so the answer can't be
            // rewritten by logging the day itself. `isOutstanding`
            // includes it, because doing the work is precisely what
            // clears the rest of the week.
            let windowEnd = countingOwnDay
                ? day
                : calendar.date(byAdding: .day, value: -1, to: day)!

            let countInWindow = completions.reduce(into: 0) { count, completion in
                // `value > 0` matters: `CompletionToggler` leaves a
                // zeroed record behind when the day carries a note, and
                // an unchecked day is not a completion.
                guard completion.habitID == habit.id, completion.value > 0 else { return }
                let completionDay = calendar.startOfDay(for: completion.date)
                if completionDay >= windowStart && completionDay <= windowEnd {
                    count += 1
                }
            }
            return countInWindow < target
        }
    }
}
