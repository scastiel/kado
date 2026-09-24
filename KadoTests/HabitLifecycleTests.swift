import Foundation
import SwiftData
import Testing
@testable import Kado
import KadoCore

/// `HabitLifecycle` owns the three writes that move a habit between
/// active, archived and gone. The first two are one assignment each;
/// the third leans on the schema's cascade rule, which is exactly the
/// kind of thing that silently stops holding when a schema version is
/// copied forward — so it is pinned here behaviourally, not just by
/// `CloudKitShapeTests` reading the relationship's metadata.
@Suite("HabitLifecycle")
@MainActor
struct HabitLifecycleTests {
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: KadoSchemaV4.self)
        return try ModelContainer(
            for: schema,
            migrationPlan: KadoMigrationPlan.self,
            configurations: ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true
            )
        )
    }

    /// A habit with `count` completions, inserted and saved.
    private func insertHabit(
        named name: String,
        completions count: Int,
        archivedAt: Date? = nil,
        into context: ModelContext
    ) throws -> HabitRecord {
        let habit = HabitRecord(name: name, archivedAt: archivedAt)
        context.insert(habit)
        for daysAgo in 0..<count {
            let date = Date(timeIntervalSince1970: 1_700_000_000 - Double(daysAgo) * 86_400)
            context.insert(CompletionRecord(date: date, value: 1, habit: habit))
        }
        try context.save()
        return habit
    }

    private func completionCount(in context: ModelContext) throws -> Int {
        try context.fetchCount(FetchDescriptor<CompletionRecord>())
    }

    @Test("archive stamps archivedAt with the given instant")
    func archiveStampsInstant() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let habit = try insertHabit(named: "Meditate", completions: 2, into: context)
        let instant = Date(timeIntervalSince1970: 1_700_100_000)

        HabitLifecycle().archive(habit, at: instant, in: context)

        let fetched = try context.fetch(FetchDescriptor<HabitRecord>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.archivedAt == instant)
        // Archiving keeps the history — that is the whole promise.
        #expect(try completionCount(in: context) == 2)
    }

    @Test("unarchive clears archivedAt and keeps the history")
    func unarchiveClearsInstant() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let habit = try insertHabit(
            named: "Meditate",
            completions: 3,
            archivedAt: Date(timeIntervalSince1970: 1_700_100_000),
            into: context
        )

        HabitLifecycle().unarchive(habit, in: context)

        let fetched = try context.fetch(FetchDescriptor<HabitRecord>())
        #expect(fetched.first?.archivedAt == nil)
        #expect(try completionCount(in: context) == 3)
    }

    @Test("delete removes the habit and cascades its completions")
    func deleteCascades() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let habit = try insertHabit(
            named: "Mistake",
            completions: 4,
            archivedAt: .now,
            into: context
        )
        #expect(try completionCount(in: context) == 4)

        HabitLifecycle().delete(habit, in: context)

        #expect(try context.fetchCount(FetchDescriptor<HabitRecord>()) == 0)
        #expect(try completionCount(in: context) == 0)
    }

    @Test("delete leaves other habits and their completions alone")
    func deleteIsScopedToOneHabit() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let doomed = try insertHabit(named: "Mistake", completions: 2, archivedAt: .now, into: context)
        let kept = try insertHabit(named: "Keep", completions: 5, into: context)

        HabitLifecycle().delete(doomed, in: context)

        let habits = try context.fetch(FetchDescriptor<HabitRecord>())
        #expect(habits.map(\.id) == [kept.id])
        #expect(try completionCount(in: context) == 5)
        #expect(habits.first?.completions?.count == 5)
    }

    @Test("archive then unarchive round-trips to an active habit")
    func archiveUnarchiveRoundTrip() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let habit = try insertHabit(named: "Pause", completions: 1, into: context)
        let lifecycle = HabitLifecycle()

        lifecycle.archive(habit, at: .now, in: context)
        #expect(habit.archivedAt != nil)
        lifecycle.unarchive(habit, in: context)

        // Back in the active set the lists and the scheduler read.
        let active = try context.fetch(
            FetchDescriptor<HabitRecord>(predicate: #Predicate { $0.archivedAt == nil })
        )
        #expect(active.map(\.id) == [habit.id])
    }
}
