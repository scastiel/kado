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

    /// Rehydrates stored entity ids — this is how a widget's saved
    /// habit selection comes back after a reload, so two properties
    /// matter beyond "returns the right set".
    ///
    /// **Order follows `identifiers`, not the snapshot.** The home
    /// widgets render habits in the order they were picked, and
    /// AppIntents rebuilds the selection from what this returns. A
    /// snapshot-ordered result silently re-sorts the user's choice.
    ///
    /// **A miss drops one habit, never the selection.** Anything not
    /// in the snapshot — archived, deleted — is skipped, and the rest
    /// still resolve. That matters because an empty return is read
    /// upstream as "no selection", which means *show everything*: the
    /// failure mode of losing the whole list is a widget that quietly
    /// ignores the user's pick rather than one that looks broken.
    public func entities(for identifiers: [UUID]) async throws -> [HabitEntity] {
        Self.resolve(identifiers: identifiers, in: WidgetSnapshotStore.read().habits)
    }

    /// The resolution step on its own, so it can be tested without
    /// writing into the real App Group container the installed app is
    /// using.
    public static func resolve(
        identifiers: [UUID],
        in habits: [WidgetHabit]
    ) -> [HabitEntity] {
        let byID = Dictionary(
            habits.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        return identifiers
            .compactMap { byID[$0] }
            .map(HabitEntity.init(widgetHabit:))
    }

    public func suggestedEntities() async throws -> [HabitEntity] {
        WidgetSnapshotStore.read().habits.map(HabitEntity.init(widgetHabit:))
    }
}
