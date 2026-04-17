import Testing
import Foundation
@testable import Kado

@Suite("HabitScoreCalculator — invariants and binary daily")
struct HabitScoreCalculatorTests {
    let calculator = DefaultHabitScoreCalculator(
        alpha: 0.05,
        calendar: TestCalendar.utc
    )

    // MARK: Invariants

    @Test("Empty history → score is 0")
    func emptyHistoryIsZero() {
        let habit = makeHabit(createdOffset: 0)
        let score = calculator.currentScore(
            for: habit,
            completions: [],
            asOf: TestCalendar.day(0)
        )
        #expect(score == 0)
    }

    @Test("No completions over 30 days → score stays at 0")
    func noCompletionsScoreStaysZero() {
        let habit = makeHabit(createdOffset: 0)
        let score = calculator.currentScore(
            for: habit,
            completions: [],
            asOf: TestCalendar.day(30)
        )
        #expect(score == 0)
    }

    @Test("Score stays within [0, 1] across mixed input")
    func scoreInRange() {
        let habit = makeHabit(createdOffset: 0)
        // Alternating completed / missed days for 60 days.
        let completions = stride(from: 0, to: 60, by: 2).map {
            Completion(habitID: habit.id, date: TestCalendar.day($0))
        }
        let history = calculator.scoreHistory(
            for: habit,
            completions: completions,
            from: TestCalendar.day(0),
            to: TestCalendar.day(60)
        )
        for point in history {
            #expect(point.score >= 0 && point.score <= 1, "score \(point.score) at \(point.date)")
        }
    }

    @Test("scoreHistory yields one entry per day in the range")
    func historyDailyCardinality() {
        let habit = makeHabit(createdOffset: 0)
        let history = calculator.scoreHistory(
            for: habit,
            completions: [],
            from: TestCalendar.day(0),
            to: TestCalendar.day(9)
        )
        #expect(history.count == 10)
    }

    // MARK: Characteristic cases

    @Test("30-day perfect daily streak → score > 0.75")
    func thirtyDayStreakAboveThreshold() {
        let habit = makeHabit(createdOffset: 0)
        let completions = (0..<30).map {
            Completion(habitID: habit.id, date: TestCalendar.day($0))
        }
        let score = calculator.currentScore(
            for: habit,
            completions: completions,
            asOf: TestCalendar.day(29)
        )
        #expect(score > 0.75, "got \(score)")
    }

    @Test("100-day perfect daily streak → score > 0.95")
    func hundredDayStreakAboveThreshold() {
        let habit = makeHabit(createdOffset: 0)
        let completions = (0..<100).map {
            Completion(habitID: habit.id, date: TestCalendar.day($0))
        }
        let score = calculator.currentScore(
            for: habit,
            completions: completions,
            asOf: TestCalendar.day(99)
        )
        #expect(score > 0.95, "got \(score)")
    }

    @Test("Single missed day after a perfect month barely dents the score")
    func singleMissBarelyAffects() {
        let habit = makeHabit(createdOffset: 0)
        let completions = (0..<30).map {
            Completion(habitID: habit.id, date: TestCalendar.day($0))
        }
        let scoreBefore = calculator.currentScore(
            for: habit,
            completions: completions,
            asOf: TestCalendar.day(29)
        )
        let scoreAfterMiss = calculator.currentScore(
            for: habit,
            completions: completions,
            asOf: TestCalendar.day(30)
        )
        let drop = scoreBefore - scoreAfterMiss
        #expect(drop > 0, "score should drop after a miss, got drop \(drop)")
        #expect(drop < 0.05, "single-miss drop \(drop) should be small")
    }

    @Test("Ten consecutive missed days significantly reduce the score")
    func tenMissesSignificantDrop() {
        let habit = makeHabit(createdOffset: 0)
        let completions = (0..<30).map {
            Completion(habitID: habit.id, date: TestCalendar.day($0))
        }
        let scoreBefore = calculator.currentScore(
            for: habit,
            completions: completions,
            asOf: TestCalendar.day(29)
        )
        let scoreAfterMisses = calculator.currentScore(
            for: habit,
            completions: completions,
            asOf: TestCalendar.day(39)
        )
        let drop = scoreBefore - scoreAfterMisses
        #expect(drop > 0.25, "ten-miss drop \(drop) should be significant")
    }

    @Test("Score recovers when completions resume after a slump")
    func scoreRecoversAfterSlump() {
        let habit = makeHabit(createdOffset: 0)
        var completions = (0..<30).map {
            Completion(habitID: habit.id, date: TestCalendar.day($0))
        }
        completions += (40..<50).map {
            Completion(habitID: habit.id, date: TestCalendar.day($0))
        }
        let slump = calculator.currentScore(
            for: habit,
            completions: completions,
            asOf: TestCalendar.day(39)
        )
        let recovered = calculator.currentScore(
            for: habit,
            completions: completions,
            asOf: TestCalendar.day(49)
        )
        #expect(recovered > slump, "expected recovery: slump \(slump) → recovered \(recovered)")
    }

