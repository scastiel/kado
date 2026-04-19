import Foundation
import Testing

/// Guards against the "added an English key but forgot to translate it"
/// regression. Walks every shipped `Localizable.xcstrings` and
/// asserts every user-facing entry has a non-empty French
/// translation — accepting either a plain `stringUnit` or ICU
/// `variations.plural` wrapper. Orphan keys (empty string,
/// developer-only entries not user-facing) can be skipped by adding
/// them to `keysExempt`.
///
/// Each target with user-facing strings has its own catalog:
/// - Main app: `Kado/Resources/Localizable.xcstrings`
/// - Widget extension: `KadoWidgets/Resources/Localizable.xcstrings`
///
/// The widget catalog exists because Xcode's synchronized-folder
/// target membership is per-file; sharing a single catalog across
/// targets requires hand-editing project.pbxproj, which the
/// author opted against. Keep the two catalogs' overlapping keys
/// (widget kind names, lock-screen fallbacks, etc.) aligned when
/// one changes.
struct LocalizationCoverageTests {
    private static let keysExempt: Set<String> = [
        // Orphan key sometimes left behind by Xcode IDE extraction
        // passes. Re-inserted on each IDE open; harmless.
        "",
    ]

    private static let supportedLanguages: [String] = ["fr"]

    private static let catalogPaths: [String] = [
        "Kado/Resources/Localizable.xcstrings",
        "KadoWidgets/Resources/Localizable.xcstrings",
    ]

    @Test("Every EN catalog key has a non-empty translation in every shipped language")
    func translationCoverage() throws {
        for path in Self.catalogPaths {
            try verifyCoverage(catalogRelativePath: path)
        }
    }

    // MARK: - Helpers

    private func verifyCoverage(catalogRelativePath path: String) throws {
        let data = try loadCatalogData(relativePath: path)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let strings = try #require(
            json?["strings"] as? [String: [String: Any]],
            "Could not parse strings dict from \(path)"
        )

        for (key, entry) in strings {
            guard !Self.keysExempt.contains(key) else { continue }

            for language in Self.supportedLanguages {
                #expect(
                    hasNonEmpty(entry: entry, language: language),
                    "Missing or empty \(language.uppercased()) localization for key \(key.debugDescription) in \(path)"
                )
            }
        }
    }

    private func loadCatalogData(relativePath: String) throws -> Data {
        // Prefer the test bundle (ships the compiled catalog as a
        // stringsdict-backed resource), fall back to reading the
        // source file from the repo when the test runs in an Xcode
        // context where the catalog isn't copied into the test target.
        // The fallback path assumes this test file lives under
        // `<repo>/KadoTests/`; break if the test file relocates.
        let basename = (relativePath as NSString).lastPathComponent
        let nameWithoutExtension = (basename as NSString).deletingPathExtension
        if let url = Bundle.main.url(
            forResource: nameWithoutExtension, withExtension: "xcstrings"
        ) {
            return try Data(contentsOf: url)
        }
        let repoCatalog = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(relativePath)
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
           let plural = variations["plural"] as? [String: Any],
           !plural.isEmpty
        {
            // Every declared plural form must have a non-empty value.
            // Accepting any single form would let a language declare
            // `one` but forget `other` (or vice versa) and still pass,
            // leaving the missing form to fall back to the key at
            // runtime.
            for (_, form) in plural {
                guard let formDict = form as? [String: Any],
                      let stringUnit = formDict["stringUnit"] as? [String: Any],
                      let value = stringUnit["value"] as? String,
                      !value.isEmpty
                else { return false }
            }
            return true
        }

        return false
    }
}
