import Testing
import Foundation
@testable import Kado
import KadoCore

@Suite("FrequencyEvaluator")
struct FrequencyEvaluatorTests {
    let evaluator = DefaultFrequencyEvaluator(calendar: TestCalendar.utc)

    // MARK: Lifecycle bounds

    @Test("Day before createdAt with no completions is not due")
    func notDueBeforeCreatedNoCompletions() {
        let habit = makeHabit(.daily, createdOffset: 0)
        #expect(!evaluator.isDue(habit: habit, on: TestCalendar.day(-1), completions: []))
    }

    @Test("Day before createdAt with a completion on that day is due")
    func dueBeforeCreatedWithCompletion() {
        let habit = makeHabit(.daily, createdOffset: 0)
        let completions = [Completion(habitID: habit.id, date: TestCalendar.day(-1))]
        #expect(evaluator.isDue(habit: habit, on: TestCalendar.day(-1), completions: completions))
    }

    @Test("Day before effective start is not due")
    func notDueBeforeEffectiveStart() {
        let habit = makeHabit(.daily, createdOffset: 0)
        let completions = [Completion(habitID: habit.id, date: TestCalendar.day(-3))]
        #expect(!evaluator.isDue(habit: habit, on: TestCalendar.day(-5), completions: completions))
    }

    @Test("Day after archivedAt is never due")
    func notDueAfterArchived() {
        let habit = makeHabit(.daily, createdOffset: 0, archivedOffset: 5)
        #expect(!evaluator.isDue(habit: habit, on: TestCalendar.day(6), completions: []))
    }

    @Test("Day equal to archivedAt is still due")
    func dueOnArchivalDay() {
        let habit = makeHabit(.daily, createdOffset: 0, archivedOffset: 5)
        #expect(evaluator.isDue(habit: habit, on: TestCalendar.day(5), completions: []))
    }

    // MARK: .daily

    @Test("Daily habit is due every day")
    func dailyAlwaysDue() {
        let habit = makeHabit(.daily, createdOffset: 0)
        for offset in 0..<14 {
            #expect(evaluator.isDue(habit: habit, on: TestCalendar.day(offset), completions: []))
        }
    }

    // MARK: .specificDays

