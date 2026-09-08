import Foundation
import Testing
@testable import Kado
import KadoCore

/// Guards the invariant that shipped broken once: the widget-edit
/// sheet let you pick eight habits for a tile that draws five, and
/// silently threw three away.
///
/// The cap now lives in `SelectHabitsIntent`'s `size:` dictionary —
/// as bare literals, because `IntentCollectionSize.init(min:max:)`
/// takes `_const Int` and rejects even a `static let`. That makes the
/// numbers a second copy of `WidgetHabitLimit` with nothing but care
/// holding them together, which is exactly the shape of the original
/// bug. So rather than trusting care, this reads the caps back out of
/// the AppIntents manifest Xcode compiles into the bundle and
/// compares them to the limits the views actually render with.
@Suite("SelectHabitsIntent")
struct SelectHabitsIntentTests {

    /// Every widget starts here, and so does one already on a Home
    /// Screen when its configuration type changes underneath it. An
    /// empty pick has to mean "show everything", so it has to *be*
    /// empty by default.
    @Test("A default-initialised intent has no pick")
    func defaultIntentHasNoPick() {
        #expect(SelectHabitsIntent().habitIDs.isEmpty)
    }

    /// The link that was never covered, and the one that broke: the
    /// selection function was tested in isolation and the manifest was
    /// tested in isolation, while *nothing* checked that a pick set on
    /// the intent actually arrives at the rows a widget draws.
    @Test("A pick set on the intent reaches the rows the widget draws")
    func pickReachesTheRenderedRows() {
        let habits = ["A", "B", "C", "D", "E"].map {
            WidgetHabit(
                id: UUID(),
                name: $0,
                color: .blue,
                icon: "circle",
                typeKind: .binary,
                target: nil
            )
        }
        let snapshot = WidgetSnapshot(
            generatedAt: .now,
            habits: habits,
            today: habits.map {
                WidgetTodayRow(
                    habit: $0,
                    status: .none,
                    progress: 0,
                    valueToday: nil,
                    streak: 0,
                    scorePercent: 0
                )
            },
            totalDueToday: habits.count,
            completedToday: 0,
            matrix: habits.map { WidgetMatrixRow(habit: $0, cells: []) },
            matrixDays: []
        )

        let intent = SelectHabitsIntent(
            habits: [habits[2], habits[0]].map(HabitEntity.init(widgetHabit:))
        )
        #expect(intent.habitIDs == [habits[2].id, habits[0].id], "the @Parameter dropped its value")

        // The entry is what the provider hands the view.
        let entry = SelectedSnapshotEntry(
            date: .now,
            snapshot: snapshot,
            habitIDs: intent.habitIDs
        )
        #expect(entry.matrixRows(limit: WidgetHabitLimit.large).map(\.habit.name) == ["C", "A"])
        #expect(entry.todayRows(limit: WidgetHabitLimit.small).map(\.habit.name) == ["C", "A"])
    }

    @Test("The picker's per-family caps match the limits the widgets render")
    func pickerCapsMatchTheRenderLimits() throws {
        let sizes = try habitsParameterCollectionSizes()
        let expected = [
            "systemSmall": WidgetHabitLimit.small,
            "systemMedium": WidgetHabitLimit.medium,
            "systemLarge": WidgetHabitLimit.large,
        ]
        for (family, limit) in expected {
            let size = try #require(
                sizes[family] as? [String: Any],
                "no selection cap declared for \(family)"
            )
            #expect(
                size["max"] as? Int == limit,
                "\(family): the picker allows \(String(describing: size["max"])) habits but the widget draws \(limit)"
            )
            // Not decoration: "no pick" is how every widget starts and
            // how it says "show them all". A minimum above zero would
            // make that state unreachable.
            #expect(
                size["min"] as? Int == 0,
                "\(family): an empty pick must stay legal — it is what 'show every habit' means"
            )
        }
        #expect(sizes.count == expected.count, "a family gained or lost a cap without this test moving")
    }

    // MARK: - Reading the compiled AppIntents manifest

    /// The `sizes` dictionary declared on the intent's `habits`
    /// parameter, keyed by widget family.
    ///
    /// Every failure here is spelled out, because this walks a format
    /// Apple owns and does not document. If Xcode reshapes the
    /// manifest, this should say so plainly rather than fail as a
    /// mysterious nil.
    private func habitsParameterCollectionSizes() throws -> [String: Any] {
        let url = try #require(
            Bundle.main.url(
                forResource: "extract",
                withExtension: "actionsdata",
                subdirectory: "Metadata.appintents"
            ),
            "No AppIntents manifest in the host app bundle — Xcode's metadata extraction moved or stopped running."
        )
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
        let intent = try #require(
            Self.firstObject(in: json, where: { $0["identifier"] as? String == "SelectHabitsIntent" }),
            "SelectHabitsIntent is missing from the AppIntents manifest."
        )
        let parameters = try #require(
            intent["parameters"] as? [[String: Any]],
            "SelectHabitsIntent declares no parameters in the manifest."
        )
        let habits = try #require(
            parameters.first(where: { $0["name"] as? String == "habits" }),
            "SelectHabitsIntent has no 'habits' parameter in the manifest."
        )
        // `typeSpecificMetadata` is a flat array mixing key strings
        // with their payload objects, so pick out the one carrying
        // the sizes rather than indexing by position.
        let metadata = try #require(
            habits["typeSpecificMetadata"] as? [Any],
            "The 'habits' parameter carries no type-specific metadata — the size: cap is gone."
        )
        let sizes = metadata
            .compactMap { $0 as? [String: Any] }
            .compactMap { $0["collectionSizes"] as? [String: Any] }
            .first
        return try #require(
            sizes?["sizes"] as? [String: Any],
            "The 'habits' parameter declares no collection sizes — the picker is uncapped again."
        )
    }

    /// Depth-first search for the first dictionary matching
    /// `predicate`. The manifest nests intents under keys that have
    /// changed between Xcode releases, so don't hard-code a path.
    private static func firstObject(
        in json: Any,
        where predicate: ([String: Any]) -> Bool
    ) -> [String: Any]? {
        if let object = json as? [String: Any] {
            if predicate(object) { return object }
            for value in object.values {
                if let found = firstObject(in: value, where: predicate) { return found }
            }
        } else if let array = json as? [Any] {
            for value in array {
                if let found = firstObject(in: value, where: predicate) { return found }
            }
        }
        return nil
    }
}
