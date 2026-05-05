import Foundation
import SwiftData
import Testing
@testable import Kado
import KadoCore

@Suite("HabitSortOrder")
@MainActor
struct HabitSortOrderTests {
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: KadoSchemaV4.self)
        return try ModelContainer(
            for: schema,
            migrationPlan: KadoMigrationPlan.self,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        )
    }

    @Test("nextSortOrder returns 0 when no habits exist")
    func nextSortOrderEmpty() throws {
        let container = try makeContainer()
        let result = HabitSortOrder.nextSortOrder(in: container.mainContext)
        #expect(result == 0)
    }

    @Test("nextSortOrder returns max + 1")
    func nextSortOrderIncrement() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let h1 = HabitRecord(name: "A", sortOrder: 0)
        let h2 = HabitRecord(name: "B", sortOrder: 5)
        let h3 = HabitRecord(name: "C", sortOrder: 3)
        ctx.insert(h1)
        ctx.insert(h2)
        ctx.insert(h3)
        try ctx.save()

        let result = HabitSortOrder.nextSortOrder(in: ctx)
        #expect(result == 6)
    }

    @Test("nextSortOrder ignores archived habits")
    func nextSortOrderIgnoresArchived() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let h1 = HabitRecord(name: "Active", sortOrder: 2)
        let h2 = HabitRecord(name: "Archived", archivedAt: .now, sortOrder: 10)
        ctx.insert(h1)
        ctx.insert(h2)
        try ctx.save()

        let result = HabitSortOrder.nextSortOrder(in: ctx)
        #expect(result == 3)
    }

    @Test("Moving habit from index 2 to 0 renumbers correctly")
    func moveUp() {
        var orders = [0, 1, 2, 3, 4]
        HabitSortOrder.reorder(&orders, from: IndexSet(integer: 2), to: 0)
        #expect(orders == [2, 0, 1, 3, 4])
    }

    @Test("Moving habit from index 0 to 2 renumbers correctly")
    func moveDown() {
        var orders = [0, 1, 2, 3, 4]
        HabitSortOrder.reorder(&orders, from: IndexSet(integer: 0), to: 2)
        #expect(orders == [1, 0, 2, 3, 4])
    }

    @Test("Moving habit to same position is a no-op")
    func moveNoOp() {
        var orders = [0, 1, 2]
        HabitSortOrder.reorder(&orders, from: IndexSet(integer: 1), to: 1)
        #expect(orders == [0, 1, 2])
    }

    @Test("Moving last habit to first position")
    func moveLastToFirst() {
        var orders = [0, 1, 2, 3]
        HabitSortOrder.reorder(&orders, from: IndexSet(integer: 3), to: 0)
        #expect(orders == [3, 0, 1, 2])
    }
}
