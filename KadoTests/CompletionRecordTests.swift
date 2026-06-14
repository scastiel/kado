import Testing
import Foundation
import SwiftData
@testable import Kado
import KadoCore

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
    func snapshotUsesParentID() throws {
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

        let snapshot = try #require(completion.snapshot)
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

    // Regression for the iPad-on-load crash (issue #54): a CloudKit
    // import delivers a CompletionRecord before its parent HabitRecord,
    // so the optional `habit` inverse is transiently nil. `snapshot`
    // used to force-unwrap `habit!`, trapping with EXC_BREAKPOINT the
    // moment any view mapped over it. It must instead yield nil.
    @Test("Snapshot is nil when the habit relationship is nil (mid-import / orphan)")
    func snapshotNilWhenOrphaned() {
        let orphan = CompletionRecord(date: .now, value: 1.0, habit: nil)
        container.mainContext.insert(orphan)
        #expect(orphan.snapshot == nil)
    }

    @Test("compactMap over mixed attached + orphaned completions drops orphans, no crash")
    func compactMapDropsOrphans() {
        let habit = HabitRecord(name: "X", frequency: .daily, type: .binary)
        container.mainContext.insert(habit)
        let attached = CompletionRecord(date: .now, value: 1.0, habit: habit)
        let orphan = CompletionRecord(date: .now, value: 1.0, habit: nil)
        container.mainContext.insert(attached)
        container.mainContext.insert(orphan)

        let snapshots = [attached, orphan].compactMap(\.snapshot)
        #expect(snapshots.count == 1)
        #expect(snapshots.first?.id == attached.id)
    }
}
