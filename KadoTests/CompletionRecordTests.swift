import Testing
import Foundation
import SwiftData
@testable import Kado

@Suite("CompletionRecord")
@MainActor
struct CompletionRecordTests {
    let container: ModelContainer

    init() throws {
        container = try ModelContainer(
            for: HabitRecord.self, CompletionRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @Test("Snapshot projects fields and uses the parent's id as habitID")
    func snapshotUsesParentID() {
        let habit = HabitRecord(name: "X", frequency: .daily, type: .binary)
        container.mainContext.insert(habit)
        let completion = CompletionRecord(
            id: UUID(),
            date: .now,
            value: 0.75,
            note: "test",
            habit: habit
        )
        container.mainContext.insert(completion)

        let snapshot = completion.snapshot
        #expect(snapshot.id == completion.id)
        #expect(snapshot.habitID == habit.id)
        #expect(snapshot.value == 0.75)
        #expect(snapshot.note == "test")
    }

    @Test("Default-initialized CompletionRecord has CloudKit-compatible shape")
    func cloudKitDefaults() {
        let record = CompletionRecord()
        #expect(record.value == 1.0)
        #expect(record.note == nil)
        #expect(record.habit == nil)
    }
}
