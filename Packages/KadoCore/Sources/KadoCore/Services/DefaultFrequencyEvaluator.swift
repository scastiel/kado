import Foundation

public struct DefaultFrequencyEvaluator: FrequencyEvaluating {
    public let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public func isDue(habit: Habit, on date: Date, completions: [Completion]) -> Bool {
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
            guard n > 0 else { return false }
            let createdDay = calendar.startOfDay(for: habit.createdAt)
            let delta = calendar.dateComponents([.day], from: createdDay, to: day).day ?? 0
            return ((delta % n) + n) % n == 0

        case .daysPerWeek(let target):
            guard target > 0 else { return false }
            let windowStart = calendar.date(byAdding: .day, value: -6, to: day)!
            let countInWindow = completions.reduce(into: 0) { count, completion in
                guard completion.habitID == habit.id else { return }
                let completionDay = calendar.startOfDay(for: completion.date)
                if completionDay >= windowStart && completionDay <= day {
                    count += 1
                }
            }
            return countInWindow < target
        }
    }
}
