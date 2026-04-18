import Foundation
import SwiftData

/// Migration plan for Kadō's persistent schema. Schemas are listed
/// oldest-to-newest; `stages` bridges each consecutive pair.
public enum KadoMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
        [KadoSchemaV1.self, KadoSchemaV2.self, KadoSchemaV3.self]
    }

    public static var stages: [MigrationStage] {
        [
            .lightweight(
                fromVersion: KadoSchemaV1.self,
                toVersion: KadoSchemaV2.self
            ),
            .lightweight(
                fromVersion: KadoSchemaV2.self,
                toVersion: KadoSchemaV3.self
            )
        ]
    }
}
