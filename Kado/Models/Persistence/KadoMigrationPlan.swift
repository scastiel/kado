import Foundation
import SwiftData

/// Migration plan for Kadō's persistent schema. `stages` stays empty
/// while v1 is the only shipped version; the first real stage lands
/// alongside `KadoSchemaV2`.
enum KadoMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [KadoSchemaV1.self]
    }

    static var stages: [MigrationStage] { [] }
}
