import XCTest

/// The Overview matrix editing a day from its own popover, end to end
/// (issue #92).
///
/// The matrix is computed from value snapshots and mutates through its
/// own `@Query`, the shape the detail screen settled on after issue
/// #80 — and, as there, whether the screen *follows* its edits is
/// something only the running app can answer. The counter test is
/// that check: two taps on `+` must read 2, not the 1 a screen stuck
/// on its first render would show. The binary test covers the surface
/// the issue asked for, a habit marked done from the matrix.
final class OverviewDayEditTests: KadoUITestCase {

    /// Stepping today's cell of the counter habit, and reading the
    /// popover after each tap.
    @MainActor
    func testSteppingTodayFromTheOverviewPopoverKeepsTheDisplayInStep() throws {
        let app = launchApp(devMode: true)

        // The suite can only learn a habit's id from its Today row, and
        // only tell the counter habit apart by pushing its detail. The
        // Overview's row order is not something to rely on: the seed
        // never sets `sortOrder`.
        tapTab(.today, in: app)
        waitForTodayRows(in: app)
        let habitID = try XCTUnwrap(openCounterHabitDetail(in: app), "No counter habit in the seed.")
        app.navigationBars.buttons.firstMatch.tap()

        tapTab(.overview, in: app)
        let cell = app.buttons[AccessibilityID.Overview.cell(habitID, daysAgo: 0)]
        XCTAssertTrue(cell.waitForExistence(timeout: 10), "Today's cell for the counter habit never appeared.")
        scrollTo(cell, in: app)
        cell.tap()

        // `DevModeSeed` logs the counter habit on odd days-ago only, so
        // today starts empty and the first tap inserts a record — the
        // one step that would refresh a screen stuck on inserts alone.
        let value = app.staticTexts[AccessibilityID.DayEdit.value]
        XCTAssertTrue(value.waitForExistence(timeout: 10), "The day-edit popover never appeared.")
        XCTAssertEqual(number(in: value), "0", "Today should start empty in the seed.")

        tapDayEditIncrement(in: app)
        tapDayEditIncrement(in: app)

        capture(app, "overview-day-edit-after-two-taps")
        XCTAssertTrue(
            waited(for: value, toRead: "2"),
            "Two taps on + should read 2; the popover shows \(value.label)."
        )
    }

    /// Marking a binary habit done from today's cell: the popover goes
    /// away on the tap, and the cell behind it now reads as completed.
    @MainActor
    func testMarkingABinaryHabitDoneFromTheOverviewPopover() throws {
        let app = launchApp(devMode: true)
        tapTab(.overview, in: app)

        let todayCells = elements(withIdentifierPrefix: AccessibilityID.Overview.cellPrefix, in: app)
            .matching(NSPredicate(format: "identifier ENDSWITH %@", ".0"))
        XCTAssertTrue(todayCells.firstMatch.waitForExistence(timeout: 10), "The matrix never appeared.")

        // Cells carry no type, so today's column is tried in turn until
        // a popover offers "Mark as done" — a binary habit with the day
        // still empty. The run pins English, and the negative habit's
        // button says "Mark as slipped" instead, so it is skipped.
        let toggle = app.buttons[AccessibilityID.DayEdit.toggle]
        var done: XCUIElement?
        for index in 0..<todayCells.count {
            let cell = todayCells.element(boundBy: index)
            scrollTo(cell, in: app)
            cell.tap()
            XCTAssertTrue(
                app.staticTexts[AccessibilityID.DayEdit.value].waitForExistence(timeout: 5)
                    || toggle.waitForExistence(timeout: 5),
                "Tapping a cell should open the day-edit popover."
            )
            if toggle.exists && toggle.label == "Mark as done" {
                done = cell
                break
            }
            dismissPopover(in: app)
        }
        let cell = try XCTUnwrap(done, "No binary habit with an empty today in the seed.")

        toggle.tap()
        capture(app, "overview-binary-marked-done")
        XCTAssertTrue(
            toggle.waitForNonExistence(timeout: 5),
            "The toggle should dismiss the popover."
        )
        let completed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS %@", "completed"),
            object: cell
        )
        XCTAssertEqual(
            XCTWaiter().wait(for: [completed], timeout: 5), .completed,
            "The cell should now read as completed; its label is \(cell.label)."
        )
    }

    // MARK: - Driving

    /// Closes the popover by tapping outside it, on the screen's title.
    @MainActor
    private func dismissPopover(in app: XCUIApplication) {
        app.navigationBars.firstMatch.tap()
        XCTAssertTrue(
            app.buttons[AccessibilityID.DayEdit.toggle].waitForNonExistence(timeout: 5)
                && app.staticTexts[AccessibilityID.DayEdit.value].waitForNonExistence(timeout: 5),
            "The popover should close on a tap outside it."
        )
    }
}
