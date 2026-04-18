import Foundation
import SwiftData
import Testing
@testable import Kado
import KadoCore

@Suite("WidgetSnapshotBuilder")
@MainActor
struct WidgetSnapshotBuilderTests {
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: KadoSchemaV3.self)
        return try ModelContainer(
            for: schema,
            migrationPlan: KadoMigrationPlan.self,
            configurations: ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true
            )
        )
    }

    @Test("Empty container produces an empty snapshot")
    func emptyContainerEmptySnapshot() throws {
        let container = try makeContainer()
        let snapshot = WidgetSnapshotBuilder.build(from: container.mainContext)
        #expect(snapshot.habits.isEmpty)
        #expect(snapshot.today.isEmpty)
        #expect(snapshot.totalDueToday == 0)
        #expect(snapshot.completedToday == 0)
        #expect(snapshot.matrix.isEmpty)
    }

    @Test("Archived habits are excluded from habits, today, and matrix")
    func archivedExcluded() throws {
        let container = try makeContainer()
        let active = HabitRecord(name: "Active", frequency: .daily, type: .binary)
        let archived = HabitRecord(
            name: "Archived",
            frequency: .daily,
            type: .binary,
            archivedAt: .now
        )
        container.mainContext.insert(active)
        container.mainContext.insert(archived)
        try container.mainContext.save()

        let snapshot = WidgetSnapshotBuilder.build(from: container.mainContext)
        #expect(snapshot.habits.map(\.name) == ["Active"])
        #expect(snapshot.today.map(\.habit.name) == ["Active"])
        #expect(snapshot.matrix.map(\.habit.name) == ["Active"])
    }

    @Test("completedToday counts habits with status == .complete")
    func completedCount() throws {
        let container = try makeContainer()
        let a = HabitRecord(name: "A", frequency: .daily, type: .binary)
        let b = HabitRecord(name: "B", frequency: .daily, type: .binary)
        container.mainContext.insert(a)
        container.mainContext.insert(b)
        container.mainContext.insert(CompletionRecord(date: .now, value: 1, habit: a))
        try container.mainContext.save()

        let snapshot = WidgetSnapshotBuilder.build(from: container.mainContext)
        #expect(snapshot.totalDueToday == 2)
        #expect(snapshot.completedToday == 1)
    }

    @Test("Counter target is preserved in the widget habit")
    func counterTargetPreserved() throws {
        let container = try makeContainer()
        let habit = HabitRecord(
            name: "Water",
            frequency: .daily,
            type: .counter(target: 8)
        )
        container.mainContext.insert(habit)
        try container.mainContext.save()

        let snapshot = WidgetSnapshotBuilder.build(from: container.mainContext)
        let row = try #require(snapshot.today.first)
        #expect(row.habit.typeKind == .counter)
        #expect(row.habit.target == 8)
    }

    @Test("Matrix spans the configured day window")
    func matrixWindow() throws {
        let container = try makeContainer()
        container.mainContext.insert(
            HabitRecord(name: "A", frequency: .daily, type: .binary)
        )
        try container.mainContext.save()

        let snapshot = WidgetSnapshotBuilder.build(
            from: container.mainContext,
            matrixWindowDays: 5
        )
        #expect(snapshot.matrixDays.count == 5)
        #expect(snapshot.matrix.first?.cells.count == 5)
    }
}
