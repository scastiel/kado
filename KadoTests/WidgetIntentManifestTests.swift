import Foundation
import Testing
@testable import Kado
import KadoCore

/// Reads the AppIntents manifest Xcode compiles into the **widget
/// extension** and pins the shape the placed widgets depend on.
///
/// Two of these guard invariants that shipped broken once: the picker
/// let you choose eight habits for a tile that draws five, and silently
/// threw three away; and a stored pick is rebuilt on every reload from
/// the manifest's idea of the parameter, so a change in its shape is a
/// change in what an already-placed widget receives. The caps live in
/// `SelectHabitsIntent`'s `size:` dictionary as bare literals — the
/// initializer takes `_const Int` and rejects even a `static let` — so
/// they are a second copy of `WidgetHabitLimit` with nothing but care
/// holding them together. This reads them back out and compares.
///
/// The manifest is walked, not the types: a unit test can instantiate
/// the intent, but only the compiled metadata says what the widget-edit
/// sheet will actually do with it.
@Suite("Widget intent manifest")
struct WidgetIntentManifestTests {

    // MARK: - SelectHabitsIntent (home widgets)

    @Test("The picker's per-family caps match the limits the widgets render")
    func pickerCapsMatchTheRenderLimits() throws {
        let sizes = try Self.collectionSizes(of: Self.habitsParameter())
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

    /// Every widget starts with a default-initialised intent, and so
    /// does one already on a Home Screen when its configuration type
    /// changes underneath it. `nil` has to be a legal value or those
    /// tiles show "needs configuration" instead of what they showed.
    @Test("The habit pick is optional, so an unconfigured widget renders")
    func habitPickIsOptional() throws {
        let habits = try Self.habitsParameter()
        #expect(habits["isOptional"] as? Bool == true)
    }

    /// The pick is stored as entity identifiers and rebuilt through
    /// `HabitEntity`'s query. The entity is the one KadoCore defines —
    /// deliberately, see `docs/plans/2026-09/widget-habit-selection/research.md`
    /// — and that is a decision worth failing loudly over if it drifts.
    @Test("The pick is an array of KadoCore's HabitEntity")
    func pickIsAnArrayOfHabitEntity() throws {
        let habits = try Self.habitsParameter()
        let member = try #require(
            Self.value(at: ["valueType", "array", "wrapper", "memberValueType", "entity", "wrapper", "typeName"], in: habits) as? String,
            "the 'habits' parameter is not an array of entities"
        )
        #expect(member == "HabitEntity")

        let entity = try #require(Self.entities()["HabitEntity"] as? [String: Any], "HabitEntity is missing from the manifest")
        #expect(entity["fullyQualifiedTypeName"] as? String == "KadoCore.HabitEntity")
    }

    // MARK: - PickHabitIntent (lock widgets)

