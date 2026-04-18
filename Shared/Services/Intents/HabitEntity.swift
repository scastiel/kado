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
    static func fetchSuggestions(in context: ModelContext) throws -> [HabitEntity] {
        let descriptor = FetchDescriptor<HabitRecord>(
            predicate: #Predicate { $0.archivedAt == nil },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return try context.fetch(descriptor).map(HabitEntity.init(record:))
    }

    /// Fetch a specific set of habit IDs, excluding archived ones.
    static func fetch(ids: [UUID], in context: ModelContext) throws -> [HabitEntity] {
        let idSet = Set(ids)
        let descriptor = FetchDescriptor<HabitRecord>(
            predicate: #Predicate { idSet.contains($0.id) && $0.archivedAt == nil }
        )
        return try context.fetch(descriptor).map(HabitEntity.init(record:))
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
