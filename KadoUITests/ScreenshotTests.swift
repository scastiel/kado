import XCTest

/// Takes the screenshots the App Store listing ships, one run per
/// language and per device.
///
/// This is not an assertion suite, and `make e2e` skips it —
/// `make screenshots` is what runs it, through `Scripts/screenshots.sh`.
/// What it *does* assert is that the screen it is about to photograph
/// has actually arrived: a photograph of an empty list looks like a
/// working app right up until someone opens the file.
///
/// The pictures leave as attachments on the result bundle, named
/// `01-today` and so on; the script exports them and names the files
/// after them, which is what puts them in order in App Store Connect.
///
/// Split in two on purpose. Light and dark are separate methods because
/// nothing inside a test can change the simulator's appearance —
/// `simctl ui <udid> appearance` can, and the script sets it between
/// the two passes.
final class ScreenshotTests: KadoUITestCase {

    // MARK: - Light

    @MainActor
    func testCaptureLightScreenshots() throws {
        let app = launch()

        // 1 — Today, with the demo habits due and a mix of states.
        waitForTodayRows(in: app)
        photograph(app, "01-today")

        // 2 — one habit's detail: the score, the streak, and the
        // monthly calendar underneath. The differentiator shot.
        todayRows(in: app).firstMatch.tap()
        assertReached(
            app.buttons[AccessibilityID.HabitDetail.scoreCard],
            "Tapping a Today row should push the habit's detail screen."
        )
        // Back one month, so the calendar in the picture is a whole one.
        // The current month is only as full as the day it was captured
        // on — a run on the 5th shows five filled squares and
        // twenty-five empty ones, which at thumbnail size reads as an
        // app nobody uses.
        app.buttons[AccessibilityID.HabitDetail.previousMonthButton].firstMatch.tap()
        photograph(app, "02-habit-detail")
        app.navigationBars.buttons.firstMatch.tap()

        // 3 — the Overview matrix, habits × days.
        tapTab(.overview, in: app)
        assertReached(
            app.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier BEGINSWITH %@", "overview.label."))
                .firstMatch,
            "The Overview tab should show the habit labels."
        )
        photograph(app, "03-overview")

        // 4 — the New Habit sheet, which is where the flexible
        // schedules live. Launched with the name field unfocused: the
        // keyboard would cover the frequency and type sections that
        // are the reason this shot is in the set.
        tapTab(.today, in: app)
        waitForTodayRows(in: app)
        app.buttons[AccessibilityID.Today.newHabitButton].firstMatch.tap()
        assertReached(
            app.textFields[AccessibilityID.NewHabit.nameField],
            "The toolbar's + should open the New Habit sheet."
        )
        photograph(app, "04-new-habit")
        app.buttons[AccessibilityID.NewHabit.cancelButton].firstMatch.tap()

        // 5 — Settings, which is where the privacy story is told:
        // iCloud status, reminders, export, and no account anywhere.
        tapTab(.settings, in: app)
        assertReached(
            app.navigationBars.firstMatch,
            "The Settings tab should show its own navigation bar."
        )
        photograph(app, "05-settings")
    }

    // MARK: - Dark

    /// The same Today screen the light pass opens with, on a simulator
    /// the script has switched to dark appearance.
    ///
    /// Worth a whole second pass: the paper-and-sage palette is drawn
    /// twice over, not dimmed, and a listing that shows only one of
    /// them is under-selling the half of the work that went into it.
    @MainActor
    func testCaptureDarkScreenshots() throws {
        let app = launch()
        waitForTodayRows(in: app)
        photograph(app, "06-today-dark")
    }

    // MARK: - Driving

    /// Launches with the demo dataset and the run's own language.
    ///
    /// `-uiTestRun` redirects the store to a throwaway file and drops
    /// CloudKit, so a screenshot run never touches — or syncs — the
    /// developer's real habits. The data is `ScreenshotSeed`'s: four
    /// months of authored history, in the run's own language, with the
    /// habits in a fixed order so the set can be diffed between runs.
    @MainActor
    private func launch() -> XCUIApplication {
        launchApp(
            seedProduction: true,
            language: Self.runLanguage,
            locale: Self.runLocale,
            seedForScreenshots: true,
            suppressNameAutoFocus: true
        )
    }

    /// The language `xcodebuild -testLanguage` started this run in.
    ///
    /// Read from the runner rather than passed in, because the app is
    /// launched by `launchApp`, which sets `-AppleLanguages` itself:
    /// whatever `-testLanguage` would have given the app is overwritten
    /// there, so the runner's own preference is the one honest source.
    private static var runLanguage: String {
        String((Locale.preferredLanguages.first ?? "en").prefix(2))
    }

    /// And the region that goes with it, so dates inside the pictures
    /// are written the way that locale writes them.
    private static var runLocale: String {
        switch runLanguage {
        case "fr": "fr_FR"
        default: "en_US"
        }
    }

    /// Waits for `element`, and says which screen failed to arrive
    /// rather than leaving a photograph of the previous one.
    @MainActor
    private func assertReached(
        _ element: XCUIElement,
        _ message: String,
        timeout: TimeInterval = 30,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            element.waitForExistence(timeout: timeout), message, file: file, line: line
        )
    }

    /// Photographs the app under the name the file should carry.
    ///
    /// A beat first: SwiftUI's navigation and sheet transitions are
    /// animated, and XCUITest will happily photograph one mid-slide.
    /// The name is the whole point — it is what orders the set in App
    /// Store Connect — so it goes on the attachment, and
    /// `Scripts/name-screenshots.py` turns it back into a file name.
    @MainActor
    private func photograph(_ app: XCUIApplication, _ name: String) {
        Thread.sleep(forTimeInterval: 1.0)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
