import XCTest

/// The day-complete celebration, end to end: the edge is detected in
/// the snapshot rebuild after a save, and the overlay that answers it
/// has no seam a unit test could assert on. So this drives the real
/// app — an empty store, one habit created through the sheet, one tap
/// on its pill — and waits for the caption that rides along with the
/// confetti.
final class DayCompletionCelebrationTests: KadoUITestCase {

    @MainActor
    func testCompletingTheOnlyDueHabitShowsTheCelebration() {
        let app = launchApp(seedProduction: false)

        tapTab(.today, in: app)
        createHabit(named: "Stretch", in: app)
        waitForTodayRows(in: app)

        let row = todayRows(in: app).firstMatch
        // The row is one accessibility element (see `HabitRowView`), so
        // its pill can't be addressed on its own. The check circle sits
        // at the trailing edge; the centre of the row would push
        // Detail instead.
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()

        let caption = app.descendants(matching: .any)[AccessibilityID.Celebration.caption]
        XCTAssertTrue(
            caption.waitForExistence(timeout: 5),
            "Completing the only habit due today should show the “All done for today” caption."
        )
        // A beat in, so the confetti is mid-air in the picture rather
        // than still bunched above the top edge.
        Thread.sleep(forTimeInterval: 0.8)
        capture(app, "celebration")
        XCTAssertEqual(app.state, .runningForeground)
    }

    @MainActor
    func testTheCelebrationLetsTouchesThrough() {
        let app = launchApp(seedProduction: false)

        tapTab(.today, in: app)
        createHabit(named: "Stretch", in: app)
        waitForTodayRows(in: app)

        let row = todayRows(in: app).firstMatch
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        let caption = app.descendants(matching: .any)[AccessibilityID.Celebration.caption]
        XCTAssertTrue(caption.waitForExistence(timeout: 5))

        // With the overlay up, the + in the toolbar must still open the
        // sheet — the confetti is decoration, not a modal.
        app.buttons[AccessibilityID.Today.newHabitButton].firstMatch.tap()
        XCTAssertTrue(
            app.textFields[AccessibilityID.NewHabit.nameField].waitForExistence(timeout: 10),
            "A tap through the celebration overlay should reach the toolbar."
        )
    }

    // MARK: - Driving

    /// Creates a daily yes/no habit — the sheet's defaults — with the
    /// given name, and waits for the sheet to go away.
    @MainActor
    private func createHabit(named name: String, in app: XCUIApplication) {
        app.buttons[AccessibilityID.Today.newHabitButton].firstMatch.tap()
        let field = app.textFields[AccessibilityID.NewHabit.nameField]
        XCTAssertTrue(field.waitForExistence(timeout: 10), "The New Habit sheet never appeared.")
        field.tap()
        field.typeText(name)
        let save = app.buttons[AccessibilityID.NewHabit.saveButton].firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()
        XCTAssertTrue(
            field.waitForNonExistence(timeout: 10),
            "The New Habit sheet should dismiss after Save."
        )
    }
}