    @Test("currentScore equals the last entry of scoreHistory")
    func currentMatchesHistoryTail() {
        let habit = makeHabit(createdOffset: 0)
        let completions = (0..<20).map {
            Completion(habitID: habit.id, date: TestCalendar.day($0))
        }
        let asOf = TestCalendar.day(25)
        let current = calculator.currentScore(for: habit, completions: completions, asOf: asOf)
        let history = calculator.scoreHistory(
            for: habit,
            completions: completions,
            from: habit.createdAt,
            to: asOf
        )
        #expect(current == history.last?.score)
    }

    // MARK: Non-daily frequencies

    @Test("Specific-days perfect adherence yields the same score as daily perfects of equal due-day count")
    func specificDaysSkipsNonDueDaysIdentically() {
        // Daily, 30 perfect days.
        let daily = makeHabit(createdOffset: 0)
        let dailyCompletions = (0..<30).map {
            Completion(habitID: daily.id, date: TestCalendar.day($0))
        }
        let dailyScore = calculator.currentScore(
            for: daily,
            completions: dailyCompletions,
            asOf: TestCalendar.day(29)
        )

        // Mon/Wed/Fri, perfect over 10 weeks → 30 due days.
        let mwf = Habit(
            name: "MWF",
            frequency: .specificDays([.monday, .wednesday, .friday]),
            type: .binary,
            createdAt: TestCalendar.day(0)
        )
        var mwfCompletions: [Completion] = []
        for week in 0..<10 {
            for offsetInWeek in [0, 2, 4] {
                mwfCompletions.append(
                    Completion(habitID: mwf.id, date: TestCalendar.day(week * 7 + offsetInWeek))
                )
            }
        }
        // Last due day in the 10-week window is week 9, offset 4 → day 67.
        let mwfScore = calculator.currentScore(
            for: mwf,
            completions: mwfCompletions,
            asOf: TestCalendar.day(67)
        )

        #expect(abs(dailyScore - mwfScore) < 1e-9, "daily=\(dailyScore) mwf=\(mwfScore)")
    }

    @Test("Every-3-days perfect adherence equals daily perfect over the same due-day count")
    func everyNDaysMatchesDailyForEqualDueCount() {
        let daily = makeHabit(createdOffset: 0)
        let dailyCompletions = (0..<20).map {
            Completion(habitID: daily.id, date: TestCalendar.day($0))
        }
        let dailyScore = calculator.currentScore(
            for: daily,
            completions: dailyCompletions,
            asOf: TestCalendar.day(19)
        )

        let everyThree = Habit(
            name: "Long run",
            frequency: .everyNDays(3),
            type: .binary,
            createdAt: TestCalendar.day(0)
        )
        // 20 due days at offsets 0, 3, 6, ..., 57.
        let everyThreeCompletions = (0..<20).map {
            Completion(habitID: everyThree.id, date: TestCalendar.day($0 * 3))
        }
        let everyThreeScore = calculator.currentScore(
            for: everyThree,
            completions: everyThreeCompletions,
            asOf: TestCalendar.day(57)
        )

        #expect(abs(dailyScore - everyThreeScore) < 1e-9, "daily=\(dailyScore) every3=\(everyThreeScore)")
    }

    @Test("Off-schedule completions on non-due days do not contribute to the score")
    func offScheduleCompletionsIgnored() {
        let mondayOnly = Habit(
            name: "Mondays only",
            frequency: .specificDays([.monday]),
            type: .binary,
            createdAt: TestCalendar.day(0)
        )
        // User completes every single day for 30 days — but only Mondays count.
        let everyDay = (0..<30).map {
            Completion(habitID: mondayOnly.id, date: TestCalendar.day($0))
        }
        let scoreEveryDay = calculator.currentScore(
            for: mondayOnly,
            completions: everyDay,
            asOf: TestCalendar.day(29)
        )

        let mondaysOnly = (0..<30).filter { $0 % 7 == 0 }.map {
            Completion(habitID: mondayOnly.id, date: TestCalendar.day($0))
        }
        let scoreMondaysOnly = calculator.currentScore(
            for: mondayOnly,
            completions: mondaysOnly,
            asOf: TestCalendar.day(29)
        )

        #expect(scoreEveryDay == scoreMondaysOnly)
    }

    // MARK: Counter, timer, negative habit types

