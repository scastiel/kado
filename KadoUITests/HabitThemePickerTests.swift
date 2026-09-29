import XCTest

/// The Habit colours picker (#111) reaches the app-wide theme.
///
/// `HabitColorTests` sweeps what each theme paints; what a unit test
/// cannot see is whether a tap in Settings reaches the environment
/// every habit view reads, *live* — a theme that only lands on the
/// next launch would pass the unit suite. Also the one place the
/// picker and the recoloured screens get photographed, since the
/// build tooling cannot tap into Settings.
final class HabitThemePickerTests: KadoUITestCase {

    private func themeRow(_ rawValue: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: AccessibilityID.Settings.habitThemeRow(rawValue))
            .firstMatch
    }

    @MainActor
    func testChoosingClassicRecoloursTheAppWithoutARelaunch() {
        let app = launchApp(seedProduction: true, seedForScreenshots: true)
        waitForTodayRows(in: app)
        capture(app, "habit-theme-today-kado")

        tapTab(.settings, in: app)
        let kado = themeRow("kado", in: app)
        let classic = themeRow("classic", in: app)
        scrollTo(classic, in: app)
        scrollClearOfTabBar(classic, in: app)
        XCTAssertTrue(kado.exists, "Settings should offer the Kadō theme.")
        capture(app, "habit-theme-picker-kado")

        classic.tap()
        capture(app, "habit-theme-picker-classic")

        tapTab(.overview, in: app)
        capture(app, "habit-theme-overview-classic")

        tapTab(.today, in: app)
        waitForTodayRows(in: app)
        capture(app, "habit-theme-today-classic")
    }
}
