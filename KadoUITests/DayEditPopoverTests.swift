import XCTest

/// The habit detail screen following its own edits, end to end
/// (issue #80).
///
/// Stepping a counter showed the first tap and froze there, while every
/// later tap still landed in the store. The freeze lived in how the
/// screen resolved the record it was about to mutate — a fetch, in a
/// view with no `@Query` of its own — so nothing on the screen
/// re-rendered on a value-only save. A crash-free SwiftUI update pass
/// has no seam a unit test could assert on (the SwiftData half is
/// pinned in `ObservationAfterFetchTests`), so these drive the real
/// thing: the seeded counter habit, a few taps, and a read of what the
/// screen displays. The quick-log test is the one that goes red on the
/// old shape; the popover test guards the reported surface.
final class DayEditPopoverTests: KadoUITestCase {

    /// The reported case: a past day, stepped from the calendar popover.
    @MainActor
    func testSteppingACounterDayKeepsTheDisplayInStep() {
        let app = launchApp(devMode: true)

        tapTab(.today, in: app)
        waitForTodayRows(in: app)
        openCounterHabitDetail(in: app)

        // `DevModeSeed` logs the counter habit on odd days-ago only, so
        // two days ago is empty and the first tap *inserts* a record —
        // the one step that used to refresh the screen. The taps after
        // it are the ones that didn't.
        let day = openDayEditPopover(daysAgo: 2, in: app)
        let value = app.staticTexts[AccessibilityID.DayEdit.value]
        XCTAssertTrue(value.waitForExistence(timeout: 10), "The day-edit popover never appeared.")
        XCTAssertEqual(
            number(in: value), "0",
            "Day \(day) should start empty — the seed leaves even days-ago without a record."
        )

        for _ in 0..<3 {
            tapDayEditIncrement(in: app)
        }

        capture(app, "day-edit-after-three-taps")
        XCTAssertTrue(
            waited(for: value, toRead: "3"),
            "Three taps on + should read 3; the popover shows \(value.label) — this is issue #80."
        )
    }

    /// The same defect on the screen's own quick-log, which nobody had
    /// reported: today starts empty in the seed too.
    @MainActor
    func testSteppingTodayFromTheQuickLogKeepsTheDisplayInStep() {
        let app = launchApp(devMode: true)

        tapTab(.today, in: app)
        waitForTodayRows(in: app)
        openCounterHabitDetail(in: app)

        let value = app.staticTexts[AccessibilityID.HabitDetail.quickLogValue]
        XCTAssertTrue(value.waitForExistence(timeout: 10))
        XCTAssertEqual(number(in: value), "0", "Today should start empty in the seed.")

        let plus = app.buttons[AccessibilityID.HabitDetail.quickLogIncrement].firstMatch
        for _ in 0..<3 {
            plus.tap()
        }

        capture(app, "quick-log-after-three-taps")
        XCTAssertTrue(
            waited(for: value, toRead: "3"),
            "Three taps on the quick-log + should read 3; it shows \(value.label)."
        )
    }

    /// The timer control, and stepping back down: `−` from one minute
    /// hands zero seconds to the parent, which routes it through
    /// `clear`, and the popover has to read 0 afterwards.
    @MainActor
    func testSteppingATimerDayUpAndBackToZero() {
        let app = launchApp(devMode: true)

        tapTab(.today, in: app)
        waitForTodayRows(in: app)
        openTimerHabitDetail(in: app)

        openDayEditPopover(daysAgo: 2, in: app)
        let value = app.staticTexts[AccessibilityID.DayEdit.value]
        XCTAssertTrue(value.waitForExistence(timeout: 10), "The day-edit popover never appeared.")
        XCTAssertEqual(number(in: value), "0")

        tapDayEditIncrement(in: app)
        tapDayEditIncrement(in: app)
        XCTAssertTrue(
            waited(for: value, toRead: "2"),
            "Two taps on + should read 2 minutes; it shows \(value.label)."
        )

        let minus = app.buttons[AccessibilityID.DayEdit.decrement].firstMatch
        minus.tap()
        minus.tap()
        capture(app, "timer-day-back-to-zero")
        XCTAssertTrue(
            waited(for: value, toRead: "0"),
            "Two taps on − should read 0; it shows \(value.label)."
        )
        XCTAssertFalse(
            app.buttons[AccessibilityID.DayEdit.clear].exists,
            "Clear should go away once the day is empty again."
        )
    }

