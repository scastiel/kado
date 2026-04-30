import Foundation

public struct DefaultStreakCalculator: StreakCalculating {
    public let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public func current(for habit: Habit, completions: [Completion], asOf date: Date) -> Int {
        let endDate = habit.archivedAt ?? date
        let end = calendar.startOfDay(for: endDate)
        let startDay = calendar.startOfDay(
            for: habit.effectiveStart(completions: completions, calendar: calendar)
        )
        guard end >= startDay else { return 0 }

        switch habit.frequency {
        case .daysPerWeek(let target):
            return currentDaysPerWeek(target: target, habit: habit, completions: completions, end: end, startDay: startDay)
        default:
            return currentByDay(habit: habit, completions: completions, end: end, startDay: startDay)
        }
    }

    public func best(for habit: Habit, completions: [Completion], asOf date: Date) -> Int {
        let endDate = habit.archivedAt ?? date
        let end = calendar.startOfDay(for: endDate)
        let startDay = calendar.startOfDay(
            for: habit.effectiveStart(completions: completions, calendar: calendar)
        )
        guard end >= startDay else { return 0 }

        switch habit.frequency {
        case .daysPerWeek(let target):
            return bestDaysPerWeek(target: target, habit: habit, completions: completions, end: end, startDay: startDay)
        default:
            return bestByDay(habit: habit, completions: completions, end: end, startDay: startDay)
        }
    }

    // MARK: - Per-day (daily / specificDays / everyNDays / negative)

    private func currentByDay(
        habit: Habit,
        completions: [Completion],
        end: Date,
        startDay: Date
    ) -> Int {
        let completedDays = completedDaySet(habit: habit, completions: completions)
        var streak = 0
        var day = end
        var isEndDay = true

        while day >= startDay {
            let due = isDueByDay(habit: habit, on: day)
            if !due {
                day = previousDay(day)
                isEndDay = false
                continue
            }

            let completed = isCompletedByDay(habit: habit, on: day, completedDays: completedDays)
            if completed {
                streak += 1
            } else if isEndDay {
                // Grace day — don't count, don't break.
            } else {
                break
            }
            day = previousDay(day)
            isEndDay = false
        }
        return streak
    }

    private func bestByDay(
        habit: Habit,
        completions: [Completion],
        end: Date,
        startDay: Date
    ) -> Int {
        let completedDays = completedDaySet(habit: habit, completions: completions)
        var best = 0
        var run = 0
        var day = startDay

        while day <= end {
            let due = isDueByDay(habit: habit, on: day)
            if !due {
                day = nextDay(day)
                continue
            }

            let completed = isCompletedByDay(habit: habit, on: day, completedDays: completedDays)
            let isEndDay = calendar.isDate(day, inSameDayAs: end)
            if completed {
                run += 1
                best = max(best, run)
            } else if isEndDay {
                // End-day grace: don't reset the run, but don't increment.
            } else {
                run = 0
            }
            day = nextDay(day)
        }
        return best
    }

    // MARK: - Days-per-week

    private func currentDaysPerWeek(
        target: Int,
        habit: Habit,
        completions: [Completion],
        end: Date,
        startDay: Date
    ) -> Int {
        guard target > 0 else { return 0 }
        let filtered = completions.filter { $0.habitID == habit.id }
        guard let endWeek = calendar.dateInterval(of: .weekOfYear, for: end) else { return 0 }

        var streak = 0

        // Current week: grace. Counts +1 as "streak ends in the current week,"
        // regardless of how many completions have landed.
        streak += 1

        var weekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: endWeek.start)!

        while weekStart >= startDay ||
              calendar.dateInterval(of: .weekOfYear, for: startDay)!.start == weekStart {
            let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart)!
            let count = completionsInRange(filtered, from: weekStart, through: weekEnd)
            if count >= target {
                streak += 1
            } else {
                break
            }
            weekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: weekStart)!
        }
        return streak
    }

    private func bestDaysPerWeek(
        target: Int,
        habit: Habit,
        completions: [Completion],
        end: Date,
        startDay: Date
    ) -> Int {
        guard target > 0 else { return 0 }
        let filtered = completions.filter { $0.habitID == habit.id }
        guard let startWeek = calendar.dateInterval(of: .weekOfYear, for: startDay),
              let endWeek = calendar.dateInterval(of: .weekOfYear, for: end) else { return 0 }

        var best = 0
        var run = 0
        var weekStart = startWeek.start

        while weekStart <= endWeek.start {
            let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart)!
            let isEndWeek = calendar.isDate(weekStart, inSameDayAs: endWeek.start)
            let count = completionsInRange(filtered, from: weekStart, through: weekEnd)
            let qualifies = count >= target
            let graceCarries = isEndWeek && !qualifies
            if qualifies {
                run += 1
                best = max(best, run)
            } else if graceCarries {
                // Don't reset: current week is grace.
            } else {
                run = 0
            }
            weekStart = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart)!
        }
        return best
    }

    // MARK: - Day helpers

    private func previousDay(_ day: Date) -> Date {
        calendar.date(byAdding: .day, value: -1, to: day)!
    }

    private func nextDay(_ day: Date) -> Date {
        calendar.date(byAdding: .day, value: 1, to: day)!
    }

    private func isDueByDay(habit: Habit, on day: Date) -> Bool {
        switch habit.frequency {
        case .daily:
            return true
        case .specificDays(let weekdays):
            let weekdayInt = calendar.component(.weekday, from: day)
            guard let weekday = Weekday(rawValue: weekdayInt) else { return false }
            return weekdays.contains(weekday)
        case .everyNDays(let n):
            guard n > 0 else { return false }
            let createdDay = calendar.startOfDay(for: habit.createdAt)
            let delta = calendar.dateComponents([.day], from: createdDay, to: day).day ?? 0
            return ((delta % n) + n) % n == 0
        case .daysPerWeek:
            return false
        }
    }

    private func completedDaySet(habit: Habit, completions: [Completion]) -> Set<Date> {
        Set(
            completions
                .filter { $0.habitID == habit.id && $0.value > 0 }
                .map { calendar.startOfDay(for: $0.date) }
        )
    }

    private func isCompletedByDay(habit: Habit, on day: Date, completedDays: Set<Date>) -> Bool {
        let hasCompletion = completedDays.contains(day)
        switch habit.type {
        case .negative:
            return !hasCompletion
        case .binary, .counter, .timer:
            return hasCompletion
        }
    }

    private func completionsInRange(_ completions: [Completion], from start: Date, through end: Date) -> Int {
        completions.reduce(into: 0) { count, completion in
            let day = calendar.startOfDay(for: completion.date)
            if day >= start && day <= end && completion.value > 0 {
                count += 1
            }
        }
    }
}
