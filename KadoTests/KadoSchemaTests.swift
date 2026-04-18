import Testing
import Foundation
import SwiftData
@testable import Kado
import KadoCore

@Suite("KadoSchema + KadoMigrationPlan")
@MainActor
struct KadoSchemaTests {
    @Test("V1 version identifier is 1.0.0")
    func v1Version() {
        #expect(KadoSchemaV1.versionIdentifier == Schema.Version(1, 0, 0))
    }

    @Test("V2 version identifier is 2.0.0")
    func v2Version() {
        #expect(KadoSchemaV2.versionIdentifier == Schema.Version(2, 0, 0))
    }

    @Test("V3 version identifier is 3.0.0")
    func v3Version() {
        #expect(KadoSchemaV3.versionIdentifier == Schema.Version(3, 0, 0))
    }

    @Test("Migration plan declares V1→V2 and V2→V3 lightweight stages")
    func migrationPlanShape() {
        #expect(KadoMigrationPlan.schemas.count == 3)
        #expect(KadoMigrationPlan.stages.count == 2)
    }

    @Test("In-memory ModelContainer constructs from the current (V3) schema")
    func containerBuildsFromPlan() throws {
        let schema = Schema(versionedSchema: KadoSchemaV3.self)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: KadoMigrationPlan.self,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        )
        let habit = HabitRecord(name: "Smoke")
        container.mainContext.insert(habit)
        try container.mainContext.save()
        let fetched = try container.mainContext.fetch(FetchDescriptor<HabitRecord>())
        #expect(fetched.count == 1)
    }

    @Test("Lightweight migration from V1 populates default color and icon")
    func v1ToV2Migration() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("migration-test-\(UUID().uuidString).store")
        defer { try? FileManager.default.removeItem(at: url) }

        // Step 1: open a V1 store at the temp URL and insert a habit.
        do {
            let schema = Schema(versionedSchema: KadoSchemaV1.self)
            let config = ModelConfiguration(schema: schema, url: url)
            let container = try ModelContainer(
                for: schema,
                migrationPlan: nil,
                configurations: config
            )
            let habit = KadoSchemaV1.HabitRecord(name: "Pre-migration habit")
            container.mainContext.insert(habit)
            try container.mainContext.save()
        }

        // Step 2: reopen as V2 + migration plan; lightweight migration runs.
        let schema = Schema(versionedSchema: KadoSchemaV2.self)
        let config = ModelConfiguration(schema: schema, url: url)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: KadoMigrationPlan.self,
            configurations: config
        )
        let habits = try container.mainContext.fetch(FetchDescriptor<KadoSchemaV2.HabitRecord>())
        #expect(habits.count == 1)
        let habit = try #require(habits.first)
        #expect(habit.name == "Pre-migration habit")
        #expect(habit.color == .blue)
        #expect(habit.icon == HabitIcon.default)
    }

    @Test("Lightweight migration from V2 populates default reminder fields")
    func v2ToV3Migration() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("migration-test-\(UUID().uuidString).store")
        defer { try? FileManager.default.removeItem(at: url) }

        // Step 1: seed a V2 store.
        do {
            let schema = Schema(versionedSchema: KadoSchemaV2.self)
            let config = ModelConfiguration(schema: schema, url: url)
            let container = try ModelContainer(
                for: schema,
                migrationPlan: nil,
                configurations: config
            )
            let habit = KadoSchemaV2.HabitRecord(name: "V2 habit", color: .orange)
            container.mainContext.insert(habit)
            try container.mainContext.save()
        }

        // Step 2: reopen as V3; lightweight stage fills reminder defaults.
        let schema = Schema(versionedSchema: KadoSchemaV3.self)
        let config = ModelConfiguration(schema: schema, url: url)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: KadoMigrationPlan.self,
            configurations: config
        )
        let habits = try container.mainContext.fetch(FetchDescriptor<KadoSchemaV3.HabitRecord>())
        #expect(habits.count == 1)
        let habit = try #require(habits.first)
        #expect(habit.name == "V2 habit")
        #expect(habit.color == .orange)
        #expect(habit.remindersEnabled == false)
        #expect(habit.reminderHour == 9)
        #expect(habit.reminderMinute == 0)
    }
}
