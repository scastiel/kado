import Foundation
import SwiftData

/// Version 1 of Kadō's persistent schema. Subsequent schema versions
/// (`KadoSchemaV2`, …) live alongside this one — never modify a
/// shipped version in place; CloudKit treats schema changes as
/// breaking and migrations rely on the prior version's snapshot.
enum KadoSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [HabitRecord.self, CompletionRecord.self]
    }
}