    @Test("The lock widgets' single pick is an optional HabitEntity")
    func lockPickIsAnOptionalHabitEntity() throws {
        let habit = try Self.parameter(named: "habit", of: "PickHabitIntent")
        #expect(habit["isOptional"] as? Bool == true)
        let entity = try #require(
            Self.value(at: ["valueType", "entity", "wrapper", "typeName"], in: habit) as? String
        )
        #expect(entity == "HabitEntity")
    }

    // MARK: - Localization

    /// The widget-edit sheet reads these keys through the extension's
    /// own catalog. Xcode does not extract them from a Swift package's
    /// sources, so a new `LocalizedStringResource` on an intent is
    /// English in the French build until someone authors the key by
    /// hand — and `LocalizationCoverageTests` only checks keys that
    /// exist. This checks that they exist.
    @Test("Every string the widget-edit sheets show is in the widget catalog")
    func intentStringsAreInTheWidgetCatalog() throws {
        let catalog = try Self.widgetCatalogKeys()
        var wanted: Set<String> = []
        for identifier in ["SelectHabitsIntent", "PickHabitIntent"] {
            let action = try Self.action(identifier)
            if let key = Self.value(at: ["title", "key"], in: action) as? String { wanted.insert(key) }
            if let key = Self.value(at: ["descriptionMetadata", "descriptionText", "key"], in: action) as? String {
                wanted.insert(key)
            }
            for parameter in action["parameters"] as? [[String: Any]] ?? [] {
                if let key = Self.value(at: ["title", "key"], in: parameter) as? String { wanted.insert(key) }
            }
        }
        for case let entity as [String: Any] in try Self.entities().values {
            if let key = Self.value(at: ["displayTypeName", "key"], in: entity) as? String { wanted.insert(key) }
        }
        #expect(!wanted.isEmpty, "found no strings to check — the manifest walk is broken")
        let missing = wanted.subtracting(catalog).sorted()
        #expect(missing.isEmpty, "not in KadoWidgets/Resources/Localizable.xcstrings: \(missing)")
    }

    // MARK: - Reading the compiled manifest

    /// The extension's `extract.actionsdata`. The appex is embedded in
    /// the host app by its "Embed Foundation Extensions" phase, so it is
    /// always there under test.
    ///
    /// Every failure here is spelled out, because this walks a format
    /// Apple owns and does not document. If Xcode reshapes the manifest,
    /// this should say so plainly rather than fail as a mysterious nil.
    private static func manifest() throws -> [String: Any] {
        let plugIns = try #require(
            Bundle.main.builtInPlugInsURL,
            "The host app has no PlugIns directory — the widget extension is no longer embedded."
        )
        let appex = plugIns.appendingPathComponent("KadoWidgetsExtension.appex")
        let url = appex
            .appendingPathComponent("Metadata.appintents")
            .appendingPathComponent("extract.actionsdata")
        let data = try #require(
            try? Data(contentsOf: url),
            "No AppIntents manifest in the widget extension at \(url.path) — Xcode's metadata extraction moved or stopped running."
        )
        return try #require(
            try JSONSerialization.jsonObject(with: data) as? [String: Any],
            "The widget extension's AppIntents manifest is not a JSON object."
        )
    }

    private static func action(_ identifier: String) throws -> [String: Any] {
        let actions = try #require(
            try manifest()["actions"] as? [String: Any],
            "The manifest has no 'actions' dictionary."
        )
        return try #require(
            actions[identifier] as? [String: Any],
            "\(identifier) is missing from the widget extension's manifest."
        )
    }

    private static func entities() throws -> [String: Any] {
        try #require(
            try manifest()["entities"] as? [String: Any],
            "The manifest has no 'entities' dictionary."
        )
    }

    private static func parameter(named name: String, of identifier: String) throws -> [String: Any] {
        let parameters = try #require(
            try action(identifier)["parameters"] as? [[String: Any]],
            "\(identifier) declares no parameters in the manifest."
        )
        return try #require(
            parameters.first(where: { $0["name"] as? String == name }),
            "\(identifier) has no '\(name)' parameter in the manifest."
        )
    }

    private static func habitsParameter() throws -> [String: Any] {
        try parameter(named: "habits", of: "SelectHabitsIntent")
    }

    /// The `sizes` dictionary declared through `@Parameter(size:)`,
    /// keyed by widget family. `typeSpecificMetadata` is a flat array
    /// mixing key strings with their payload objects, so pick out the
    /// one carrying the sizes rather than indexing by position.
    private static func collectionSizes(of parameter: [String: Any]) throws -> [String: Any] {
        let metadata = try #require(
            parameter["typeSpecificMetadata"] as? [Any],
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

    private static func value(at path: [String], in object: [String: Any]) -> Any? {
        var current: Any = object
        for key in path {
            guard let dictionary = current as? [String: Any], let next = dictionary[key] else { return nil }
            current = next
        }
        return current
    }

    /// The keys of the widget extension's source catalog, read from the
    /// repo the same way `LocalizationCoverageTests` does.
    private static func widgetCatalogKeys() throws -> Set<String> {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("KadoWidgets/Resources/Localizable.xcstrings")
        let catalog = try #require(
            try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any],
            "Could not read the widget catalog at \(url.path)."
        )
        let strings = try #require(catalog["strings"] as? [String: Any], "The widget catalog has no 'strings'.")
        return Set(strings.keys)
    }
}