    @Test("Counter habit at target equals binary perfect")
    func counterAtTargetEqualsBinary() {
        let binary = makeHabit(createdOffset: 0)
        let binaryCompletions = (0..<30).map {
            Completion(habitID: binary.id, date: TestCalendar.day($0))
        }
        let binaryScore = calculator.currentScore(
            for: binary,
            completions: binaryCompletions,
            asOf: TestCalendar.day(29)
        )

        let counter = Habit(
            name: "Water",
            frequency: .daily,
            type: .counter(target: 8),
            createdAt: TestCalendar.day(0)
        )
        let counterCompletions = (0..<30).map {
            Completion(habitID: counter.id, date: TestCalendar.day($0), value: 8)
        }
        let counterScore = calculator.currentScore(
            for: counter,
            completions: counterCompletions,
            asOf: TestCalendar.day(29)
        )

        #expect(abs(binaryScore - counterScore) < 1e-9)
    }

    @Test("Counter at 6/8 yields 0.75 of binary perfect")
    func counterPartialCredit() {
        let counter = Habit(
            name: "Water",
            frequency: .daily,
            type: .counter(target: 8),
            createdAt: TestCalendar.day(0)
        )
        let completions = (0..<30).map {
            Completion(habitID: counter.id, date: TestCalendar.day($0), value: 6)
        }
        let score = calculator.currentScore(
            for: counter,
            completions: completions,
            asOf: TestCalendar.day(29)
        )
        let expected = 0.75 * (1 - pow(0.95, 30))
        #expect(abs(score - expected) < 1e-9, "got \(score) expected \(expected)")
    }

    @Test("Counter exceeding target caps at 1.0")
    func counterCapsAtOne() {
        let counter = Habit(
            name: "Water",
            frequency: .daily,
            type: .counter(target: 8),
            createdAt: TestCalendar.day(0)
        )
        let over = (0..<30).map {
            Completion(habitID: counter.id, date: TestCalendar.day($0), value: 12)
        }
        let exact = (0..<30).map {
            Completion(habitID: counter.id, date: TestCalendar.day($0), value: 8)
        }
        let scoreOver = calculator.currentScore(for: counter, completions: over, asOf: TestCalendar.day(29))
        let scoreExact = calculator.currentScore(for: counter, completions: exact, asOf: TestCalendar.day(29))
        #expect(scoreOver == scoreExact)
    }

    @Test("Counter sums multiple same-day completions toward target")
    func counterSumsSameDay() {
        let counter = Habit(
            name: "Water",
            frequency: .daily,
            type: .counter(target: 8),
            createdAt: TestCalendar.day(0)
        )
        var split: [Completion] = []
        for d in 0..<30 {
            split.append(Completion(habitID: counter.id, date: TestCalendar.day(d), value: 3))
            split.append(Completion(habitID: counter.id, date: TestCalendar.day(d), value: 3))
            split.append(Completion(habitID: counter.id, date: TestCalendar.day(d), value: 2))
        }
        let single = (0..<30).map {
            Completion(habitID: counter.id, date: TestCalendar.day($0), value: 8)
        }
        let scoreSplit = calculator.currentScore(for: counter, completions: split, asOf: TestCalendar.day(29))
        let scoreSingle = calculator.currentScore(for: counter, completions: single, asOf: TestCalendar.day(29))
        #expect(abs(scoreSplit - scoreSingle) < 1e-9)
    }

    @Test("Timer habit uses ratio of achieved-seconds over target-seconds")
    func timerRatio() {
        // Target 30 minutes = 1800s. Achieved 20 minutes = 1200s. Ratio = 2/3.
        let timer = Habit(
            name: "Read",
            frequency: .daily,
            type: .timer(targetSeconds: 1800),
            createdAt: TestCalendar.day(0)
        )
        let completions = (0..<30).map {
            Completion(habitID: timer.id, date: TestCalendar.day($0), value: 1200)
        }
        let score = calculator.currentScore(for: timer, completions: completions, asOf: TestCalendar.day(29))
        let expected = (2.0 / 3.0) * (1 - pow(0.95, 30))
        #expect(abs(score - expected) < 1e-9, "got \(score) expected \(expected)")
    }

    @Test("Negative habit: no-completion days raise the score")
    func negativeAvoidedRaisesScore() {
        let neg = Habit(
            name: "No smoking",
            frequency: .daily,
            type: .negative,
            createdAt: TestCalendar.day(0)
        )
        let score = calculator.currentScore(for: neg, completions: [], asOf: TestCalendar.day(29))
        #expect(score > 0.75, "got \(score)")
    }

    @Test("Negative habit: a logged completion drops the score (failure)")
    func negativeLoggedDropsScore() {
        let neg = Habit(
            name: "No smoking",
            frequency: .daily,
            type: .negative,
            createdAt: TestCalendar.day(0)
        )
        let allDays = (0..<30).map {
            Completion(habitID: neg.id, date: TestCalendar.day($0))
        }
        let score = calculator.currentScore(for: neg, completions: allDays, asOf: TestCalendar.day(29))
        #expect(score == 0)
    }

    // MARK: Helpers

    private func makeHabit(createdOffset: Int) -> Habit {
        Habit(
            name: "Run",
            frequency: .daily,
            type: .binary,
            createdAt: TestCalendar.day(createdOffset)
        )
    }
}
