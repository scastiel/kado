import Foundation

public struct DefaultHabitScoreCalculator: HabitScoreCalculating {
    public let alpha: Double
    public let calendar: Calendar
    public let frequencyEvaluator: any FrequencyEvaluating

    public init(
        alpha: Double = 0.05,
        calendar: Calendar = .current,
        frequencyEvaluator: (any FrequencyEvaluating)? = nil
    ) {
        self.alpha = alpha
        self.calendar = calendar
        self.frequencyEvaluator = frequencyEvaluator
            ?? DefaultFrequencyEvaluator(calendar: calendar)
    }

    public func currentScore(
        for habit: Habit,
        completions: [Completion],
        asOf date: Date
    ) -> Double {
        let start = habit.effectiveStart(completions: completions, calendar: calendar)
        let history = scoreHistory(
            for: habit,
            completions: completions,
            from: start,
            to: date
        )
        return history.last?.score ?? 0.0
    }

    public func scoreHistory(
        for habit: Habit,
        completions: [Completion],
        from startDate: Date,
        to endDate: Date
    ) -> [DailyScore] {
        let effectiveStartDay = calendar.startOfDay(
            for: habit.effectiveStart(completions: completions, calendar: calendar)
        )
        let firstDay = max(calendar.startOfDay(for: startDate), effectiveStartDay)
        let lastDay = calendar.startOfDay(for: endDate)
        guard firstDay <= lastDay else { return [] }

        let completionsByDay = completionsForHabitGrouped(by: habit, completions: completions)

        var score = 0.0
        var result: [DailyScore] = []
        var day = firstDay
        while day <= lastDay {
            if frequencyEvaluator.isDue(habit: habit, on: day, completions: completions) {
                let value = DailyValue.compute(
                    for: habit,
                    completionsOnDay: completionsByDay[day] ?? []
                )
                score = (1 - alpha) * score + alpha * value
            }
            result.append(DailyScore(date: day, score: score))
            day = calendar.date(byAdding: .day, value: 1, to: day)!
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
}
