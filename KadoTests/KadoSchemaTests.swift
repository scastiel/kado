import Testing
import Foundation
import SwiftData
@testable import Kado

@Suite("KadoSchemaV1 + KadoMigrationPlan")
@MainActor
struct KadoSchemaTests {
    @Test("Schema version identifier is 1.0.0")
    func schemaVersion() {
        #expect(KadoSchemaV1.versionIdentifier == Schema.Version(1, 0, 0))
    }

    @Test("Schema declares HabitRecord and CompletionRecord")
    func schemaModels() {
        let modelTypes = KadoSchemaV1.models
        #expect(modelTypes.contains { $0 == HabitRecord.self })
        #expect(modelTypes.contains { $0 == CompletionRecord.self })
    }

    @Test("Migration plan declares v1 with empty stages")
    func migrationPlanShape() {
        #expect(KadoMigrationPlan.stages.isEmpty)
        #expect(KadoMigrationPlan.schemas.count == 1)
    }

    @Test("In-memory ModelContainer constructs from the migration plan")
    func containerBuildsFromPlan() throws {
        let schema = Schema(versionedSchema: KadoSchemaV1.self)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: KadoMigrationPlan.self,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        )
        // Smoke test: the main context exists and accepts inserts.
        let habit = HabitRecord(name: "Smoke")
        container.mainContext.insert(habit)
        try container.mainContext.save()
        let fetched = try container.mainContext.fetch(FetchDescriptor<HabitRecord>())
        #expect(fetched.count == 1)
    }
}
