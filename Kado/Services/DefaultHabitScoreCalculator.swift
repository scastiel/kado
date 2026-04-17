import Foundation

struct DefaultHabitScoreCalculator: HabitScoreCalculating {
    let alpha: Double
    let calendar: Calendar
    let frequencyEvaluator: any FrequencyEvaluating

    init(
        alpha: Double = 0.05,
        calendar: Calendar = .current,
        frequencyEvaluator: (any FrequencyEvaluating)? = nil
    ) {
        self.alpha = alpha
        self.calendar = calendar
        self.frequencyEvaluator = frequencyEvaluator
            ?? DefaultFrequencyEvaluator(calendar: calendar)
    }

    func currentScore(
        for habit: Habit,
        completions: [Completion],
        asOf date: Date
    ) -> Double {
        let history = scoreHistory(
            for: habit,
            completions: completions,
            from: habit.createdAt,
            to: date
        )
        return history.last?.score ?? 0.0
    }

    func scoreHistory(
        for habit: Habit,
        completions: [Completion],
        from startDate: Date,
        to endDate: Date
    ) -> [DailyScore] {
        let createdDay = calendar.startOfDay(for: habit.createdAt)
        let firstDay = max(calendar.startOfDay(for: startDate), createdDay)
        let lastDay = calendar.startOfDay(for: endDate)
        guard firstDay <= lastDay else { return [] }

        let completionsByDay = completionsForHabitGrouped(by: habit, completions: completions)

        var score = 0.0
        var result: [DailyScore] = []
        var day = firstDay
        while day <= lastDay {
            if frequencyEvaluator.isDue(habit: habit, on: day, completions: completions) {
                let value = derivedValue(for: habit, completionsOnDay: completionsByDay[day] ?? [])
                score = (1 - alpha) * score + alpha * value
            }
            result.append(DailyScore(date: day, score: score))
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return result
    }

    private func completionsForHabitGrouped(
        by habit: Habit,
        completions: [Completion]
    ) -> [Date: [Completion]] {
        Dictionary(grouping: completions.filter { $0.habitID == habit.id }) {
            calendar.startOfDay(for: $0.date)
        }
    }

    private func derivedValue(for habit: Habit, completionsOnDay: [Completion]) -> Double {
        switch habit.type {
        case .binary:
            return completionsOnDay.isEmpty ? 0.0 : 1.0
        case .counter(let target):
            guard target > 0 else { return 0.0 }
            let achieved = completionsOnDay.reduce(0.0) { $0 + $1.value }
            return min(1.0, achieved / target)
        case .timer(let targetSeconds):
            guard targetSeconds > 0 else { return 0.0 }
            let achievedSeconds = completionsOnDay.reduce(0.0) { $0 + $1.value }
            return min(1.0, achievedSeconds / targetSeconds)
        case .negative:
            return completionsOnDay.isEmpty ? 1.0 : 0.0
        }
    }
}