    @Test("Specific-days habit is due only on listed weekdays")
    func specificDaysOnly() {
        // Day 0 is Monday. Pattern: Mon=0, Tue=1, …, Sun=6.
        let habit = makeHabit(
            .specificDays([.monday, .wednesday, .friday]),
            createdOffset: 0
        )
        let expected: [(offset: Int, due: Bool)] = [
            (0, true),   // Mon
            (1, false),  // Tue
            (2, true),   // Wed
            (3, false),  // Thu
            (4, true),   // Fri
            (5, false),  // Sat
            (6, false),  // Sun
            (7, true),   // Mon
        ]
        for (offset, due) in expected {
            #expect(
                evaluator.isDue(habit: habit, on: TestCalendar.day(offset), completions: []) == due,
                "offset \(offset) expected due=\(due)"
            )
        }
    }

    // MARK: .everyNDays

    @Test("Every-3-days habit is due on createdAt and every third day after")
    func everyNDaysCadence() {
        let habit = makeHabit(.everyNDays(3), createdOffset: 0)
        let dueOffsets: Set<Int> = [0, 3, 6, 9, 12]
        for offset in 0...12 {
            let isDue = evaluator.isDue(habit: habit, on: TestCalendar.day(offset), completions: [])
            #expect(isDue == dueOffsets.contains(offset), "offset \(offset)")
        }
    }

    // MARK: .everyNDays — the cycle re-anchors on completion

    @Test("Completing early restarts the every-2-days cycle")
    func everyNDaysReanchorsOnEarlyCompletion() {
        // Created Monday (offset 0), done Mon, Tue, Thu. Tuesday's
        // completion moves the next due day from Wednesday to
        // Thursday, so Wednesday is never asked for and none of the
        // three days reads as a miss.
        let habit = makeHabit(.everyNDays(2), createdOffset: 0)
        let completions = [0, 1, 3].map {
            Completion(habitID: habit.id, date: TestCalendar.day($0))
        }
        let expected: [Int: Bool] = [0: true, 1: false, 2: false, 3: true, 4: false, 5: true]
        for offset in 0...5 {
            #expect(
                evaluator.isDue(habit: habit, on: TestCalendar.day(offset), completions: completions)
                    == expected[offset]!,
                "offset \(offset) expected due=\(expected[offset]!)"
            )
        }
    }

    @Test("A missed due day does not reschedule the every-N-days cycle")
    func everyNDaysMissKeepsTheCycle() {
        // Done on day 0 only. Day 3 is due and goes unmet — the cycle
        // stays anchored to day 0, so day 6 is due. Skipping must not
        // buy the user a fresh interval; only doing the work does.
        let habit = makeHabit(.everyNDays(3), createdOffset: 0)
        let completions = [Completion(habitID: habit.id, date: TestCalendar.day(0))]
        #expect(evaluator.isDue(habit: habit, on: TestCalendar.day(3), completions: completions))
        #expect(!evaluator.isDue(habit: habit, on: TestCalendar.day(4), completions: completions))
        #expect(!evaluator.isDue(habit: habit, on: TestCalendar.day(5), completions: completions))
        #expect(evaluator.isDue(habit: habit, on: TestCalendar.day(6), completions: completions))
    }

    @Test("everyNDays ignores completions belonging to another habit")
    func everyNDaysIgnoresOtherHabits() {
        let habit = makeHabit(.everyNDays(2), createdOffset: 0)
        let completions = [Completion(habitID: UUID(), date: TestCalendar.day(1))]
        #expect(evaluator.isDue(habit: habit, on: TestCalendar.day(2), completions: completions))
        #expect(!evaluator.isDue(habit: habit, on: TestCalendar.day(3), completions: completions))
    }

    @Test("A note-only day does not restart the every-N-days cycle")
    func everyNDaysZeroValueDoesNotReanchor() {
        // `CompletionToggler` leaves a value-0 record behind when an
        // unchecked day carries a note. Nothing was done that day, so
        // nothing re-anchors.
        let habit = makeHabit(.everyNDays(2), createdOffset: 0)
        let completions = [
            Completion(habitID: habit.id, date: TestCalendar.day(1), value: 0, note: "note")
        ]
        #expect(evaluator.isDue(habit: habit, on: TestCalendar.day(2), completions: completions))
        #expect(!evaluator.isDue(habit: habit, on: TestCalendar.day(3), completions: completions))
    }

    @Test("A negative habit's slip does not restart the every-N-days cycle")
    func everyNDaysNegativeSlipDoesNotReanchor() {
        // On a `.negative` habit a record means the user *broke* it.
        // Slipping must not push the next check-in day out.
        let habit = Habit(
            name: "No soda",
            frequency: .everyNDays(2),
            type: .negative,
            createdAt: TestCalendar.day(0)
        )
        let completions = [Completion(habitID: habit.id, date: TestCalendar.day(1))]
        #expect(evaluator.isDue(habit: habit, on: TestCalendar.day(2), completions: completions))
        #expect(!evaluator.isDue(habit: habit, on: TestCalendar.day(3), completions: completions))
    }

    @Test("The re-anchored cycle holds across DST transitions of every shape")
    func everyNDaysReanchorSurvivesDST() {
        // The invariant, not an example: after an early completion the
        // next due day is two calendar days later, whatever the day's
        // length. Paris shifts at 02:00/03:00; Havana shifts at
        // midnight, so its day starts at 01:00 and any arithmetic that
        // assumes midnight exists drifts by an hour.
        let fixtures: [(String, Calendar, Date)] = [
            ("Paris spring-forward", TestCalendar.paris, TestCalendar.instant(TestCalendar.paris, 2026, 3, 27, 12)),
            ("Paris fall-back", TestCalendar.paris, TestCalendar.instant(TestCalendar.paris, 2026, 10, 23, 12)),
            ("Havana midnight shift", TestCalendar.havana, TestCalendar.instant(TestCalendar.havana, 2026, 3, 6, 12)),
        ]
        for (label, calendar, start) in fixtures {
            let evaluator = DefaultFrequencyEvaluator(calendar: calendar)
            let habit = Habit(
                name: "Run",
                frequency: .everyNDays(2),
                type: .binary,
                createdAt: start
            )
            func day(_ offset: Int) -> Date {
                calendar.date(byAdding: .day, value: offset, to: start)!
            }
            // Done on the created day and again the next day: the
            // early completion moves the next due day from +2 to +3.
            let completions = [0, 1].map { Completion(habitID: habit.id, date: day($0)) }
            #expect(evaluator.isDue(habit: habit, on: day(0), completions: completions), "\(label) day 0")
            #expect(!evaluator.isDue(habit: habit, on: day(2), completions: completions), "\(label) day 2")
            #expect(evaluator.isDue(habit: habit, on: day(3), completions: completions), "\(label) day 3")
        }
    }

    // MARK: .daysPerWeek (trailing 7-day rolling window)

    @Test("3-per-week habit is due when trailing 7-day window has zero completions")
    func daysPerWeekDueWhenEmpty() {
        let habit = makeHabit(.daysPerWeek(3), createdOffset: 0)
        #expect(evaluator.isDue(habit: habit, on: TestCalendar.day(7), completions: []))
    }

    @Test("3-per-week habit is not due once 3 earlier completions fill the trailing window")
    func daysPerWeekRollingQuota() {
        let habit = makeHabit(.daysPerWeek(3), createdOffset: 0)
        let completions = [
            Completion(habitID: habit.id, date: TestCalendar.day(1)),
            Completion(habitID: habit.id, date: TestCalendar.day(3)),
            Completion(habitID: habit.id, date: TestCalendar.day(5)),
        ]
        // Day 5: `isDue` looks at days -1...4, which hold two
        // completions — day 5's own completion is not evidence that
        // day 5 was unnecessary. `isOutstanding` counts it and sees
        // the quota met.
        #expect(evaluator.isDue(habit: habit, on: TestCalendar.day(5), completions: completions))
        #expect(!evaluator.isOutstanding(habit: habit, on: TestCalendar.day(5), completions: completions))
        // Day 7: days 1...6 hold all three → not due either way.
        #expect(!evaluator.isDue(habit: habit, on: TestCalendar.day(7), completions: completions))
        // Day 8: days 2...7 — day 1 falls out, two remain → due.
        #expect(evaluator.isDue(habit: habit, on: TestCalendar.day(8), completions: completions))
    }

    @Test("daysPerWeek ignores completions for unrelated habits")
    func daysPerWeekIgnoresOtherHabits() {
        let habit = makeHabit(.daysPerWeek(3), createdOffset: 0)
        let otherID = UUID()
        let completions = (1...3).map {
            Completion(habitID: otherID, date: TestCalendar.day($0))
        }
        #expect(evaluator.isDue(habit: habit, on: TestCalendar.day(5), completions: completions))
    }

    // MARK: .daysPerWeek — isDue is monotonic (issue #57)

    @Test("isDue ignores the evaluated day's own completion")
    func isDueIsMonotonic() {
        // Four completions in the trailing window, target of five.
        // Logging the fifth *on* day 6 must not retroactively decide
        // that day 6 was never required.
        let habit = makeHabit(.daysPerWeek(5), createdOffset: 0)
        let priorFour = [2, 3, 4, 5].map {
            Completion(habitID: habit.id, date: TestCalendar.day($0))
        }
        let withOwnDay = priorFour + [
            Completion(habitID: habit.id, date: TestCalendar.day(6))
        ]

        #expect(evaluator.isDue(habit: habit, on: TestCalendar.day(6), completions: priorFour))
        #expect(evaluator.isDue(habit: habit, on: TestCalendar.day(6), completions: withOwnDay))
    }

    @Test("isDue still saturates on completions strictly before the day")
    func isDueSaturatesOnPriorDays() {
        // Five completions all strictly before day 6 → the quota is
        // met without day 6, so day 6 is not required.
        let habit = makeHabit(.daysPerWeek(5), createdOffset: 0)
        let completions = [1, 2, 3, 4, 5].map {
            Completion(habitID: habit.id, date: TestCalendar.day($0))
        }
        #expect(!evaluator.isDue(habit: habit, on: TestCalendar.day(6), completions: completions))
    }

    // MARK: .daysPerWeek — isOutstanding counts the day itself

    @Test("isOutstanding counts the evaluated day's own completion")
    func isOutstandingCountsOwnDay() {
        let habit = makeHabit(.daysPerWeek(5), createdOffset: 0)
        let priorFour = [2, 3, 4, 5].map {
            Completion(habitID: habit.id, date: TestCalendar.day($0))
        }
        let withOwnDay = priorFour + [
            Completion(habitID: habit.id, date: TestCalendar.day(6))
        ]

        // Four logged, one to go → still outstanding.
        #expect(evaluator.isOutstanding(habit: habit, on: TestCalendar.day(6), completions: priorFour))
        // Fifth logged today → nothing left to do.
        #expect(!evaluator.isOutstanding(habit: habit, on: TestCalendar.day(6), completions: withOwnDay))
    }

    @Test("isDue and isOutstanding agree for every non-daysPerWeek frequency")
    func fixedSchedulesAgree() {
        let frequencies: [Frequency] = [
            .daily,
            .specificDays([.monday, .wednesday, .friday]),
            .everyNDays(3),
        ]
        for frequency in frequencies {
            let habit = makeHabit(frequency, createdOffset: 0)
            for offset in 0...13 {
                let day = TestCalendar.day(offset)
                // Both a completion on the day itself and one on a
                // prior day. The own-day record alone cannot detect an
                // `.everyNDays` divergence: the anchor lookup skips
                // records that are not strictly earlier, so both
                // questions fall through to the createdAt fallback and
                // agree trivially. A prior-day record is what actually
                // exercises the re-anchored cycle here.
                let ownDay = [Completion(habitID: habit.id, date: day)]
                let withPrior = ownDay + [
                    Completion(habitID: habit.id, date: TestCalendar.day(offset - 1))
                ]
                for completions in [ownDay, withPrior] {
                    #expect(
                        evaluator.isDue(habit: habit, on: day, completions: completions)
                            == evaluator.isOutstanding(habit: habit, on: day, completions: completions),
                        "\(frequency) at offset \(offset)"
                    )
                }
            }
        }
    }

    // MARK: .daysPerWeek — zero-value records don't fill the quota

    @Test("Zero-value completions do not count toward the weekly quota")
    func zeroValueDoesNotSaturate() {
        // `CompletionToggler` keeps a record at value 0 when the day
        // carries a note, so "unchecked but annotated" days exist in
        // real stores. They are not completions and must not fill the
        // quota.
        let habit = makeHabit(.daysPerWeek(3), createdOffset: 0)
        let zeroed = [1, 2, 3].map {
            Completion(habitID: habit.id, date: TestCalendar.day($0), value: 0, note: "note")
        }
        #expect(evaluator.isDue(habit: habit, on: TestCalendar.day(4), completions: zeroed))
        #expect(evaluator.isOutstanding(habit: habit, on: TestCalendar.day(4), completions: zeroed))
    }

    // MARK: Backdate — everyNDays with negative deltas

    @Test("everyNDays: 6 days before creation (cycle-aligned) is due when backdated")
    func everyNDaysBackdateAligned() {
        let habit = makeHabit(.everyNDays(3), createdOffset: 0)
        let completions = [Completion(habitID: habit.id, date: TestCalendar.day(-6))]
        #expect(evaluator.isDue(habit: habit, on: TestCalendar.day(-6), completions: completions))
    }

    @Test("everyNDays: 5 days before creation (not aligned) is not due")
    func everyNDaysBackdateNotAligned() {
        let habit = makeHabit(.everyNDays(3), createdOffset: 0)
        let completions = [Completion(habitID: habit.id, date: TestCalendar.day(-6))]
        #expect(!evaluator.isDue(habit: habit, on: TestCalendar.day(-5), completions: completions))
    }

    @Test("Negative habit: day before createdAt is never due even with completion")
    func negativeNotDueBeforeCreation() {
        let habit = Habit(
            name: "No smoking",
            frequency: .daily,
            type: .negative,
            createdAt: TestCalendar.day(0)
        )
        let completions = [Completion(habitID: habit.id, date: TestCalendar.day(-2))]
        #expect(!evaluator.isDue(habit: habit, on: TestCalendar.day(-2), completions: completions))
    }

    // MARK: isDueOrLogged — the shared "show it in Today" rule

    @Test("isDueOrLogged keeps a habit visible once its weekly quota saturates")
    func isDueOrLoggedKeepsCompletedHabitVisible() {
        let habit = makeHabit(.daysPerWeek(3), createdOffset: 0)
        // Quota already met by three earlier days, then a bonus today.
        let completions = [1, 2, 3, 4].map {
            Completion(habitID: habit.id, date: TestCalendar.day($0))
        }
        let today = TestCalendar.day(4)
        #expect(!evaluator.isDue(habit: habit, on: today, completions: completions))
        #expect(
            evaluator.isDueOrLogged(
                habit: habit, on: today, completions: completions, calendar: TestCalendar.utc
            )
        )
    }

    @Test("isDueOrLogged does not surface a negative habit's off-schedule slip")
    func isDueOrLoggedIgnoresNegativeSlip() {
        // A record on a negative habit means the user broke it. On a
        // day the schedule never covered that is not a reason to show
        // the row — `HabitRowState` would resolve it to `.complete`
        // and credit the slip.
        let habit = Habit(
            name: "No alcohol",
            frequency: .specificDays([.monday]),
            type: .negative,
            createdAt: TestCalendar.day(-10)
        )
        let saturday = TestCalendar.day(-2)
        let completions = [Completion(habitID: habit.id, date: saturday)]
        #expect(!evaluator.isDue(habit: habit, on: saturday, completions: completions))
        #expect(
            !evaluator.isDueOrLogged(
                habit: habit, on: saturday, completions: completions, calendar: TestCalendar.utc
            )
        )
    }

    @Test("isDueOrLogged ignores completions belonging to other habits")
    func isDueOrLoggedIgnoresOtherHabits() {
        let habit = makeHabit(.specificDays([.monday]), createdOffset: -10)
        let saturday = TestCalendar.day(-2)
        let completions = [Completion(habitID: UUID(), date: saturday)]
        #expect(
            !evaluator.isDueOrLogged(
                habit: habit, on: saturday, completions: completions, calendar: TestCalendar.utc
            )
        )
    }

    // MARK: Helpers

    private func makeHabit(
        _ frequency: Frequency,
        createdOffset: Int,
        archivedOffset: Int? = nil
    ) -> Habit {
        Habit(
            name: "Test",
            frequency: frequency,
            type: .binary,
            createdAt: TestCalendar.day(createdOffset),
            archivedAt: archivedOffset.map(TestCalendar.day)
        )
    }
}
