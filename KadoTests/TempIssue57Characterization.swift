import Testing
import Foundation
@testable import Kado
import KadoCore

/// TEMPORARY — characterization probe for issue #57. Deleted once the
/// real regression tests land. Every test here deliberately fails so
/// the actual values land in the test log.
@Suite("TEMP issue57 characterization")
struct TempIssue57Characterization {
    let calendar = TestCalendar.utc

    @Test("PROBE: overview vs calendar for an off-schedule completion")
    func probeOverviewDivergence() throws {
        // 5-per-week habit created 30 days ago.
        let habit = Habit(
            name: "Run",
            frequency: .daysPerWeek(5),
            type: .binary,
            createdAt: TestCalendar.day(-30)
        )
        // Completions on days -6, -5, -4, -3, -2 (five in the trailing
        // window ending today), then a back-filled one on day -1.
        var completions = [-6, -5, -4, -3, -2].map {
            Completion(habitID: habit.id, date: TestCalendar.day($0), value: 1)
        }
        completions.append(
            Completion(habitID: habit.id, date: TestCalendar.day(-1), value: 1)
        )

        let evaluator = DefaultFrequencyEvaluator(calendar: calendar)
        let days = (-8...0).map { calendar.startOfDay(for: TestCalendar.day($0)) }
        let rows = OverviewMatrix.compute(
            habits: [habit],
            completions: completions,
            days: days,
            today: TestCalendar.day(0),
            calendar: calendar,
            frequencyEvaluator: evaluator
        )
        let row = try #require(rows.first)
        let rendered = zip(-8...0, row.days).map { offset, cell -> String in
            let has = completions.contains {
                calendar.isDate($0.date, inSameDayAs: TestCalendar.day(offset))
            }
            return "d\(offset)\(has ? "*" : " ")=\(cell)"
        }
        Issue.record("MATRIX: \(rendered.joined(separator: " | "))")
    }

    @Test("PROBE: does a day's own completion flip it to not-due?")
    func probeSelfCancelling() {
        let habit = Habit(
            name: "Run",
            frequency: .daysPerWeek(5),
            type: .binary,
            createdAt: TestCalendar.day(-30)
        )
        let priorFour = [-6, -5, -4, -3].map {
            Completion(habitID: habit.id, date: TestCalendar.day($0), value: 1)
        }
        let evaluator = DefaultFrequencyEvaluator(calendar: calendar)
        let withoutToday = evaluator.isDue(
            habit: habit, on: TestCalendar.day(0), completions: priorFour
        )
        let withToday = evaluator.isDue(
            habit: habit,
            on: TestCalendar.day(0),
            completions: priorFour + [
                Completion(habitID: habit.id, date: TestCalendar.day(0), value: 1)
            ]
        )
        Issue.record("SELF-CANCEL: due(4 prior)=\(withoutToday) due(4 prior + today)=\(withToday)")
    }

    @Test("PROBE: score trajectory for a perfect 5-per-week user")
    func probeScoreFreeze() {
        let habit = Habit(
            name: "Run",
            frequency: .daysPerWeek(5),
            type: .binary,
            createdAt: TestCalendar.day(0)
        )
        // Mon..Fri every week for 6 weeks. Day 0 is a Monday.
        var completions: [Completion] = []
        for week in 0..<6 {
            for weekday in 0..<5 {
                completions.append(
                    Completion(
                        habitID: habit.id,
                        date: TestCalendar.day(week * 7 + weekday),
                        value: 1
                    )
                )
            }
        }
        let calc = DefaultHabitScoreCalculator(calendar: calendar)
        let score = calc.currentScore(
            for: habit, completions: completions, asOf: TestCalendar.day(41)
        )
        let dailyEquivalent = DefaultHabitScoreCalculator(calendar: calendar)
        let dailyHabit = Habit(
            name: "Run daily",
            frequency: .daily,
            type: .binary,
            createdAt: TestCalendar.day(0)
        )
        let dailyCompletions = (0...41).map {
            Completion(habitID: dailyHabit.id, date: TestCalendar.day($0), value: 1)
        }
        let dailyScore = dailyEquivalent.currentScore(
            for: dailyHabit, completions: dailyCompletions, asOf: TestCalendar.day(41)
        )
        Issue.record("SCORE: perfect 5/week after 6 weeks = \(score); perfect daily = \(dailyScore)")

        let history = calc.scoreHistory(
            for: habit,
            completions: completions,
            from: TestCalendar.day(0),
            to: TestCalendar.day(20)
        )
        let trail = history.map { String(format: "%.3f", $0.score) }.joined(separator: ",")
        Issue.record("SCORE TRAIL d0..d20: \(trail)")
    }

    @Test("PROBE: zero-value completion counted toward the weekly quota?")
    func probeZeroValueCounted() {
        let habit = Habit(
            name: "Run",
            frequency: .daysPerWeek(3),
            type: .binary,
            createdAt: TestCalendar.day(-30)
        )
        // Three same-day-window records, all "unchecked but noted"
        // (value 0) — the shape CompletionToggler leaves behind.
        let zeroed = [-3, -2, -1].map {
            Completion(
                habitID: habit.id, date: TestCalendar.day($0), value: 0, note: "n"
            )
        }
        let evaluator = DefaultFrequencyEvaluator(calendar: calendar)
        let due = evaluator.isDue(
            habit: habit, on: TestCalendar.day(0), completions: zeroed
        )
        Issue.record("ZERO-VALUE: due with 3 zero-value records = \(due) (expected true)")
    }
}
