import Testing
import Foundation
import SwiftData
@testable import Kado

@Suite("HabitRecord")
@MainActor
struct HabitRecordTests {
    let container: ModelContainer

    init() throws {
        container = try ModelContainer(
            for: HabitRecord.self, CompletionRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @Test("Snapshot projects all fields back to a value-type Habit")
    func snapshotProjection() {
        let id = UUID()
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let record = HabitRecord(
            id: id,
            name: "Run",
            frequency: .specificDays([.monday, .friday]),
            type: .counter(target: 5),
            createdAt: createdAt
        )
        container.mainContext.insert(record)

        let expected = Habit(
            id: id,
            name: "Run",
            frequency: .specificDays([.monday, .friday]),
            type: .counter(target: 5),
            createdAt: createdAt
        )
        #expect(record.snapshot == expected)
    }

    @Test("frequency setter round-trips through the JSON-Data backing")
    func frequencyRoundTrip() {
        let record = HabitRecord(frequency: .everyNDays(3))
        #expect(record.frequency == .everyNDays(3))
        record.frequency = .daysPerWeek(5)
        #expect(record.frequency == .daysPerWeek(5))
    }

    @Test("type setter round-trips through the JSON-Data backing")
    func typeRoundTrip() {
        let record = HabitRecord(type: .counter(target: 8))
        #expect(record.type == .counter(target: 8))
        record.type = .timer(targetSeconds: 1800)
        #expect(record.type == .timer(targetSeconds: 1800))
    }

    @Test("Default-initialized HabitRecord has CloudKit-compatible shape")
    func cloudKitDefaults() {
        let record = HabitRecord()
        #expect(record.name == "")
        #expect(record.frequency == .daily)
        #expect(record.type == .binary)
        #expect(record.archivedAt == nil)
        #expect(record.completions.isEmpty)
    }

    @Test("Cascade delete removes child completions from the context")
    func cascadeDelete() throws {
        let habit = HabitRecord(name: "Stretch", frequency: .daily, type: .binary)
        container.mainContext.insert(habit)
        let completion = CompletionRecord(date: .now, value: 1, habit: habit)
        container.mainContext.insert(completion)
        try container.mainContext.save()

        container.mainContext.delete(habit)
        try container.mainContext.save()

        let remaining = try container.mainContext.fetch(FetchDescriptor<CompletionRecord>())
        #expect(remaining.isEmpty)
    }

    @Test("Setting completion.habit populates habit.completions (inverse)")
    func inverseRelationship() throws {
        let habit = HabitRecord(name: "Read", frequency: .daily, type: .binary)
        container.mainContext.insert(habit)
        let completion = CompletionRecord(date: .now, value: 1)
        container.mainContext.insert(completion)
        completion.habit = habit
        try container.mainContext.save()

        #expect(habit.completions.count == 1)
        #expect(habit.completions.first?.id == completion.id)
    }
}
