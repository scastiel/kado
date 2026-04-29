import Testing
import Foundation
import SwiftData
@testable import Kado
import KadoCore

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

    @Test("setCounter creates a completion at the exact value when none exists")
    func setCounterCreatesAtValue() throws {
        let habit = HabitRecord(type: .counter(target: 8))
        container.mainContext.insert(habit)

        let logger = CompletionLogger(calendar: TestCalendar.utc)
        logger.setCounter(for: habit, on: TestCalendar.day(0), to: 5, in: container.mainContext)
        try container.mainContext.save()

        #expect(habit.completions?.count == 1)
        #expect(habit.completions?.first?.value == 5)
    }

    @Test("setCounter overwrites today's existing value (does not add)")
    func setCounterOverwrites() throws {
        let habit = HabitRecord(type: .counter(target: 8))
        container.mainContext.insert(habit)
        let existing = CompletionRecord(date: TestCalendar.day(0), value: 3, habit: habit)
        container.mainContext.insert(existing)
        try container.mainContext.save()

        let logger = CompletionLogger(calendar: TestCalendar.utc)
        logger.setCounter(for: habit, on: TestCalendar.day(0), to: 7, in: container.mainContext)
        try container.mainContext.save()

        #expect(habit.completions?.count == 1)
        #expect(habit.completions?.first?.value == 7)
    }

    @Test("setCounter to 0 deletes the existing completion")
    func setCounterZeroDeletes() throws {
        let habit = HabitRecord(type: .counter(target: 8))
        container.mainContext.insert(habit)
        let existing = CompletionRecord(date: TestCalendar.day(0), value: 3, habit: habit)
        container.mainContext.insert(existing)
        try container.mainContext.save()

        let logger = CompletionLogger(calendar: TestCalendar.utc)
        logger.setCounter(for: habit, on: TestCalendar.day(0), to: 0, in: container.mainContext)
        try container.mainContext.save()

        #expect(habit.completions?.isEmpty ?? true)
    }

    @Test("setCounter to 0 with no existing completion is a no-op")
    func setCounterZeroNoOp() throws {
        let habit = HabitRecord(type: .counter(target: 8))
        container.mainContext.insert(habit)
        try container.mainContext.save()

        let logger = CompletionLogger(calendar: TestCalendar.utc)
        logger.setCounter(for: habit, on: TestCalendar.day(0), to: 0, in: container.mainContext)
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

    @Test("setCounter on a past day preserves other days' values")
    func setCounterPastDayPreservesOthers() throws {
        let habit = HabitRecord(type: .counter(target: 8))
        container.mainContext.insert(habit)
        let d3 = CompletionRecord(date: TestCalendar.day(-3), value: 2, habit: habit)
        let d1 = CompletionRecord(date: TestCalendar.day(-1), value: 4, habit: habit)
        container.mainContext.insert(d3)
        container.mainContext.insert(d1)
        try container.mainContext.save()

        let logger = CompletionLogger(calendar: TestCalendar.utc)
        logger.setCounter(for: habit, on: TestCalendar.day(-2), to: 6, in: container.mainContext)
        try container.mainContext.save()

        #expect(habit.completions?.count == 3)
        let newRecord = habit.completions?.first {
            TestCalendar.utc.isDate($0.date, inSameDayAs: TestCalendar.day(-2))
        }
        #expect(newRecord?.value == 6)
        #expect(habit.completions?.first { $0.id == d3.id }?.value == 2)
        #expect(habit.completions?.first { $0.id == d1.id }?.value == 4)
    }

    @Test("logTimerSession on a past day targets the correct day")
    func timerPastDayTargetsCorrectDay() throws {
        let habit = HabitRecord(type: .timer(targetSeconds: 30 * 60))
        container.mainContext.insert(habit)
        let todaySession = CompletionRecord(date: TestCalendar.day(0), value: 10 * 60, habit: habit)
        container.mainContext.insert(todaySession)
        try container.mainContext.save()

        let logger = CompletionLogger(calendar: TestCalendar.utc)
        logger.logTimerSession(for: habit, seconds: 25 * 60, on: TestCalendar.day(-2), in: container.mainContext)
        try container.mainContext.save()

        #expect(habit.completions?.count == 2)
        let past = habit.completions?.first {
            TestCalendar.utc.isDate($0.date, inSameDayAs: TestCalendar.day(-2))
        }
        #expect(past?.value == Double(25 * 60))
        #expect(habit.completions?.first { $0.id == todaySession.id }?.value == Double(10 * 60))
    }

    @Test("setCounter to 0 on a past day deletes only that day's record")
    func setCounterPastDayZeroDeletesOnlyThatDay() throws {
        let habit = HabitRecord(type: .counter(target: 8))
        container.mainContext.insert(habit)
        let todayValue = CompletionRecord(date: TestCalendar.day(0), value: 3, habit: habit)
        let pastValue = CompletionRecord(date: TestCalendar.day(-3), value: 2, habit: habit)
        container.mainContext.insert(todayValue)
        container.mainContext.insert(pastValue)
        try container.mainContext.save()

        let logger = CompletionLogger(calendar: TestCalendar.utc)
        logger.setCounter(for: habit, on: TestCalendar.day(-3), to: 0, in: container.mainContext)
        try container.mainContext.save()

        #expect(habit.completions?.count == 1)
        #expect(habit.completions?.first?.id == todayValue.id)
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

    // MARK: - Note mutations

    @Test("setNote on existing completion sets the note without changing value")
    func setNoteOnExistingCompletion() throws {
        let habit = HabitRecord(type: .counter(target: 8))
        container.mainContext.insert(habit)
        let existing = CompletionRecord(date: TestCalendar.day(0), value: 5, habit: habit)
        container.mainContext.insert(existing)
        try container.mainContext.save()

        let logger = CompletionLogger(calendar: TestCalendar.utc)
        logger.setNote(for: habit, on: TestCalendar.day(0), to: "Felt great", in: container.mainContext)
        try container.mainContext.save()

        #expect(habit.completions?.count == 1)
        #expect(habit.completions?.first?.note == "Felt great")
        #expect(habit.completions?.first?.value == 5)
    }

    @Test("setNote with no existing completion creates a zero-value record")
    func setNoteStandaloneCreatesRecord() throws {
        let habit = HabitRecord(type: .binary)
        container.mainContext.insert(habit)
        try container.mainContext.save()

        let logger = CompletionLogger(calendar: TestCalendar.utc)
        logger.setNote(for: habit, on: TestCalendar.day(0), to: "Skipped — was sick", in: container.mainContext)
        try container.mainContext.save()

        #expect(habit.completions?.count == 1)
        let record = try #require(habit.completions?.first)
        #expect(record.note == "Skipped — was sick")
        #expect(record.value == 0)
    }

    @Test("setNote to nil clears the note on existing completion")
    func setNoteNilClearsNote() throws {
        let habit = HabitRecord(type: .binary)
        container.mainContext.insert(habit)
        let existing = CompletionRecord(date: TestCalendar.day(0), value: 1, note: "Old note", habit: habit)
        container.mainContext.insert(existing)
        try container.mainContext.save()

        let logger = CompletionLogger(calendar: TestCalendar.utc)
        logger.setNote(for: habit, on: TestCalendar.day(0), to: nil, in: container.mainContext)
        try container.mainContext.save()

        #expect(habit.completions?.count == 1)
        #expect(habit.completions?.first?.note == nil)
        #expect(habit.completions?.first?.value == 1)
    }

    @Test("setNote to nil on a zero-value record deletes the record")
    func setNoteNilOnStandaloneDeletesRecord() throws {
        let habit = HabitRecord(type: .binary)
        container.mainContext.insert(habit)
        let existing = CompletionRecord(date: TestCalendar.day(0), value: 0, note: "Note only", habit: habit)
        container.mainContext.insert(existing)
        try container.mainContext.save()

        let logger = CompletionLogger(calendar: TestCalendar.utc)
        logger.setNote(for: habit, on: TestCalendar.day(0), to: nil, in: container.mainContext)
        try container.mainContext.save()

        #expect(habit.completions?.isEmpty ?? true)
    }

    @Test("setNote to empty string clears the note like nil")
    func setNoteEmptyStringClearsNote() throws {
        let habit = HabitRecord(type: .binary)
        container.mainContext.insert(habit)
        let existing = CompletionRecord(date: TestCalendar.day(0), value: 1, note: "Old note", habit: habit)
        container.mainContext.insert(existing)
        try container.mainContext.save()

        let logger = CompletionLogger(calendar: TestCalendar.utc)
        logger.setNote(for: habit, on: TestCalendar.day(0), to: "", in: container.mainContext)
        try container.mainContext.save()

        #expect(habit.completions?.first?.note == nil)
    }

    @Test("setNote updates an existing note")
    func setNoteUpdatesExisting() throws {
        let habit = HabitRecord(type: .counter(target: 8))
        container.mainContext.insert(habit)
        let existing = CompletionRecord(date: TestCalendar.day(0), value: 5, note: "First note", habit: habit)
        container.mainContext.insert(existing)
        try container.mainContext.save()

        let logger = CompletionLogger(calendar: TestCalendar.utc)
        logger.setNote(for: habit, on: TestCalendar.day(0), to: "Updated note", in: container.mainContext)
        try container.mainContext.save()

        #expect(habit.completions?.first?.note == "Updated note")
        #expect(habit.completions?.first?.value == 5)
    }

    @Test("logTimerSession preserves existing note")
    func timerSessionPreservesNote() throws {
        let habit = HabitRecord(type: .timer(targetSeconds: 30 * 60))
        container.mainContext.insert(habit)
        let existing = CompletionRecord(date: TestCalendar.day(0), value: 10 * 60, note: "Morning run", habit: habit)
        container.mainContext.insert(existing)
        try container.mainContext.save()

        let logger = CompletionLogger(calendar: TestCalendar.utc)
        logger.logTimerSession(for: habit, seconds: 25 * 60, on: TestCalendar.day(0), in: container.mainContext)
        try container.mainContext.save()

        #expect(habit.completions?.count == 1)
        #expect(habit.completions?.first?.value == Double(25 * 60))
        #expect(habit.completions?.first?.note == "Morning run")
    }

    @Test("decrementCounter preserves note when value stays above zero")
    func decrementPreservesNote() throws {
        let habit = HabitRecord(type: .counter(target: 8))
        container.mainContext.insert(habit)
        let existing = CompletionRecord(date: TestCalendar.day(0), value: 3, note: "Some note", habit: habit)
        container.mainContext.insert(existing)
        try container.mainContext.save()

        let logger = CompletionLogger(calendar: TestCalendar.utc)
        logger.decrementCounter(for: habit, on: TestCalendar.day(0), in: container.mainContext)
        try container.mainContext.save()

        #expect(habit.completions?.first?.value == 2)
        #expect(habit.completions?.first?.note == "Some note")
    }

    @Test("decrementCounter to zero keeps record if note exists")
    func decrementToZeroKeepsNoteRecord() throws {
        let habit = HabitRecord(type: .counter(target: 8))
        container.mainContext.insert(habit)
        let existing = CompletionRecord(date: TestCalendar.day(0), value: 1, note: "Keep me", habit: habit)
        container.mainContext.insert(existing)
        try container.mainContext.save()

        let logger = CompletionLogger(calendar: TestCalendar.utc)
        logger.decrementCounter(for: habit, on: TestCalendar.day(0), in: container.mainContext)
        try container.mainContext.save()

        #expect(habit.completions?.count == 1)
        #expect(habit.completions?.first?.value == 0)
        #expect(habit.completions?.first?.note == "Keep me")
    }

    @Test("setCounter to zero keeps record if note exists")
    func setCounterZeroKeepsNoteRecord() throws {
        let habit = HabitRecord(type: .counter(target: 8))
        container.mainContext.insert(habit)
        let existing = CompletionRecord(date: TestCalendar.day(0), value: 5, note: "Important", habit: habit)
        container.mainContext.insert(existing)
        try container.mainContext.save()

        let logger = CompletionLogger(calendar: TestCalendar.utc)
        logger.setCounter(for: habit, on: TestCalendar.day(0), to: 0, in: container.mainContext)
        try container.mainContext.save()

        #expect(habit.completions?.count == 1)
        #expect(habit.completions?.first?.value == 0)
        #expect(habit.completions?.first?.note == "Important")
    }
}
