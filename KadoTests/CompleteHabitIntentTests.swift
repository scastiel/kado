import Foundation
import SwiftData
import Testing
@testable import Kado
import KadoCore

@Suite("CompleteHabitIntent")
@MainActor
struct CompleteHabitIntentTests {
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

    private func insert(
        _ habit: HabitRecord,
        into container: ModelContainer
    ) throws {
        container.mainContext.insert(habit)
        try container.mainContext.save()
    }

    @Test("Completes a binary habit due today")
    func togglesBinary() throws {
        let container = try makeContainer()
        let habit = HabitRecord(name: "Meditate", frequency: .daily, type: .binary)
        try insert(habit, into: container)

        let outcome = try CompleteHabitIntent.apply(
            habitID: habit.id,
            in: container.mainContext,
            calendar: .current,
            now: .now
        )

        #expect(outcome == .toggled)
        let completions = try container.mainContext.fetch(
            FetchDescriptor<CompletionRecord>()
        )
        #expect(completions.count == 1)
        #expect(completions.first?.habit?.id == habit.id)
    }

    @Test("Repeat tap toggles the completion off (never creates a duplicate)")
    func repeatTapTogglesOff() throws {
        let container = try makeContainer()
        let habit = HabitRecord(name: "Stretch", frequency: .daily, type: .binary)
        try insert(habit, into: container)

        _ = try CompleteHabitIntent.apply(
            habitID: habit.id,
            in: container.mainContext,
            calendar: .current,
            now: .now
        )
        _ = try CompleteHabitIntent.apply(
            habitID: habit.id,
            in: container.mainContext,
            calendar: .current,
            now: .now
        )

        let completions = try container.mainContext.fetch(
            FetchDescriptor<CompletionRecord>()
        )
        #expect(completions.isEmpty, "Second tap must undo, not duplicate")
    }

    @Test("Counter habit returns opensApp and writes nothing")
    func counterOpensApp() throws {
        let container = try makeContainer()
        let habit = HabitRecord(
            name: "Water",
            frequency: .daily,
            type: .counter(target: 8)
        )
        try insert(habit, into: container)

        let outcome = try CompleteHabitIntent.apply(
            habitID: habit.id,
            in: container.mainContext,
            calendar: .current,
            now: .now
        )

        #expect(outcome == .opensApp)
        let completions = try container.mainContext.fetch(
            FetchDescriptor<CompletionRecord>()
        )
        #expect(completions.isEmpty)
    }

    @Test("Timer habit returns opensApp and writes nothing")
    func timerOpensApp() throws {
        let container = try makeContainer()
        let habit = HabitRecord(
            name: "Read",
            frequency: .daily,
            type: .timer(targetSeconds: 25 * 60)
        )
        try insert(habit, into: container)

        let outcome = try CompleteHabitIntent.apply(
            habitID: habit.id,
            in: container.mainContext,
            calendar: .current,
            now: .now
        )

        #expect(outcome == .opensApp)
    }

    @Test("Negative habit toggles like a binary (tap = logged slip)")
    func negativeToggles() throws {
        let container = try makeContainer()
        let habit = HabitRecord(name: "No snack", frequency: .daily, type: .negative)
        try insert(habit, into: container)

        let outcome = try CompleteHabitIntent.apply(
            habitID: habit.id,
            in: container.mainContext,
            calendar: .current,
            now: .now
        )

        #expect(outcome == .toggled)
    }

    @Test("Unknown habit ID throws habitNotFound")
    func unknownHabitThrows() throws {
        let container = try makeContainer()
        let phantom = UUID()

        #expect(throws: CompleteHabitIntent.IntentError.self) {
            _ = try CompleteHabitIntent.apply(
                habitID: phantom,
                in: container.mainContext,
                calendar: .current,
                now: .now
            )
        }
    }

    @Test("Archived habit is refused")
    func archivedHabitThrows() throws {
        let container = try makeContainer()
        let habit = HabitRecord(
            name: "Past",
            frequency: .daily,
            type: .binary,
            archivedAt: .now
        )
        try insert(habit, into: container)

        #expect(throws: CompleteHabitIntent.IntentError.self) {
            _ = try CompleteHabitIntent.apply(
                habitID: habit.id,
                in: container.mainContext,
                calendar: .current,
                now: .now
            )
        }
    }

}
