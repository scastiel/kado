import XCTest

/// Typing a value into the log sheets, end to end (issue #100).
///
/// "Log specific value…" used to open a second stepper, so 25 was
/// twenty-five taps either way. The sheets now lead with a number
/// field that is focused on appear with its prefilled value selected,
/// and that selection is the part no unit test can see: `TextSelection`
/// only takes once the field is first responder, inside a presented
/// sheet, with the keyboard up. So these drive the real thing — a
/// value typed over the prefill has to *replace* it (`3` → `25`), not
/// extend it (`325`) — and read the result back off the Today row.
///
/// The row is found by pushing details, not by opening menus: a
/// context menu never reports idle to XCUITest on this OS, so every
/// step taken while one is up waits out a 60s timeout. Each test opens
/// exactly the menus it is about.
final class LogValueSheetTests: KadoUITestCase {

    /// The counter sheet from the Today row's menu, twice: once over
    /// the seed's empty today, and once over the value the first save
    /// left, which is the case that tells select-all from append.
    @MainActor
    func testTypingACounterValueReplacesThePrefill() throws {
        let app = launchApp(devMode: true)

        tapTab(.today, in: app)
        waitForTodayRows(in: app)
        let habitID = try XCTUnwrap(openCounterHabitDetail(in: app))
        popToToday(in: app)
        let row = AccessibilityID.Today.row(habitID)

        openLogSheet(fromRow: row, in: app)
        let field = app.textFields[AccessibilityID.LogSheet.counterField]
        XCTAssertTrue(field.waitForExistence(timeout: 10), "The counter sheet never appeared.")
        // Worth an assertion only because the field's placeholder is no
        // longer "0": XCUITest reports a *placeholder* as an empty
        // field's `value`, so while the two matched, this passed whether
        // or not the prefill had run at all.
        XCTAssertEqual(field.value as? String, "0", "Today is empty in the seed, so the field should prefill with 0.")

        // Over the cap: rejected outright, never clamped to a number
        // nobody typed. The prefill is selected, so this replaces it.
        let save = app.buttons[AccessibilityID.LogSheet.saveButton]
        field.typeText("1234567")
        XCTAssertFalse(save.isEnabled, "Save should be disabled while the number is above the cap.")

        // An empty field must not save as 0 and clear the day. Checked
        // here, where a delete empties the field whether or not the
        // prefill was selected — the second pass is what tells those
        // apart, and a delete there would hide the difference.
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 7))
        // Also pins what makes the prefill assertion above mean
        // anything: an empty field reports its placeholder as its
        // value, and that placeholder is the title, not "0". The run
        // pins English, so the literal is safe here.
        XCTAssertEqual(field.value as? String, "Today's value", "The field should be empty, showing its placeholder.")
        XCTAssertFalse(save.isEnabled, "Save should be disabled while the field is empty.")

        field.typeText("3")
        XCTAssertTrue(save.isEnabled)
        tapSave(in: app)
        XCTAssertTrue(
            waited(forRow: row, toReadValue: "3 of 8", in: app),
            "Saving 3 should put 3 on the row; it reads \(value(ofRow: row, in: app))."
        )

        openLogSheet(fromRow: row, in: app)
        XCTAssertTrue(field.waitForExistence(timeout: 10), "The counter sheet never reappeared.")
        XCTAssertEqual(field.value as? String, "3", "Reopening should prefill with the saved value.")

        // Typed straight over the prefill, no delete first: this is the
        // select-all under test.
        field.typeText("25")
        capture(app, "counter-sheet-typed-25")
        tapSave(in: app)
        XCTAssertTrue(
            waited(forRow: row, toReadValue: "25 of 8", in: app),
            "Typing 25 over a selected 3 should save 25, not 325; the row reads \(value(ofRow: row, in: app))."
        )
    }

    /// The timer sheet from the detail's "Log a session", with minutes
    /// typed over the target it prefills with.
    @MainActor
    func testTypingASessionLengthReplacesThePrefill() throws {
        let app = launchApp(devMode: true)

        tapTab(.today, in: app)
        waitForTodayRows(in: app)
        let habitID = try XCTUnwrap(openTimerHabitDetail(in: app))
        let row = AccessibilityID.Today.row(habitID)

        app.buttons[AccessibilityID.HabitDetail.logSessionButton].tap()
        let field = app.textFields[AccessibilityID.LogSheet.timerField]
        XCTAssertTrue(field.waitForExistence(timeout: 10), "The timer sheet never appeared.")
        XCTAssertEqual(
            field.value as? String, "30",
            "With nothing logged today the field should prefill with the 30-minute target."
        )

        field.typeText("45")
        capture(app, "timer-sheet-typed-45")
        tapSave(in: app)

        popToToday(in: app)
        XCTAssertTrue(
            waited(forRow: row, toReadValue: "45 of 30 minutes", in: app),
            "Typing 45 over a selected 30 should save 45 minutes; the row reads \(value(ofRow: row, in: app))."
        )
    }

    // MARK: - Driving

    /// Pops the detail that `openHabitDetail` left pushed.
    @MainActor
    private func popToToday(in app: XCUIApplication) {
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(
            app.buttons[AccessibilityID.HabitDetail.scoreCard].waitForNonExistence(timeout: 10),
            "Popping the detail should return to Today."
        )
    }

    /// Opens the log sheet from a row's long-press menu.
    @MainActor
    private func openLogSheet(fromRow row: String, in app: XCUIApplication) {
        element(ofRow: row, in: app).press(forDuration: 1)
        let menuItem = app.buttons[AccessibilityID.Today.logValueMenuItem].firstMatch
        XCTAssertTrue(menuItem.waitForExistence(timeout: 5), "The row's menu should offer Log specific value…")
        menuItem.tap()
    }

    @MainActor
    private func tapSave(in app: XCUIApplication) {
        let save = app.buttons[AccessibilityID.LogSheet.saveButton]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        XCTAssertTrue(save.isEnabled, "Save should be enabled with a number in the field.")
        save.tap()
        XCTAssertTrue(save.waitForNonExistence(timeout: 5), "Saving should dismiss the sheet.")
    }

    // MARK: - Reading the row

    /// The row, for gestures: the outermost of the elements carrying
    /// its identifier, which is the one that covers the row's area. A
    /// `List` row answers to its identifier twice — the cell and the
    /// content inside it — so a plain subscript is ambiguous.
    @MainActor
    private func element(ofRow row: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: row).firstMatch
    }

    /// The row's accessibility value, for a failure message: whichever
    /// of its elements carries one.
    @MainActor
    private func value(ofRow row: String, in app: XCUIApplication) -> String {
        let elements = app.descendants(matching: .any).matching(identifier: row).allElementsBoundByIndex
        return elements.compactMap { $0.value as? String }.first { !$0.isEmpty } ?? "nothing"
    }

    /// Whether the row's accessibility value came to lead with `value`
    /// — "25 of 8" out of "25 of 8, streak 1, score 40 percent".
    /// Matched on identifier and value together, so it doesn't matter
    /// which of the row's elements carries the value. Waited on rather
    /// than read once, because the read straight after the sheet
    /// dismisses races the list's update. The run pins English.
    @MainActor
    private func waited(
        forRow row: String, toReadValue value: String, in app: XCUIApplication, timeout: TimeInterval = 5
    ) -> Bool {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@ AND value BEGINSWITH %@", row, value))
            .firstMatch
            .waitForExistence(timeout: timeout)
    }
}
