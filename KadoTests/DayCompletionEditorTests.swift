import Testing
import Foundation
import SwiftData
@testable import Kado
import KadoCore

/// The day-edit popover's mutation path, shared by the detail calendar
/// and the Overview matrix. Each case pins two things: what the store
/// holds afterwards, and the `Change` the caller feeds into the haptic.
@Suite("DayCompletionEditor")
@MainActor
struct DayCompletionEditorTests {
    let container: ModelContainer
    let editor = DayCompletionEditor(calendar: TestCalendar.utc)
    /// A past day — the popover edits history, not just today.
    let day = TestCalendar.day(-2)

    init() throws {
        container = try ModelContainer(
            for: HabitRecord.self, CompletionRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private var context: ModelContext { container.mainContext }

    private func insert(_ habit: HabitRecord, completion: CompletionRecord? = nil) throws {
        context.insert(habit)
        if let completion { context.insert(completion) }
        try context.save()
    }

    private func completion(of habit: HabitRecord) -> CompletionRecord? {
        habit.completions?.first { TestCalendar.utc.isDate($0.date, inSameDayAs: day) }
    }

    // MARK: - Toggle

    @Test("toggle on an empty day inserts a unit completion and reports 0 → 1")
    func toggleInserts() throws {
        let habit = HabitRecord(type: .binary)
        try insert(habit)

        let change = editor.toggle(for: habit, on: day, in: context)

        #expect(change == DayCompletionEditor.Change(before: 0.0, after: 1.0))
        #expect(completion(of: habit)?.value == 1.0)
    }

    @Test("toggle on a completed day deletes the record and reports 1 → 0")
    func toggleDeletes() throws {
        let habit = HabitRecord(type: .binary)
        try insert(habit, completion: CompletionRecord(date: day, value: 1, habit: habit))

        let change = editor.toggle(for: habit, on: day, in: context)

        #expect(change == DayCompletionEditor.Change(before: 1.0, after: 0.0))
        #expect(habit.completions?.isEmpty ?? true)
    }

    @Test("toggle on a zero-value noted record marks it done and keeps the note")
    func toggleOnNotedZeroRecord() throws {
        let habit = HabitRecord(type: .binary)
        try insert(habit, completion: CompletionRecord(date: day, value: 0, note: "Sick", habit: habit))

        let change = editor.toggle(for: habit, on: day, in: context)

        #expect(change == DayCompletionEditor.Change(before: 0.0, after: 1.0))
        #expect(completion(of: habit)?.value == 1.0)
        #expect(completion(of: habit)?.note == "Sick")
    }

    @Test("toggle off a noted record zeroes it rather than deleting it")
    func toggleOffKeepsNotedRecord() throws {
        let habit = HabitRecord(type: .negative)
        try insert(habit, completion: CompletionRecord(date: day, value: 1, note: "Slipped", habit: habit))

        let change = editor.toggle(for: habit, on: day, in: context)

        #expect(change == DayCompletionEditor.Change(before: 1.0, after: 0.0))
        #expect(habit.completions?.count == 1)
        #expect(completion(of: habit)?.value == 0.0)
        #expect(completion(of: habit)?.note == "Slipped")
    }

    // MARK: - Counter

    @Test("setCounter on an empty day inserts the value and reports 0 → value")
    func setCounterInserts() throws {
        let habit = HabitRecord(type: .counter(target: 8))
        try insert(habit)

        let change = editor.setCounter(3, for: habit, on: day, in: context)

        #expect(change == DayCompletionEditor.Change(before: 0.0, after: 3.0))
        #expect(completion(of: habit)?.value == 3.0)
    }

    @Test("setCounter to 0 deletes the record and reports value → 0")
    func setCounterZeroDeletes() throws {
        let habit = HabitRecord(type: .counter(target: 8))
        try insert(habit, completion: CompletionRecord(date: day, value: 3, habit: habit))

        let change = editor.setCounter(0, for: habit, on: day, in: context)

        #expect(change == DayCompletionEditor.Change(before: 3.0, after: 0.0))
        #expect(habit.completions?.isEmpty ?? true)
    }

    @Test("setCounter to 0 keeps a noted record at zero")
    func setCounterZeroKeepsNote() throws {
        let habit = HabitRecord(type: .counter(target: 8))
        try insert(habit, completion: CompletionRecord(date: day, value: 3, note: "Only three", habit: habit))

        editor.setCounter(0, for: habit, on: day, in: context)

        #expect(habit.completions?.count == 1)
        #expect(completion(of: habit)?.value == 0.0)
        #expect(completion(of: habit)?.note == "Only three")
    }

    @Test("setCounter below zero reports an after value of 0, not the negative input")
    func setCounterNegativeClampsAfter() throws {
        let habit = HabitRecord(type: .counter(target: 8))
        try insert(habit, completion: CompletionRecord(date: day, value: 1, habit: habit))

        let change = editor.setCounter(-1, for: habit, on: day, in: context)

        #expect(change == DayCompletionEditor.Change(before: 1.0, after: 0.0))
        #expect(habit.completions?.isEmpty ?? true)
    }

    // MARK: - Timer

    @Test("setTimerSeconds on an empty day inserts the duration and reports 0 → seconds")
    func setTimerInserts() throws {
        let habit = HabitRecord(type: .timer(targetSeconds: 1800))
        try insert(habit)

        let change = editor.setTimerSeconds(600, for: habit, on: day, in: context)

        #expect(change == DayCompletionEditor.Change(before: 0.0, after: 600.0))
        #expect(completion(of: habit)?.value == 600.0)
    }

    @Test("setTimerSeconds to 0 on an empty day creates no zero-value record")
    func setTimerZeroOnEmptyDayInsertsNothing() throws {
        let habit = HabitRecord(type: .timer(targetSeconds: 1800))
        try insert(habit)

        let change = editor.setTimerSeconds(0, for: habit, on: day, in: context)

        #expect(change == DayCompletionEditor.Change(before: 0.0, after: 0.0))
        #expect(habit.completions?.isEmpty ?? true)
    }

    @Test("setTimerSeconds to 0 clears the day: deletes, or zeroes a noted record")
    func setTimerZeroClears() throws {
        let plain = HabitRecord(type: .timer(targetSeconds: 1800))
        try insert(plain, completion: CompletionRecord(date: day, value: 900, habit: plain))
        let noted = HabitRecord(type: .timer(targetSeconds: 1800))
        try insert(noted, completion: CompletionRecord(date: day, value: 900, note: "Short one", habit: noted))

        let plainChange = editor.setTimerSeconds(0, for: plain, on: day, in: context)
        let notedChange = editor.setTimerSeconds(0, for: noted, on: day, in: context)

        #expect(plainChange == DayCompletionEditor.Change(before: 900.0, after: 0.0))
        #expect(plain.completions?.isEmpty ?? true)
        #expect(notedChange == DayCompletionEditor.Change(before: 900.0, after: 0.0))
        #expect(completion(of: noted)?.value == 0.0)
        #expect(completion(of: noted)?.note == "Short one")
    }

    // MARK: - Clear

    @Test("clear deletes a note-less record and reports value → 0")
    func clearDeletes() throws {
        let habit = HabitRecord(type: .counter(target: 8))
        try insert(habit, completion: CompletionRecord(date: day, value: 5, habit: habit))

        let change = editor.clear(for: habit, on: day, in: context)

        #expect(change == DayCompletionEditor.Change(before: 5.0, after: 0.0))
        #expect(habit.completions?.isEmpty ?? true)
    }

    @Test("clear zeroes a noted record and keeps the note")
    func clearKeepsNote() throws {
        let habit = HabitRecord(type: .counter(target: 8))
        try insert(habit, completion: CompletionRecord(date: day, value: 5, note: "Keep", habit: habit))

        editor.clear(for: habit, on: day, in: context)

        #expect(habit.completions?.count == 1)
        #expect(completion(of: habit)?.value == 0.0)
        #expect(completion(of: habit)?.note == "Keep")
    }

    @Test("clear on an empty day inserts nothing and reports 0 → 0")
    func clearOnEmptyDay() throws {
        let habit = HabitRecord(type: .binary)
        try insert(habit)

        let change = editor.clear(for: habit, on: day, in: context)

        #expect(change == DayCompletionEditor.Change(before: 0.0, after: 0.0))
        #expect(habit.completions?.isEmpty ?? true)
    }

    // MARK: - Note

    @Test("setNote on an empty day creates a zero-value record holding the note")
    func setNoteCreatesRecord() throws {
        let habit = HabitRecord(type: .binary)
        try insert(habit)

        editor.setNote("Travelling", for: habit, on: day, in: context)

        #expect(completion(of: habit)?.value == 0.0)
        #expect(completion(of: habit)?.note == "Travelling")
    }

    @Test("setNote to nil on a zero-value record deletes it")
    func setNoteNilDeletesStandaloneRecord() throws {
        let habit = HabitRecord(type: .binary)
        try insert(habit, completion: CompletionRecord(date: day, value: 0, note: "Travelling", habit: habit))

        editor.setNote(nil, for: habit, on: day, in: context)

        #expect(habit.completions?.isEmpty ?? true)
    }

    @Test("setNote on a valued record keeps the value")
    func setNoteKeepsValue() throws {
        let habit = HabitRecord(type: .counter(target: 8))
        try insert(habit, completion: CompletionRecord(date: day, value: 4, habit: habit))

        editor.setNote("Half", for: habit, on: day, in: context)

        #expect(completion(of: habit)?.value == 4.0)
        #expect(completion(of: habit)?.note == "Half")
    }

    // MARK: - Persistence

    @Test("Every mutation saves — the context has no pending changes afterwards")
    func editorSaves() throws {
        let habit = HabitRecord(type: .counter(target: 8))
        try insert(habit)

        editor.setCounter(2, for: habit, on: day, in: context)
        #expect(context.hasChanges == false)

        editor.setNote("Two", for: habit, on: day, in: context)
        #expect(context.hasChanges == false)

        editor.toggle(for: habit, on: day, in: context)
        #expect(context.hasChanges == false)

        editor.setTimerSeconds(30, for: habit, on: day, in: context)
        #expect(context.hasChanges == false)

        editor.clear(for: habit, on: day, in: context)
        #expect(context.hasChanges == false)
    }

    @Test("A mutation on one day leaves the neighbouring days alone")
    func otherDaysUntouched() throws {
        let habit = HabitRecord(type: .counter(target: 8))
        try insert(habit)
        let before = CompletionRecord(date: TestCalendar.day(-3), value: 1, habit: habit)
        let after = CompletionRecord(date: TestCalendar.day(-1), value: 2, habit: habit)
        context.insert(before)
        context.insert(after)
        try context.save()

        editor.setCounter(7, for: habit, on: day, in: context)
        editor.clear(for: habit, on: day, in: context)

        let values = Dictionary(
            uniqueKeysWithValues: (habit.completions ?? []).map {
                (TestCalendar.utc.startOfDay(for: $0.date), $0.value)
            }
        )
        #expect(values[TestCalendar.utc.startOfDay(for: TestCalendar.day(-3))] == 1.0)
        #expect(values[TestCalendar.utc.startOfDay(for: TestCalendar.day(-1))] == 2.0)
        #expect(values[TestCalendar.utc.startOfDay(for: day)] == nil)
    }
}
