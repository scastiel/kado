import Testing
import Foundation
import SwiftData
@testable import Kado

@Suite("CompletionLogger")
@MainActor
struct CompletionLoggerTests {
    let container: ModelContainer

    init() throws {
        container = try ModelContainer(
            for: HabitRecord.self, CompletionRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @Test("incrementCounter creates a completion with value 1 when none exists today")
    func incrementCreatesWhenAbsent() throws {
        let habit = HabitRecord(name: "Water", frequency: .daily, type: .counter(target: 8))
        container.mainContext.insert(habit)

        let logger = CompletionLogger(calendar: TestCalendar.utc)
        logger.incrementCounter(for: habit, on: TestCalendar.day(0), in: container.mainContext)
        try container.mainContext.save()

        #expect(habit.completions?.count == 1)
        #expect(habit.completions?.first?.value == 1)
    }

    @Test("incrementCounter adds to existing today's value")
    func incrementAddsToExisting() throws {
        let habit = HabitRecord(type: .counter(target: 8))
        container.mainContext.insert(habit)
        let existing = CompletionRecord(date: TestCalendar.day(0), value: 3, habit: habit)
        container.mainContext.insert(existing)
        try container.mainContext.save()

        let logger = CompletionLogger(calendar: TestCalendar.utc)
        logger.incrementCounter(for: habit, on: TestCalendar.day(0), in: container.mainContext)
        try container.mainContext.save()

        #expect(habit.completions?.count == 1)
        #expect(habit.completions?.first?.value == 4)
    }

    @Test("decrementCounter reduces value by 1")
    func decrementReducesValue() throws {
        let habit = HabitRecord(type: .counter(target: 8))
        container.mainContext.insert(habit)
        let existing = CompletionRecord(date: TestCalendar.day(0), value: 5, habit: habit)
        container.mainContext.insert(existing)
        try container.mainContext.save()

        let logger = CompletionLogger(calendar: TestCalendar.utc)
        logger.decrementCounter(for: habit, on: TestCalendar.day(0), in: container.mainContext)
        try container.mainContext.save()

        #expect(habit.completions?.first?.value == 4)
    }

    @Test("decrementCounter below 1 deletes the completion")
    func decrementDeletesWhenZero() throws {
        let habit = HabitRecord(type: .counter(target: 8))
        container.mainContext.insert(habit)
        let existing = CompletionRecord(date: TestCalendar.day(0), value: 1, habit: habit)
        container.mainContext.insert(existing)
        try container.mainContext.save()

        let logger = CompletionLogger(calendar: TestCalendar.utc)
        logger.decrementCounter(for: habit, on: TestCalendar.day(0), in: container.mainContext)
        try container.mainContext.save()

        #expect(habit.completions?.isEmpty ?? true)
    }

    @Test("decrementCounter with no completion is a no-op")
    func decrementWithoutCompletionIsNoOp() throws {
        let habit = HabitRecord(type: .counter(target: 8))
        container.mainContext.insert(habit)
        try container.mainContext.save()

        let logger = CompletionLogger(calendar: TestCalendar.utc)
        logger.decrementCounter(for: habit, on: TestCalendar.day(0), in: container.mainContext)
        try container.mainContext.save()

        #expect(habit.completions?.isEmpty ?? true)
    }

    @Test("logTimerSession creates a completion with value = seconds")
    func timerSessionCreates() throws {
        let habit = HabitRecord(type: .timer(targetSeconds: 30 * 60))
        container.mainContext.insert(habit)

        let logger = CompletionLogger(calendar: TestCalendar.utc)
        logger.logTimerSession(for: habit, seconds: 25 * 60, on: TestCalendar.day(0), in: container.mainContext)
        try container.mainContext.save()

        #expect(habit.completions?.count == 1)
        #expect(habit.completions?.first?.value == Double(25 * 60))
    }

    @Test("logTimerSession replaces today's existing completion")
    func timerSessionReplaces() throws {
        let habit = HabitRecord(type: .timer(targetSeconds: 30 * 60))
        container.mainContext.insert(habit)
        let existing = CompletionRecord(date: TestCalendar.day(0), value: 10 * 60, habit: habit)
        container.mainContext.insert(existing)
        try container.mainContext.save()

        let logger = CompletionLogger(calendar: TestCalendar.utc)
        logger.logTimerSession(for: habit, seconds: 40 * 60, on: TestCalendar.day(0), in: container.mainContext)
        try container.mainContext.save()

        #expect(habit.completions?.count == 1)
        #expect(habit.completions?.first?.value == Double(40 * 60))
    }

    @Test("delete removes the given completion without touching others")
    func deleteRemovesOnly() throws {
        let habit = HabitRecord(type: .counter(target: 8))
        container.mainContext.insert(habit)
        let c1 = CompletionRecord(date: TestCalendar.day(0), value: 3, habit: habit)
        let c2 = CompletionRecord(date: TestCalendar.day(-1), value: 4, habit: habit)
        container.mainContext.insert(c1)
        container.mainContext.insert(c2)
        try container.mainContext.save()

        let logger = CompletionLogger(calendar: TestCalendar.utc)
        logger.delete(c1, in: container.mainContext)
        try container.mainContext.save()

        #expect(habit.completions?.count == 1)
        #expect(habit.completions?.first?.id == c2.id)
    }

    @Test("Incrementing on two consecutive days creates two records")
    func incrementSpanningDays() throws {
        let habit = HabitRecord(type: .counter(target: 8))
        container.mainContext.insert(habit)
        try container.mainContext.save()

        let logger = CompletionLogger(calendar: TestCalendar.utc)
        logger.incrementCounter(for: habit, on: TestCalendar.day(-1), in: container.mainContext)
        logger.incrementCounter(for: habit, on: TestCalendar.day(0), in: container.mainContext)
        try container.mainContext.save()

        #expect(habit.completions?.count == 2)
    }
}
