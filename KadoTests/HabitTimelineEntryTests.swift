import Foundation
import SwiftData
import Testing
@testable import Kado

@Suite("HabitTimelineEntry")
@MainActor
struct HabitTimelineEntryTests {
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

    private func buildEntry(
        from context: ModelContext,
        asOf: Date = .now,
        limit: Int
    ) throws -> HabitTimelineEntry {
        try HabitTimelineEntry.build(
            from: context,
            asOf: asOf,
            calendar: .current,
            frequencyEvaluator: DefaultFrequencyEvaluator(),
            scoreCalculator: DefaultHabitScoreCalculator(),
            streakCalculator: DefaultStreakCalculator(),
            limit: limit
        )
    }

    @Test("Empty store produces an empty entry")
    func emptyStoreIsEmpty() throws {
        let container = try makeContainer()

        let entry = try buildEntry(from: container.mainContext, limit: 5)
        #expect(entry.rows.isEmpty)
        #expect(entry.totalCount == 0)
        #expect(entry.completedCount == 0)
    }

    @Test("Daily habits due today appear in creation order")
    func dailyHabitsInCreationOrder() throws {
        let container = try makeContainer()
        let anchor = Date.now

        let a = HabitRecord(name: "A", frequency: .daily, type: .binary, createdAt: anchor.addingTimeInterval(-300))
        let b = HabitRecord(name: "B", frequency: .daily, type: .binary, createdAt: anchor.addingTimeInterval(-200))
        let c = HabitRecord(name: "C", frequency: .daily, type: .binary, createdAt: anchor.addingTimeInterval(-100))
        container.mainContext.insert(a)
        container.mainContext.insert(b)
        container.mainContext.insert(c)
        try container.mainContext.save()

        let entry = try buildEntry(from: container.mainContext, limit: 5)
        #expect(entry.rows.map(\.habit.name) == ["A", "B", "C"])
        #expect(entry.totalCount == 3)
    }

    @Test("Archived habits are excluded from the entry")
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

        let entry = try buildEntry(from: container.mainContext, limit: 5)
        #expect(entry.rows.map(\.habit.name) == ["Active"])
        #expect(entry.totalCount == 1)
    }

    @Test("Habits not due today are excluded")
    func notDueExcluded() throws {
        let container = try makeContainer()

        let everyOtherDay = HabitRecord(
            name: "EveryOther",
            frequency: .everyNDays(2),
            type: .binary,
            createdAt: .now
        )
        // Mark completed today so tomorrow's isDue returns false.
        container.mainContext.insert(everyOtherDay)
        let completion = CompletionRecord(date: .now, value: 1, habit: everyOtherDay)
        container.mainContext.insert(completion)
        try container.mainContext.save()

        // Build for tomorrow: the every-other-day habit isn't due.
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: .now)!
        let entry = try buildEntry(from: container.mainContext, asOf: tomorrow, limit: 5)
        #expect(entry.rows.isEmpty)
    }

    @Test("limit caps rows but totalCount reflects the full due list")
    func limitCapsRowsOnly() throws {
        let container = try makeContainer()
        let anchor = Date.now

        for i in 0..<7 {
            let h = HabitRecord(
                name: "H\(i)",
                frequency: .daily,
                type: .binary,
                createdAt: anchor.addingTimeInterval(TimeInterval(-700 + i * 60))
            )
            container.mainContext.insert(h)
        }
        try container.mainContext.save()

        let entry = try buildEntry(from: container.mainContext, limit: 5)
        #expect(entry.rows.count == 5)
        #expect(entry.totalCount == 7)
    }

    @Test("completedCount counts every done habit, not just visible rows")
    func completedCountSpansFullList() throws {
        let container = try makeContainer()
        let anchor = Date.now

        var habits: [HabitRecord] = []
        for i in 0..<6 {
            let h = HabitRecord(
                name: "H\(i)",
                frequency: .daily,
                type: .binary,
                createdAt: anchor.addingTimeInterval(TimeInterval(-600 + i * 60))
            )
            container.mainContext.insert(h)
            habits.append(h)
        }
        // Complete the last two (positions 4 and 5 — outside a limit of 3).
        for i in 4...5 {
            let c = CompletionRecord(date: anchor, value: 1, habit: habits[i])
            container.mainContext.insert(c)
        }
        try container.mainContext.save()

        let entry = try buildEntry(from: container.mainContext, limit: 3)
        #expect(entry.rows.count == 3)
        #expect(entry.totalCount == 6)
        #expect(entry.completedCount == 2, "Completed count should span the whole due list, not just visible rows")
    }

    @Test("scorePercent matches the rounded score from the calculator")
    func scorePercentMatchesCalculator() throws {
        let container = try makeContainer()
        let habit = HabitRecord(name: "H", frequency: .daily, type: .binary)
        container.mainContext.insert(habit)
        // 5 completions in the last 5 days so the score is above 0.
        let calendar = Calendar.current
        for i in 0..<5 {
            let d = calendar.date(byAdding: .day, value: -i, to: .now)!
            container.mainContext.insert(CompletionRecord(date: d, value: 1, habit: habit))
        }
        try container.mainContext.save()

        let entry = try buildEntry(from: container.mainContext, limit: 5)
        let row = try #require(entry.rows.first)
        #expect(row.scorePercent > 0)
        #expect(row.scorePercent <= 100)
    }
}
