import Foundation
import SwiftData
import Testing
@testable import Kado
import KadoCore

/// Regression coverage for issue #63: the Today list must hold value
/// types, not managed objects. A dev-mode `ModelContainer` swap
/// invalidates every `HabitRecord` the previous store vended, and
/// `ForEach` re-reads its retained data during the next list diff —
/// so anything the list keeps has to stay readable once the records
/// behind it are gone.
@Suite("TodayRow")
@MainActor
struct TodayRowTests {
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: KadoSchemaV4.self)
        return try ModelContainer(
            for: schema,
            migrationPlan: KadoMigrationPlan.self,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        )
    }

    private let calendar = TestCalendar.utc
    private let evaluator = DefaultFrequencyEvaluator()

    /// 2026-03-11, a Wednesday.
    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 3, day: 11, hour: 12))!
    }

    @Test("Rows stay readable after their records are deleted")
    func rowsSurviveRecordDeletion() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let habit = HabitRecord(
            name: "Meditate",
            frequency: .daily,
            type: .binary,
            createdAt: calendar.date(byAdding: .day, value: -10, to: now)!,
            sortOrder: 0
        )
        ctx.insert(habit)
        ctx.insert(CompletionRecord(date: now, value: 1, habit: habit))
        try ctx.save()

        let (due, _) = TodayRow.sections(
            from: try ctx.fetch(FetchDescriptor<HabitRecord>()),
            on: now,
            evaluator: evaluator,
            calendar: calendar
        )
        let id = try #require(due.first).id

        // Stand-in for the container swap: the records the rows came
        // from are gone, but the rows themselves must still answer.
        for record in try ctx.fetch(FetchDescriptor<HabitRecord>()) {
            ctx.delete(record)
        }
        try ctx.save()

        let row = try #require(due.first)
        #expect(row.id == id)
        #expect(row.habit.name == "Meditate")
        #expect(row.completions.count == 1)
    }

    @Test("Row id is the habit id, which is what ForEach diffs on")
    func rowIDIsHabitID() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let habit = HabitRecord(name: "Read", frequency: .daily, type: .binary, createdAt: now)
        ctx.insert(habit)
        try ctx.save()

        let row = TodayRow(habit)
        #expect(row.id == habit.id)
    }

    @Test("Sections split habits the schedule asks for today from the rest")
    func sectionsSplitByDueness() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let createdAt = calendar.date(byAdding: .day, value: -30, to: now)!

        let daily = HabitRecord(
            name: "Daily", frequency: .daily, type: .binary, createdAt: createdAt, sortOrder: 0
        )
        // Wednesday is 2026-03-11; scheduling Monday only keeps this
        // one out of the due section.
        let mondayOnly = HabitRecord(
            name: "Mondays",
            frequency: .specificDays([.monday]),
            type: .binary,
            createdAt: createdAt,
            sortOrder: 1
        )
        ctx.insert(daily)
        ctx.insert(mondayOnly)
        try ctx.save()

        let (due, other) = TodayRow.sections(
            from: try ctx.fetch(
                FetchDescriptor<HabitRecord>(sortBy: [SortDescriptor(\.sortOrder)])
            ),
            on: now,
            evaluator: evaluator,
            calendar: calendar
        )

        #expect(due.map(\.habit.name) == ["Daily"])
        #expect(other.map(\.habit.name) == ["Mondays"])
    }

    @Test("A habit logged today stays in the due section even when off schedule")
    func loggedOffScheduleHabitStaysDue() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let mondayOnly = HabitRecord(
            name: "Mondays",
            frequency: .specificDays([.monday]),
            type: .binary,
            createdAt: calendar.date(byAdding: .day, value: -30, to: now)!
        )
        ctx.insert(mondayOnly)
        ctx.insert(CompletionRecord(date: now, value: 1, habit: mondayOnly))
        try ctx.save()

        let (due, other) = TodayRow.sections(
            from: try ctx.fetch(FetchDescriptor<HabitRecord>()),
            on: now,
            evaluator: evaluator,
            calendar: calendar
        )

        #expect(due.map(\.habit.name) == ["Mondays"])
        #expect(other.isEmpty)
    }
}
