import Foundation
import Testing
@testable import Kado

/// Pins the plain-ASCII names Siri can match the app by (issue #108).
///
/// Siri on visionOS 26 transcribes "Open Kadō" with the macron and then
/// reports no app by that name: matching an app whose display name
/// carries a diacritic fails, both for "Open …" and for App Shortcut
/// phrases built on `\(.applicationName)`. `Kado/Info.plist` declares
/// "Kado" as the spoken name and as an alternative app name — which
/// App Shortcuts also accept for `.applicationName` — and this suite
/// fails if either drops out of the merged Info.plist or stops being
/// the display name with its diacritics folded away.
@Suite("App spoken name")
struct AppSpokenNameTests {

    private var info: [String: Any] { Bundle.main.infoDictionary ?? [:] }

    private var foldedDisplayName: String? {
        (info["CFBundleDisplayName"] as? String)?
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "en"))
    }

    @Test("The display name still carries the macron")
    func displayNameIsKado() {
        #expect(info["CFBundleDisplayName"] as? String == "Kadō")
    }

    @Test("The spoken name is the display name without diacritics")
    func spokenNameIsFolded() throws {
        let spoken = try #require(info["CFBundleSpokenName"] as? String)
        #expect(spoken == foldedDisplayName)
        #expect(spoken.allSatisfy { $0.isASCII })
    }

    @Test("An alternative app name is the display name without diacritics")
    func alternativeNameIsFolded() throws {
        let entries = try #require(info["INAlternativeAppNames"] as? [[String: Any]])
        let names = entries.compactMap { $0["INAlternativeAppName"] as? String }
        #expect(names.contains { $0 == foldedDisplayName })
        #expect(names.allSatisfy { name in name.allSatisfy { $0.isASCII } })
    }
}
