import Foundation
import Testing
import KadoCore

@Suite("HabitThemeDefaults")
struct HabitThemeDefaultsTests {
    private func makeSuite() -> (UserDefaults, String) {
        let name = "habit-theme-tests-\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: name)!
        return (suite, name)
    }

    private func tearDown(_ name: String) {
        UserDefaults().removePersistentDomain(forName: name)
    }

    /// "Nothing changes for users who never open the picker."
    @Test("An unset key reads as Kadō")
    func defaultsToKado() {
        let (suite, name) = makeSuite()
        defer { tearDown(name) }

        #expect(HabitThemeDefaults.theme(in: suite) == .kado)
    }

    @Test("Every theme round-trips")
    func everyThemeRoundTrips() {
        let (suite, name) = makeSuite()
        defer { tearDown(name) }

        for theme in HabitTheme.allCases {
            HabitThemeDefaults.setTheme(theme, in: suite)
            #expect(HabitThemeDefaults.theme(in: suite) == theme)
        }
    }

    /// A later build adds paid themes (#113); downgrading, or a theme
    /// that is later withdrawn, must not leave habits unpaintable.
    @Test("A raw value outside the cases falls back to Kadō")
    func unknownRawValueFallsBack() {
        let (suite, name) = makeSuite()
        defer { tearDown(name) }

        suite.set("sunset", forKey: HabitThemeDefaults.key)
        #expect(HabitThemeDefaults.theme(in: suite) == .kado)
        suite.set(3, forKey: HabitThemeDefaults.key)
        #expect(HabitThemeDefaults.theme(in: suite) == .kado)
    }

    /// What the widgets paint in. A refund flips the App Group mirror,
    /// and the next timeline must fall back to Kadō — while the stored
    /// pick survives, so the pack coming back restores it.
    @Test("The widgets' theme is the stored pick, gated on the pack mirror")
    func renderedThemeIsGated() {
        let (suite, name) = makeSuite()
        let (supporter, supporterName) = makeSuite()
        defer { tearDown(name); tearDown(supporterName) }

        HabitThemeDefaults.setTheme(.autumn, in: suite)
        #expect(HabitThemeDefaults.renderedTheme(in: suite, supporterDefaults: supporter) == .kado)

        SupporterDefaults.setSupporter(true, in: supporter)
        #expect(HabitThemeDefaults.renderedTheme(in: suite, supporterDefaults: supporter) == .autumn)

        SupporterDefaults.setSupporter(false, in: supporter)
        #expect(HabitThemeDefaults.renderedTheme(in: suite, supporterDefaults: supporter) == .kado)
        #expect(HabitThemeDefaults.theme(in: suite) == .autumn)

        HabitThemeDefaults.setTheme(.classic, in: suite)
        #expect(HabitThemeDefaults.renderedTheme(in: suite, supporterDefaults: supporter) == .classic)
    }

    /// `@AppStorage` in `KadoApp` and the widgets' `theme()` read the
    /// same key; this pins the stored shape both sides agree on.
    @Test("The stored value is the theme's raw string")
    func storesRawValue() {
        let (suite, name) = makeSuite()
        defer { tearDown(name) }

        HabitThemeDefaults.setTheme(.classic, in: suite)
        #expect(suite.string(forKey: HabitThemeDefaults.key) == "classic")
    }
}
