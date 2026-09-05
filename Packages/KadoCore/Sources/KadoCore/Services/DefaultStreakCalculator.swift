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
        let cycleAnchors = EveryNDaysCycle.anchorCandidates(for: habit, completedDays: completedDays)
        let createdDay = calendar.startOfDay(for: habit.createdAt)
        let countsLogged = countsLoggedDays(habit: habit)
        var streak = 0
        var day = end
        var isEndDay = true

        while day >= startDay {
            let due = isDueByDay(
                habit: habit, on: day, cycleAnchors: cycleAnchors, createdDay: createdDay
            )
            if !due && !(countsLogged && completedDays.contains(day)) {
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
        let cycleAnchors = EveryNDaysCycle.anchorCandidates(for: habit, completedDays: completedDays)
        let createdDay = calendar.startOfDay(for: habit.createdAt)
        let countsLogged = countsLoggedDays(habit: habit)
        var best = 0
        var run = 0
        var day = startDay

        while day <= end {
            let due = isDueByDay(
                habit: habit, on: day, cycleAnchors: cycleAnchors, createdDay: createdDay
            )
            if !due && !(countsLogged && completedDays.contains(day)) {
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

    /// Deliberately **not** delegated to the shared
    /// `FrequencyEvaluating`, unlike `MonthlyCalendarView`.
    ///
    /// Two reasons. Performance: `DefaultFrequencyEvaluator` recomputes
    /// `habit.effectiveStart(completions:)` — a filter + map + min over
    /// every completion — on each call, and the callers below walk one
    /// day at a time across the habit's whole lifetime. That turns an
    /// O(1) check into O(completions) per day, on the main thread, for
    /// a value `HabitDetailView` reads from a computed property and
    /// `WidgetSnapshotBuilder` recomputes on every mutation. The
    /// `.everyNDays` anchor has the same shape — the evaluator rescans
    /// every completion per day, where the walkers below hoist the
    /// sorted anchors once and binary-search them.
    /// Correctness: the explicit `.daysPerWeek` case keeps the
    /// "week-bucket path handles this frequency" invariant enforced
    /// where it is used, rather than relying on both callers switching
    /// first. The rolling-quota answer would silently mix weekly
    /// semantics into a per-day streak walk.
    ///
    /// The lifecycle guards the evaluator applies (`effectiveStart`,
    /// `archivedAt`) are already enforced by the callers' loop bounds.
    private func isDueByDay(
        habit: Habit,
        on day: Date,
        cycleAnchors: [Date],
        createdDay: Date
    ) -> Bool {
        switch habit.frequency {
        case .daily:
            return true
        case .specificDays(let weekdays):
            let weekdayInt = calendar.component(.weekday, from: day)
            guard let weekday = Weekday(rawValue: weekdayInt) else { return false }
            return weekdays.contains(weekday)
        case .everyNDays(let n):
            // The cycle restarts from the last day the habit was
            // done, so an early completion moves the next due day
            // instead of leaving a phantom miss behind. `cycleAnchors`
            // is hoisted out of the caller's day-by-day walk to keep
            // this a binary search rather than a scan per day.
            guard n > 0 else { return false }
            return EveryNDaysCycle.isDue(
                interval: n,
                on: day,
                anchoredAt: EveryNDaysCycle.anchorDay(
                    before: day,
                    in: cycleAnchors,
                    fallback: createdDay
                ),
                calendar: calendar
            )
        case .daysPerWeek:
            return false
        }
    }

    /// Whether a day the user logged counts toward the streak even when
    /// the schedule didn't ask for it.
    ///
    /// Only `.everyNDays`, and only because its cycle re-anchors on
    /// completion: working ahead removes due days, so a habit done
    /// every day on an every-2-days cadence would otherwise report a
    /// streak of 1. Mirrors `FrequencyEvaluating.isCounted`, which the
    /// score uses for the same reason.
    ///
    /// Never for `.negative`, where `completedDaySet` holds the days
    /// the user *slipped* — counting those would credit the slip.
    private func countsLoggedDays(habit: Habit) -> Bool {
        guard case .everyNDays = habit.frequency else { return false }
        return EveryNDaysCycle.canReanchor(habit)
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
