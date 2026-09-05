import Foundation
import SwiftData
import KadoCore

/// Turning an id back into a live managed object, against whichever
/// store is mounted right now.
///
/// Screens address habits and completions by `UUID` and render from
/// value-type snapshots, so a dev-mode `ModelContainer` swap can't
/// leave them holding an object the old store vended — reading one
/// traps inside SwiftData (issue #63). These lookups are where the id
/// becomes a record again: inside a mutation, never in a `body`.
extension ModelContext {
    /// The live `HabitRecord` for this id, or `nil` if the store that
    /// is mounted now doesn't have it.
    ///
    /// No `#Predicate`: matching a `UUID` inside one is a shape this
    /// project stays away from, and the habit list is small enough
    /// that filtering in Swift costs nothing.
    func habitRecord(id: UUID) -> HabitRecord? {
        let all = try? fetch(FetchDescriptor<HabitRecord>())
        return all?.first { $0.id == id }
    }

    /// The live `CompletionRecord` for this id, same rules.
    func completionRecord(id: UUID) -> CompletionRecord? {
        let all = try? fetch(FetchDescriptor<CompletionRecord>())
        return all?.first { $0.id == id }
    }
}
