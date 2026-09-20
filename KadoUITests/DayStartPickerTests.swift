import XCTest

/// The "Day starts at" picker offers every hour of the day (#93).
///
/// `DayStartDefaultsTests` pins the range; what a unit test cannot see
/// is whether the row the range produces is *reachable* — a list that
/// clips, or a selection that never reaches the binding, compiles and
/// passes the unit suite. This is also the one place the widened
/// picker gets photographed, since the build tooling cannot tap into
/// Settings.
final class DayStartPickerTests: KadoUITestCase {

    /// An hour's label follows the simulator's 24-Hour Time setting,
    /// which `launchApp` cannot pin the way it pins the language — the
    /// same run reads `2:00 PM` on one machine and `14:00` on another.
    /// Both spellings of the hour are accepted; the 12-hour one carries
    /// Foundation's narrow no-break space (`U+202F`) before the period,
    /// which prints as a space and never matches one.
    private func hourRow(twelveHour: String, twentyFourHour: String) -> NSPredicate {
        NSPredicate(format: "label == %@ OR label == %@", twelveHour, twentyFourHour)
    }

    private func rowShowing(_ predicate: NSPredicate, in app: XCUIApplication) -> XCUIElement {
        // The pushed list's rows come through as buttons on current
        // releases; matching any type keeps the test from caring.
        app.descendants(matching: .any).matching(predicate).firstMatch
    }

    @MainActor
    func testAnAfternoonHourCanBeChosen() {
        let app = launchApp()
        tapTab(.settings, in: app)

        let picker = app.descendants(matching: .any)[AccessibilityID.Settings.dayStartPicker].firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 10), "Settings should show the Day starts at picker.")
        picker.tap()

        // 2 PM is fifteen rows down a list of twenty-four, so it is
        // below the fold of the pushed list and not in the hierarchy
        // until something scrolls — see `scrollTo`.
        let twoPM = hourRow(twelveHour: "2:00\u{202F}PM", twentyFourHour: "14:00")
        let twoPMRow = rowShowing(twoPM, in: app)
        XCTAssertTrue(
            rowShowing(hourRow(twelveHour: "1:00\u{202F}AM", twentyFourHour: "01:00"), in: app)
                .waitForExistence(timeout: 10),
            "Tapping the row should push the list of hours."
        )
        scrollTo(twoPMRow, in: app)
        capture(app, "day-start-list-afternoon")
        twoPMRow.tap()

        // A navigation-link picker pops on selection, and the row it
        // returns to should read the chosen hour.
        let updated = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@", AccessibilityID.Settings.dayStartPicker))
            .matching(NSPredicate(format: "label CONTAINS %@ OR label CONTAINS %@", "2:00\u{202F}PM", "14:00"))
            .firstMatch
        XCTAssertTrue(updated.waitForExistence(timeout: 10), "The picker row should read 2 PM after choosing it.")

        // And the footer swaps from the midnight explanation to the
        // custom-hour one.
        let footer = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Until this hour, Today still shows the previous day")
        ).firstMatch
        XCTAssertTrue(footer.waitForExistence(timeout: 5), "The custom-hour footer should replace the midnight one.")
        capture(app, "day-start-2pm-selected")
    }
}
