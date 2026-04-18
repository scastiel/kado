import AppIntents
import Foundation
import SwiftData

/// Lightweight value-type projection of a habit used as an
/// `AppIntent` parameter. Kept separate from `Habit` (domain
/// value) because `AppEntity` has its own protocol surface and
/// we don't want the UI / services types to pull `AppIntents` in
/// transitively.
///
/// The query backing `defaultQuery` reads from the App Group JSON
/// snapshot rather than SwiftData — two processes can't both
/// attach CloudKit to the same store, so the widget extension
/// stays out of SwiftData entirely and trusts the app to keep the
/// snapshot fresh (see `WidgetSnapshotBuilder`).
public struct HabitEntity: AppEntity, Identifiable, Hashable, Sendable {
    public let id: UUID
    public let name: String
    public let colorRaw: String

    public init(id: UUID, name: String, colorRaw: String) {
        self.id = id
        self.name = name
        self.colorRaw = colorRaw
    }

    public static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Habit")

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    public static let defaultQuery = HabitEntityQuery()
}

public extension HabitEntity {
    init(record: HabitRecord) {
        self.init(id: record.id, name: record.name, colorRaw: record.color.rawValue)
    }

    init(habit: Habit) {
        self.init(id: habit.id, name: habit.name, colorRaw: habit.color.rawValue)
    }

    init(widgetHabit: WidgetHabit) {
        self.init(id: widgetHabit.id, name: widgetHabit.name, colorRaw: widgetHabit.color.rawValue)
    }
}

/// `EntityQuery` backing `HabitEntity.defaultQuery`. Reads from
/// the App Group JSON snapshot, so it works identically in the
/// main app and the widget extension.
public struct HabitEntityQuery: EntityQuery {
    public init() {}

    public func entities(for identifiers: [UUID]) async throws -> [HabitEntity] {
        let idSet = Set(identifiers)
        return WidgetSnapshotStore.read().habits
            .filter { idSet.contains($0.id) }
            .map(HabitEntity.init(widgetHabit:))
    }

    public func suggestedEntities() async throws -> [HabitEntity] {
        WidgetSnapshotStore.read().habits.map(HabitEntity.init(widgetHabit:))
    }
}
