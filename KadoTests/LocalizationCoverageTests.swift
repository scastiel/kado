import Foundation
import Testing
@testable import Kado

/// Guards against the "added an English key but forgot to translate it"
/// regression. Walks the shipped `Localizable.xcstrings` and asserts
/// every user-facing entry has a non-empty French translation —
/// accepting either a plain `stringUnit` or ICU `variations.plural`
/// wrapper. Orphan keys (empty string, developer-only entries not
/// user-facing) can be skipped by adding them to `keysExempt`.
@MainActor
struct LocalizationCoverageTests {
    private static let keysExempt: Set<String> = [
        // Orphan key sometimes left behind by Xcode IDE extraction
        // passes. Re-inserted on each IDE open; harmless.
        "",
    ]

    private static let supportedLanguages: [String] = ["fr"]

    @Test("Every EN catalog key has a non-empty translation in every shipped language")
    func translationCoverage() throws {
        let data = try loadCatalogData()
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let strings = try #require(json?["strings"] as? [String: [String: Any]])

        for (key, entry) in strings {
            guard !Self.keysExempt.contains(key) else { continue }

            for language in Self.supportedLanguages {
                #expect(
                    hasNonEmpty(entry: entry, language: language),
                    "Missing or empty \(language.uppercased()) localization for key: \(key)"
                )
            }
        }
    }

    // MARK: - Helpers

    private func loadCatalogData() throws -> Data {
        // Prefer the test bundle (ships the compiled catalog as a
        // stringsdict-backed resource), fall back to reading the
        // source file from the repo when the test runs in an Xcode
        // context where the catalog isn't copied into the test target.
        if let url = Bundle.main.url(
            forResource: "Localizable", withExtension: "xcstrings"
        ) {
            return try Data(contentsOf: url)
        }
        let repoCatalog = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Kado/Resources/Localizable.xcstrings")
        return try Data(contentsOf: repoCatalog)
    }

    private func hasNonEmpty(entry: [String: Any], language: String) -> Bool {
        guard let localizations = entry["localizations"] as? [String: Any],
              let langEntry = localizations[language] as? [String: Any]
        else { return false }

        if let stringUnit = langEntry["stringUnit"] as? [String: Any],
           let value = stringUnit["value"] as? String,
           !value.isEmpty {
            return true
        }

        if let variations = langEntry["variations"] as? [String: Any],
           let plural = variations["plural"] as? [String: Any]
        {
            // Any non-empty plural form counts as covered.
            for (_, form) in plural {
                if let formDict = form as? [String: Any],
                   let stringUnit = formDict["stringUnit"] as? [String: Any],
                   let value = stringUnit["value"] as? String,
                   !value.isEmpty
                {
                    return true
                }
            }
        }

        return false
    }
}
