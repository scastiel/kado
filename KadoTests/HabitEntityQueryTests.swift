import Foundation
import Testing
@testable import Kado
import KadoCore

/// `HabitEntityQuery` is how a widget's saved habit selection comes
/// back after every reload: AppIntents stores the ids and rebuilds
/// the entity list from this. It sits between two pieces that were
/// each tested on their own — the picker and the selection filter —
/// and was itself covered by nothing.
@Suite("HabitEntityQuery")
struct HabitEntityQueryTests {

    private func habits(_ names: [String]) -> [WidgetHabit] {
        names.map {
            WidgetHabit(
                id: UUID(),
                name: $0,
                color: .blue,
                icon: "circle",
                typeKind: .binary,
                target: nil
            )
        }
    }

    /// The bug this suite exists for. The widgets render habits in the
    /// order they were picked, and that order only survives if it
    /// survives rehydration — resolving against the snapshot's own
    /// order silently re-sorts the user's choice back to the app's.
    @Test("Resolution follows the requested order, not the snapshot's")
    func resolutionKeepsRequestedOrder() {
        let all = habits(["A", "B", "C", "D", "E"])
        let requested = [all[3].id, all[0].id, all[2].id]
        let resolved = HabitEntityQuery.resolve(identifiers: requested, in: all)
        #expect(resolved.map(\.name) == ["D", "A", "C"])
        #expect(resolved.map(\.id) == requested, "ids must come back in the order they went in")
    }

    /// A habit archived or deleted since the widget was configured
    /// takes only itself out. Returning nothing for the whole list
    /// would read upstream as "no selection", which means *show
    /// everything* — the pick would be ignored rather than reduced,
    /// and nothing about the widget would look wrong.
    @Test("An id with no habit behind it drops only itself")
    func missingIDDropsOnlyItself() {
        let all = habits(["A", "B", "C"])
        let resolved = HabitEntityQuery.resolve(
            identifiers: [all[1].id, UUID(), all[0].id],
            in: all
        )
        #expect(resolved.map(\.name) == ["B", "A"])
    }

    @Test("No identifiers resolves to nothing")
    func emptyRequestResolvesEmpty() {
        #expect(HabitEntityQuery.resolve(identifiers: [], in: habits(["A"])).isEmpty)
    }

    /// The shape of the reported failure, pinned: when the snapshot
    /// can't be read the resolution is empty, and empty is read as
    /// "no pick" — so the widget shows every habit rather than the
    /// chosen ones. Stated here so the consequence is written down
    /// where the next person looks.
    @Test("An unreadable snapshot resolves to nothing, which upstream reads as no pick")
    func emptySnapshotResolvesEmpty() {
        let all = habits(["A", "B"])
        #expect(HabitEntityQuery.resolve(identifiers: all.map(\.id), in: []).isEmpty)
    }

    @Test("Entities carry the fields the widget-edit sheet displays")
    func resolvedEntitiesCarryDisplayFields() throws {
        let all = habits(["Meditate"])
        let resolved = try #require(
            HabitEntityQuery.resolve(identifiers: [all[0].id], in: all).first
        )
        #expect(resolved.name == "Meditate")
        #expect(resolved.colorRaw == HabitColor.blue.rawValue)
    }
}
