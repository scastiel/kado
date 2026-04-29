import Testing
import Foundation
import SwiftData
@testable import Kado
import KadoCore

@Suite("CompletionToggler")
@MainActor
struct CompletionTogglerTests {
    let container: ModelContainer

    init() throws {
        container = try ModelContainer(
            for: HabitRecord.self, CompletionRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @Test("Toggling a habit with no completion today inserts one with value 1")
    func insertsWhenAbsent() throws {
        let habit = HabitRecord(name: "Meditate", frequency: .daily, type: .binary)
        container.mainContext.insert(habit)
        try container.mainContext.save()

        let toggler = CompletionToggler(calendar: TestCalendar.utc)
        toggler.toggleToday(for: habit, on: TestCalendar.day(0), in: container.mainContext)
        try container.mainContext.save()

        #expect(habit.completions?.count == 1)
        let completion = try #require(habit.completions?.first)
        #expect(completion.value == 1.0)
        #expect(TestCalendar.utc.isDate(completion.date, inSameDayAs: TestCalendar.day(0)))
    }

    @Test("Toggling a habit with a completion today deletes it")
    func deletesWhenPresent() throws {
        let habit = HabitRecord(name: "Meditate", frequency: .daily, type: .binary)
        container.mainContext.insert(habit)
        let existing = CompletionRecord(date: TestCalendar.day(0), value: 1, habit: habit)
        container.mainContext.insert(existing)
        try container.mainContext.save()

        let toggler = CompletionToggler(calendar: TestCalendar.utc)
        toggler.toggleToday(for: habit, on: TestCalendar.day(0), in: container.mainContext)
        try container.mainContext.save()

        #expect(habit.completions?.isEmpty ?? true)
        let remaining = try container.mainContext.fetch(FetchDescriptor<CompletionRecord>())
        #expect(remaining.isEmpty)
    }

    @Test("Toggling leaves other days' completions alone")
    func preservesOtherDays() throws {
        let habit = HabitRecord(name: "Meditate", frequency: .daily, type: .binary)
        container.mainContext.insert(habit)
        let yesterday = CompletionRecord(date: TestCalendar.day(-1), value: 1, habit: habit)
        container.mainContext.insert(yesterday)
        try container.mainContext.save()

        let toggler = CompletionToggler(calendar: TestCalendar.utc)
        toggler.toggleToday(for: habit, on: TestCalendar.day(0), in: container.mainContext)
        try container.mainContext.save()

        #expect(habit.completions?.count == 2)
        #expect(habit.completions?.contains { $0.id == yesterday.id } ?? false)
    }

    @Test("Toggling twice returns to the original state")
    func idempotentRoundTrip() throws {
        let habit = HabitRecord(name: "Meditate", frequency: .daily, type: .binary)
        container.mainContext.insert(habit)
        try container.mainContext.save()

        let toggler = CompletionToggler(calendar: TestCalendar.utc)
        toggler.toggleToday(for: habit, on: TestCalendar.day(0), in: container.mainContext)
        toggler.toggleToday(for: habit, on: TestCalendar.day(0), in: container.mainContext)
        try container.mainContext.save()

        #expect(habit.completions?.isEmpty ?? true)
    }

    @Test("Toggle on a past day inserts a record on that day, not today")
    func pastDayInsertsOnThatDay() throws {
        let habit = HabitRecord(name: "Meditate", frequency: .daily, type: .binary)
        container.mainContext.insert(habit)
        try container.mainContext.save()

        let toggler = CompletionToggler(calendar: TestCalendar.utc)
        toggler.toggleToday(for: habit, on: TestCalendar.day(-3), in: container.mainContext)
        try container.mainContext.save()

        #expect(habit.completions?.count == 1)
        let stored = try #require(habit.completions?.first)
        #expect(TestCalendar.utc.isDate(stored.date, inSameDayAs: TestCalendar.day(-3)))
        #expect(!TestCalendar.utc.isDate(stored.date, inSameDayAs: TestCalendar.day(0)))
    }

    @Test("Toggle on a past day twice leaves today's record intact")
    func pastDayRoundTripPreservesToday() throws {
        let habit = HabitRecord(name: "Meditate", frequency: .daily, type: .binary)
        container.mainContext.insert(habit)
        let todayRecord = CompletionRecord(date: TestCalendar.day(0), value: 1, habit: habit)
        container.mainContext.insert(todayRecord)
        try container.mainContext.save()

        let toggler = CompletionToggler(calendar: TestCalendar.utc)
        toggler.toggleToday(for: habit, on: TestCalendar.day(-3), in: container.mainContext)
        toggler.toggleToday(for: habit, on: TestCalendar.day(-3), in: container.mainContext)
        try container.mainContext.save()

        #expect(habit.completions?.count == 1)
        #expect(habit.completions?.first?.id == todayRecord.id)
    }

    @Test("Toggle uses the injected calendar for day comparison across timezones")
    func calendarIsolation() throws {
        // Paris calendar: a completion at 23:30 UTC is already "tomorrow"
        // in Paris (01:30 local). Toggling on Paris-today (the UTC-yesterday
        // value) must leave the UTC-evening completion alone.
        var paris = Calendar(identifier: .gregorian)
        paris.timeZone = TimeZone(identifier: "Europe/Paris")!

        let habit = HabitRecord(name: "Meditate", frequency: .daily, type: .binary)
        container.mainContext.insert(habit)

        // Reference anchor: 2026-04-13 23:30 UTC = 2026-04-14 01:30 Paris.
        var components = DateComponents()
        components.year = 2026
        components.month = 4
        components.day = 13
        components.hour = 23
        components.minute = 30
        components.timeZone = TimeZone(identifier: "UTC")
        let utcEvening = Calendar(identifier: .gregorian).date(from: components)!
        let parisToday = paris.date(byAdding: .day, value: -1, to: utcEvening)! // Paris April 13

        let existingOnParisApril14 = CompletionRecord(date: utcEvening, value: 1, habit: habit)
        container.mainContext.insert(existingOnParisApril14)
        try container.mainContext.save()

        let toggler = CompletionToggler(calendar: paris)
        toggler.toggleToday(for: habit, on: parisToday, in: container.mainContext)
        try container.mainContext.save()

        // Paris-April-13 had no completion, so we inserted one. The Paris-April-14
        // completion (utcEvening) remains untouched.
        #expect(habit.completions?.count == 2)
        #expect(habit.completions?.contains { $0.id == existingOnParisApril14.id } ?? false)
    }

    // MARK: - setValueToday (counter / timer overwrite primitive)

    @Test("setValueToday writes a new completion when none exists")
    func setValueInsertsWhenAbsent() throws {
        let habit = HabitRecord(name: "Water", frequency: .daily, type: .counter(target: 8))
        container.mainContext.insert(habit)
        try container.mainContext.save()

        let toggler = CompletionToggler(calendar: TestCalendar.utc)
        toggler.setValueToday(3, for: habit, on: TestCalendar.day(0), in: container.mainContext)
        try container.mainContext.save()

        #expect(habit.completions?.count == 1)
        let completion = try #require(habit.completions?.first)
        #expect(completion.value == 3.0)
        #expect(TestCalendar.utc.isDate(completion.date, inSameDayAs: TestCalendar.day(0)))
    }

    @Test("setValueToday overwrites an existing same-day completion")
    func setValueOverwrites() throws {
        let habit = HabitRecord(name: "Water", frequency: .daily, type: .counter(target: 8))
        container.mainContext.insert(habit)
        let existing = CompletionRecord(date: TestCalendar.day(0), value: 2, habit: habit)
        container.mainContext.insert(existing)
        try container.mainContext.save()

        let toggler = CompletionToggler(calendar: TestCalendar.utc)
        toggler.setValueToday(5, for: habit, on: TestCalendar.day(0), in: container.mainContext)
        try container.mainContext.save()

        #expect(habit.completions?.count == 1)
        #expect(habit.completions?.first?.value == 5.0)
    }

    @Test("setValueToday with zero removes today's completion")
    func setValueZeroRemoves() throws {
        let habit = HabitRecord(name: "Water", frequency: .daily, type: .counter(target: 8))
        container.mainContext.insert(habit)
        let existing = CompletionRecord(date: TestCalendar.day(0), value: 4, habit: habit)
        container.mainContext.insert(existing)
        try container.mainContext.save()

        let toggler = CompletionToggler(calendar: TestCalendar.utc)
        toggler.setValueToday(0, for: habit, on: TestCalendar.day(0), in: container.mainContext)
        try container.mainContext.save()

        #expect(habit.completions?.isEmpty ?? true)
    }

    @Test("setValueToday respects the injected calendar for day boundary")
    func setValueRespectsCalendar() throws {
        // Yesterday's completion (UTC) is left untouched when we set
        // today's value via UTC calendar.
        let habit = HabitRecord(name: "Water", frequency: .daily, type: .counter(target: 8))
        container.mainContext.insert(habit)
        let yesterday = CompletionRecord(date: TestCalendar.day(-1), value: 4, habit: habit)
        container.mainContext.insert(yesterday)
        try container.mainContext.save()

        let toggler = CompletionToggler(calendar: TestCalendar.utc)
        toggler.setValueToday(7, for: habit, on: TestCalendar.day(0), in: container.mainContext)
        try container.mainContext.save()

        #expect(habit.completions?.count == 2)
        #expect(habit.completions?.contains { $0.id == yesterday.id } ?? false)
    }

    // MARK: - Note-only record handling

    @Test("Toggling on a day with a note-only record upgrades value to 1 and keeps note")
    func toggleUpgradesNoteOnlyRecord() throws {
        let habit = HabitRecord(name: "Meditate", frequency: .daily, type: .binary)
        container.mainContext.insert(habit)
        let noteOnly = CompletionRecord(date: TestCalendar.day(0), value: 0, note: "Skipped — sick", habit: habit)
        container.mainContext.insert(noteOnly)
        try container.mainContext.save()

        let toggler = CompletionToggler(calendar: TestCalendar.utc)
        let result = toggler.toggleToday(for: habit, on: TestCalendar.day(0), in: container.mainContext)
        try container.mainContext.save()

        #expect(result == .completed)
        #expect(habit.completions?.count == 1)
        #expect(habit.completions?.first?.value == 1)
        #expect(habit.completions?.first?.note == "Skipped — sick")
    }

    @Test("Toggling off a completed record with a note keeps the record as note-only")
    func toggleOffWithNoteKeepsRecord() throws {
        let habit = HabitRecord(name: "Meditate", frequency: .daily, type: .binary)
        container.mainContext.insert(habit)
        let withNote = CompletionRecord(date: TestCalendar.day(0), value: 1, note: "Morning session", habit: habit)
        container.mainContext.insert(withNote)
        try container.mainContext.save()

        let toggler = CompletionToggler(calendar: TestCalendar.utc)
        let result = toggler.toggleToday(for: habit, on: TestCalendar.day(0), in: container.mainContext)
        try container.mainContext.save()

        #expect(result == .uncompleted)
        #expect(habit.completions?.count == 1)
        #expect(habit.completions?.first?.value == 0)
        #expect(habit.completions?.first?.note == "Morning session")
    }

    @Test("Toggling off a completed record without a note deletes it")
    func toggleOffWithoutNoteDeletes() throws {
        let habit = HabitRecord(name: "Meditate", frequency: .daily, type: .binary)
        container.mainContext.insert(habit)
        let noNote = CompletionRecord(date: TestCalendar.day(0), value: 1, habit: habit)
        container.mainContext.insert(noNote)
        try container.mainContext.save()

        let toggler = CompletionToggler(calendar: TestCalendar.utc)
        toggler.toggleToday(for: habit, on: TestCalendar.day(0), in: container.mainContext)
        try container.mainContext.save()

        #expect(habit.completions?.isEmpty ?? true)
    }
}
