import Foundation
import SwiftData
import Testing
@testable import Kado
import KadoCore

@Suite("LogHabitValueIntent")
@MainActor
struct LogHabitValueIntentTests {
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

    private func insert(_ habit: HabitRecord, into container: ModelContainer) throws {
        container.mainContext.insert(habit)
        try container.mainContext.save()
    }

    @Test("Logs a counter completion with the given value")
    func logsCounter() throws {
        let container = try makeContainer()
        let habit = HabitRecord(
            name: "Water",
            frequency: .daily,
            type: .counter(target: 8)
        )
        try insert(habit, into: container)

        let outcome = try LogHabitValueIntent.apply(
            habitID: habit.id,
            value: 3,
            in: container.mainContext,
            calendar: .current,
            now: .now
        )

        #expect(outcome == .logged(value: 3, kind: .counter))
        let completions = try container.mainContext.fetch(
            FetchDescriptor<CompletionRecord>()
        )
        #expect(completions.count == 1)
        #expect(completions.first?.value == 3)
    }

    @Test("Overwrites same-day counter completion")
    func overwritesSameDay() throws {
        let container = try makeContainer()
        let habit = HabitRecord(
            name: "Water",
            frequency: .daily,
            type: .counter(target: 8)
        )
        try insert(habit, into: container)

        _ = try LogHabitValueIntent.apply(
            habitID: habit.id,
            value: 2,
            in: container.mainContext,
            calendar: .current,
            now: .now
        )
        _ = try LogHabitValueIntent.apply(
            habitID: habit.id,
            value: 6,
            in: container.mainContext,
            calendar: .current,
            now: .now
        )

        let completions = try container.mainContext.fetch(
            FetchDescriptor<CompletionRecord>()
        )
        #expect(completions.count == 1, "Same-day logs must overwrite, not accumulate")
        #expect(completions.first?.value == 6)
    }

    @Test("Timer habit interprets value as minutes and stores seconds")
    func timerMinutesToSeconds() throws {
        let container = try makeContainer()
        let habit = HabitRecord(
            name: "Read",
            frequency: .daily,
            type: .timer(targetSeconds: 25 * 60)
        )
        try insert(habit, into: container)

        let outcome = try LogHabitValueIntent.apply(
            habitID: habit.id,
            value: 15,
            in: container.mainContext,
            calendar: .current,
            now: .now
        )

        #expect(outcome == .logged(value: 15, kind: .timer))
        let completions = try container.mainContext.fetch(
            FetchDescriptor<CompletionRecord>()
        )
        // Spoken "15 minutes" → 900 seconds on disk so graphing /
        // scoring stay consistent with manual timer completions.
        #expect(completions.first?.value == 900)
    }

    @Test("Binary habit is refused with wrongType(.binary)")
    func refusesBinary() throws {
        let container = try makeContainer()
        let habit = HabitRecord(name: "Meditate", frequency: .daily, type: .binary)
        try insert(habit, into: container)

        let outcome = try LogHabitValueIntent.apply(
            habitID: habit.id,
            value: 1,
            in: container.mainContext,
            calendar: .current,
            now: .now
        )

        #expect(outcome == .wrongType(kind: .binary))
        let completions = try container.mainContext.fetch(
            FetchDescriptor<CompletionRecord>()
        )
        #expect(completions.isEmpty, "Wrong-type refusal must not write anything")
    }

    @Test("Negative habit is refused with wrongType(.negative)")
    func refusesNegative() throws {
        let container = try makeContainer()
        let habit = HabitRecord(name: "No snack", frequency: .daily, type: .negative)
        try insert(habit, into: container)

        let outcome = try LogHabitValueIntent.apply(
            habitID: habit.id,
            value: 1,
            in: container.mainContext,
            calendar: .current,
            now: .now
        )

        #expect(outcome == .wrongType(kind: .negative))
    }

    @Test("Archived habit throws habitArchived")
    func archivedThrows() throws {
        let container = try makeContainer()
        let habit = HabitRecord(
            name: "Retired",
            frequency: .daily,
            type: .counter(target: 8),
            archivedAt: .now
        )
        try insert(habit, into: container)

        #expect(throws: LogHabitValueIntent.IntentError.self) {
            _ = try LogHabitValueIntent.apply(
                habitID: habit.id,
                value: 3,
                in: container.mainContext,
                calendar: .current,
                now: .now
            )
        }
    }

    @Test("Unknown habit id throws habitNotFound")
    func unknownThrows() throws {
        let container = try makeContainer()
        let phantom = UUID()

        #expect(throws: LogHabitValueIntent.IntentError.self) {
            _ = try LogHabitValueIntent.apply(
                habitID: phantom,
                value: 1,
                in: container.mainContext,
                calendar: .current,
                now: .now
            )
        }
    }

    // MARK: - Dialog content

    @Test("Dialog for logged counter mentions value and habit name")
    func dialogCounter() {
        let dialog = LogHabitValueIntent.dialog(
            for: .logged(value: 3, kind: .counter),
            habitName: "Water"
        )
        let text = String(describing: dialog)
        #expect(text.contains("Water"))
        #expect(text.contains("3"))
    }

    @Test("Dialog for logged timer mentions minutes")
    func dialogTimer() {
        let dialog = LogHabitValueIntent.dialog(
            for: .logged(value: 15, kind: .timer),
            habitName: "Read"
        )
        let text = String(describing: dialog)
        #expect(text.contains("Read"))
        #expect(text.contains("15"))
        #expect(text.localizedCaseInsensitiveContains("minute"))
    }

    @Test("Dialog for wrong type suggests Complete instead")
    func dialogWrongType() {
        let dialog = LogHabitValueIntent.dialog(
            for: .wrongType(kind: .binary),
            habitName: "Meditate"
        )
        let text = String(describing: dialog)
        #expect(text.contains("Meditate"))
        #expect(text.localizedCaseInsensitiveContains("complete"))
    }
}
