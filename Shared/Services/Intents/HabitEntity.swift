import AppIntents
import Foundation
import SwiftData

/// Lightweight value-type projection of a habit used as an
/// `AppIntent` parameter. Kept separate from `Habit` (domain
/// value) because `AppEntity` has its own protocol surface and
/// we don't want the UI / services types to pull `AppIntents` in
/// transitively.
struct HabitEntity: AppEntity, Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let colorRaw: String

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Habit")

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    static let defaultQuery = HabitEntityQuery()
}

extension HabitEntity {
    init(record: HabitRecord) {
        self.init(
            id: record.id,
            name: record.name,
            colorRaw: record.color.rawValue
        )
    }

    init(habit: Habit) {
        self.init(
            id: habit.id,
            name: habit.name,
            colorRaw: habit.color.rawValue
        )
    }

    /// Non-archived habits, sorted by creation order. Feeds
    /// `EntityQuery.suggestedEntities` and is reusable from tests.
    ///
    /// Filters `archivedAt == nil` in Swift after a broad fetch
    /// because `#Predicate` expressions — even a trivial
    /// `$0.archivedAt == nil` — crash with `EXC_BREAKPOINT` in the
    /// widget extension process at fetch compilation time. Same
    /// workaround as `fetch(ids:in:)`.
    static func fetchSuggestions(in context: ModelContext) throws -> [HabitEntity] {
        let descriptor = FetchDescriptor<HabitRecord>(
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return try context.fetch(descriptor)
            .filter { $0.archivedAt == nil }
            .map(HabitEntity.init(record:))
    }

    /// Fetch a specific set of habit IDs, excluding archived ones.
    ///
    /// Filters in Swift after a broad `archivedAt == nil` fetch because
    /// SwiftData's `#Predicate` macro doesn't reliably support
    /// `Set.contains` / `Array.contains` across toolchain versions —
    /// the widget extension crashes with `EXC_BREAKPOINT` at fetch
    /// time when the predicate is compiled into a SQL `IN (...)`
    /// clause. The in-Swift filter is fine because the typical
    /// `ids` length is 1 (lock widget) and at most a few dozen.
    static func fetch(ids: [UUID], in context: ModelContext) throws -> [HabitEntity] {
        let idSet = Set(ids)
        let descriptor = FetchDescriptor<HabitRecord>(
            predicate: #Predicate { $0.archivedAt == nil }
        )
        return try context.fetch(descriptor)
            .filter { idSet.contains($0.id) }
            .map(HabitEntity.init(record:))
    }
}

/// `EntityQuery` backing `HabitEntity.defaultQuery`. Resolves the
/// shared container on each invocation — iOS caches intent metadata
/// aggressively so holding state here isn't worth the complexity.
struct HabitEntityQuery: EntityQuery {
    init() {}

    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [HabitEntity] {
        let context = try IntentContainerResolver.sharedContainer().mainContext
        return try HabitEntity.fetch(ids: identifiers, in: context)
    }

    @MainActor
    func suggestedEntities() async throws -> [HabitEntity] {
        let context = try IntentContainerResolver.sharedContainer().mainContext
        return try HabitEntity.fetchSuggestions(in: context)
    }
}
