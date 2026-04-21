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

    // MARK: - Per-habit stats on WidgetHabit

    @Test("Snapshot exposes current streak on every habit")
    func habitCurrentStreak() throws {
        let container = try makeContainer()
        let calendar = TestCalendar.utc
        let today = TestCalendar.day(0)
        let habit = HabitRecord(
            name: "Meditate",
            frequency: .daily,
            type: .binary,
            createdAt: TestCalendar.day(-10)
        )
        container.mainContext.insert(habit)
        // Three consecutive days ending today.
        for offset in 0...2 {
            container.mainContext.insert(
                CompletionRecord(date: TestCalendar.day(-offset), value: 1, habit: habit)
            )
        }
        try container.mainContext.save()

        let snapshot = WidgetSnapshotBuilder.build(
            from: container.mainContext,
            asOf: today,
            calendar: calendar
        )
        let widgetHabit = try #require(snapshot.habits.first)
        #expect(widgetHabit.currentStreak == 3)
    }

    @Test("Snapshot exposes best streak across history")
    func habitBestStreak() throws {
        let container = try makeContainer()
        let calendar = TestCalendar.utc
        let today = TestCalendar.day(0)
        let habit = HabitRecord(
            name: "Stretch",
            frequency: .daily,
            type: .binary,
            createdAt: TestCalendar.day(-30)
        )
        container.mainContext.insert(habit)
        // Five-day streak in the past, then a gap, then one today.
        for offset in (10...14).reversed() {
            container.mainContext.insert(
                CompletionRecord(date: TestCalendar.day(-offset), value: 1, habit: habit)
            )
        }
        container.mainContext.insert(
            CompletionRecord(date: today, value: 1, habit: habit)
        )
        try container.mainContext.save()

        let snapshot = WidgetSnapshotBuilder.build(
            from: container.mainContext,
            asOf: today,
            calendar: calendar
        )
        let widgetHabit = try #require(snapshot.habits.first)
        #expect(widgetHabit.bestStreak == 5)
        #expect(widgetHabit.currentStreak == 1)
    }

    @Test("Snapshot exposes score as Double in [0, 1]")
    func habitScoreInRange() throws {
        let container = try makeContainer()
        let calendar = TestCalendar.utc
        let today = TestCalendar.day(0)
        let habit = HabitRecord(
            name: "Read",
            frequency: .daily,
            type: .binary,
            createdAt: TestCalendar.day(-20)
        )
        container.mainContext.insert(habit)
        // Ten perfect days — score should be high but ≤ 1.
        for offset in 0...9 {
            container.mainContext.insert(
                CompletionRecord(date: TestCalendar.day(-offset), value: 1, habit: habit)
            )
        }
        try container.mainContext.save()

        let snapshot = WidgetSnapshotBuilder.build(
            from: container.mainContext,
            asOf: today,
            calendar: calendar
        )
        let widgetHabit = try #require(snapshot.habits.first)
        #expect(widgetHabit.currentScore >= 0.0)
        #expect(widgetHabit.currentScore <= 1.0)
        #expect(widgetHabit.currentScore > 0.0, "any completions should push the score above zero")
    }

    @Test("Snapshot replicates stats into matrix and today nested habits")
    func statsReplicatedIntoNestedHabits() throws {
        let container = try makeContainer()
        let calendar = TestCalendar.utc
        let today = TestCalendar.day(0)
        let habit = HabitRecord(
            name: "Walk",
            frequency: .daily,
            type: .binary,
            createdAt: TestCalendar.day(-10)
        )
        container.mainContext.insert(habit)
        for offset in 0...4 {
            container.mainContext.insert(
                CompletionRecord(date: TestCalendar.day(-offset), value: 1, habit: habit)
            )
        }
        try container.mainContext.save()

        let snapshot = WidgetSnapshotBuilder.build(
            from: container.mainContext,
            asOf: today,
            calendar: calendar
        )
        let topLevel = try #require(snapshot.habits.first)
        let todayNested = try #require(snapshot.today.first?.habit)
        let matrixNested = try #require(snapshot.matrix.first?.habit)

        #expect(topLevel.currentStreak == todayNested.currentStreak)
        #expect(topLevel.currentStreak == matrixNested.currentStreak)
        #expect(topLevel.currentScore == matrixNested.currentScore)
    }
}
