import Foundation
import SwiftData
import Testing
@testable import Kado

@Suite("PickedHabitEntry")
@MainActor
struct PickedHabitEntryTests {
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: KadoSchemaV2.self)
        return try ModelContainer(
            for: schema,
            migrationPlan: KadoMigrationPlan.self,
            configurations: ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true
            )
        )
    }

    private func build(
        for habitID: UUID?,
        in context: ModelContext,
        asOf: Date = .now
    ) throws -> PickedHabitEntry {
        try PickedHabitEntry.build(
            for: habitID,
            from: context,
            asOf: asOf,
            calendar: .current,
            scoreCalculator: DefaultHabitScoreCalculator(),
            streakCalculator: DefaultStreakCalculator()
        )
    }

    @Test("Nil habit id returns an empty entry")
    func nilHabitReturnsEmpty() throws {
        let container = try makeContainer()
        let entry = try build(for: nil, in: container.mainContext)
        #expect(entry.habit == nil)
        #expect(entry.state == nil)
    }

    @Test("Unknown habit id returns an empty entry")
    func unknownHabitReturnsEmpty() throws {
        let container = try makeContainer()
        let entry = try build(for: UUID(), in: container.mainContext)
        #expect(entry.habit == nil)
    }

    @Test("Archived habit returns an empty entry")
    func archivedHabitReturnsEmpty() throws {
        let container = try makeContainer()
        let habit = HabitRecord(
            name: "Gone",
            frequency: .daily,
            type: .binary,
            archivedAt: .now
        )
        container.mainContext.insert(habit)
        try container.mainContext.save()

        let entry = try build(for: habit.id, in: container.mainContext)
        #expect(entry.habit == nil)
    }

    @Test("Known habit populates name, state, streak, score")
    func knownHabitPopulates() throws {
        let container = try makeContainer()
        let habit = HabitRecord(name: "Meditate", frequency: .daily, type: .binary)
        container.mainContext.insert(habit)
        container.mainContext.insert(CompletionRecord(date: .now, value: 1, habit: habit))
        try container.mainContext.save()

        let entry = try build(for: habit.id, in: container.mainContext)
        #expect(entry.habit?.name == "Meditate")
        #expect(entry.state?.status == .complete)
        #expect((entry.streak ?? 0) >= 1)
        #expect((entry.scorePercent ?? 0) >= 0)
    }
}
