import Foundation
import SwiftData
import Testing
@testable import Kado

/// CloudKit imposes several runtime-enforced rules on SwiftData
/// schemas:
/// 1. Every relationship must be optional (on both sides).
/// 2. No `@Attribute(.unique)` may be declared.
/// 3. Every attribute must have a default value or be optional.
/// Violating rule 1 or 2 crashes at `ModelContainer.init(...)` the
/// first time `cloudKitDatabase:` is set — and only then; a
/// local-only container happily mounts the same schema.
///
/// These regression tests pin the current schema shape so a future
/// commit adding a required relationship or a unique attribute
/// fails fast in CI instead of at first launch under CloudKit.
@MainActor
struct CloudKitShapeTests {
    @Test("KadoSchemaV1: every relationship is optional")
    func allRelationshipsOptional() {
        let schema = Schema(versionedSchema: KadoSchemaV1.self)
        for entity in schema.entities {
            for relationship in entity.relationships {
                #expect(
                    relationship.isOptional,
                    "\(entity.name).\(relationship.name) must be optional for CloudKit"
                )
            }
        }
    }

    @Test("KadoSchemaV1: no attribute is marked unique")
    func noUniqueAttributes() {
        let schema = Schema(versionedSchema: KadoSchemaV1.self)
        for entity in schema.entities {
            for attribute in entity.attributes {
                #expect(
                    !attribute.isUnique,
                    "\(entity.name).\(attribute.name) must not be @Attribute(.unique) for CloudKit"
                )
            }
        }
    }

    @Test("HabitRecord constructs with no arguments")
    func habitRecordHasAllDefaults() {
        let record = HabitRecord()
        #expect(record.name == "")
        #expect(record.frequency == .daily)
        #expect(record.type == .binary)
        #expect(record.archivedAt == nil)
        #expect(record.completions?.isEmpty ?? true)
    }

    @Test("CompletionRecord constructs with no arguments")
    func completionRecordHasAllDefaults() {
        let record = CompletionRecord()
        #expect(record.value == 1.0)
        #expect(record.note == nil)
        #expect(record.habit == nil)
    }
}