    /// Done saves the note and closes the popover (#127); reopening
    /// the day shows the note back.
    @MainActor
    func testDoneSavesTheNoteAndClosesThePopover() {
        let app = launchApp(devMode: true)

        tapTab(.today, in: app)
        waitForTodayRows(in: app)
        openCounterHabitDetail(in: app)

        openDayEditPopover(daysAgo: 2, in: app)
        typeNote("Done saves this", in: app)
        app.buttons[AccessibilityID.DayEdit.noteDone].tap()

        XCTAssertTrue(
            app.staticTexts[AccessibilityID.DayEdit.value].waitForNonExistence(timeout: 5),
            "Done should close the popover."
        )
        assertNoteReads("Done saves this", onDaysAgo: 2, in: app)
    }

    /// Closing the popover any other way keeps the draft too. Done was
    /// the only path that wrote it, so a note tapped away from was lost.
    @MainActor
    func testTappingOutsideSavesTheNote() {
        let app = launchApp(devMode: true)

        tapTab(.today, in: app)
        waitForTodayRows(in: app)
        openCounterHabitDetail(in: app)

        openDayEditPopover(daysAgo: 2, in: app)
        typeNote("Tapped away from", in: app)
        app.otherElements["PopoverDismissRegion"].firstMatch.tap()

        XCTAssertTrue(
            app.staticTexts[AccessibilityID.DayEdit.value].waitForNonExistence(timeout: 5),
            "A tap outside should close the popover."
        )
        assertNoteReads("Tapped away from", onDaysAgo: 2, in: app)
    }

    // MARK: - Driving

    /// Opens the note field and types into it. Tapped rather than
    /// trusted to auto-focus, which iOS 26.5 drops.
    @MainActor
    private func typeNote(_ text: String, in app: XCUIApplication) {
        let expand = app.buttons[AccessibilityID.DayEdit.noteExpand]
        XCTAssertTrue(expand.waitForExistence(timeout: 10), "The day-edit popover never appeared.")
        expand.tap()
        let field = noteField(in: app)
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(text)
    }

    /// Reopens the day and reads the note field, which a day with a
    /// note opens expanded.
    @MainActor
    private func assertNoteReads(
        _ text: String, onDaysAgo daysAgo: Int, in app: XCUIApplication,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        openDayEditPopover(daysAgo: daysAgo, in: app)
        let field = noteField(in: app)
        XCTAssertTrue(
            field.waitForExistence(timeout: 10),
            "Reopening the day should show its note.", file: file, line: line
        )
        capture(app, "day-edit-note-reopened")
        XCTAssertEqual(field.value as? String, text, file: file, line: line)
    }

    @MainActor
    private func noteField(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: AccessibilityID.DayEdit.noteField)
            .firstMatch
    }

    /// Taps the calendar cell for the given day, navigating back a
    /// month first when it falls in the previous one, and returns the
    /// day-of-month it tapped.
    @MainActor
    @discardableResult
    private func openDayEditPopover(daysAgo: Int, in app: XCUIApplication) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let target = calendar.date(byAdding: .day, value: -daysAgo, to: today)!
        if !calendar.isDate(target, equalTo: today, toGranularity: .month) {
            // Below the fold on a short device or at a large text size;
            // `tap()` on an existing-but-not-hittable element fails.
            let previous = app.buttons[AccessibilityID.HabitDetail.previousMonthButton].firstMatch
            scrollTo(previous, in: app)
            previous.tap()
        }
        let day = calendar.component(.day, from: target)
        let cell = app.descendants(matching: .any)[AccessibilityID.HabitDetail.calendarDay(day)]
        scrollTo(cell, in: app)
        cell.tap()
        return day
    }
}
