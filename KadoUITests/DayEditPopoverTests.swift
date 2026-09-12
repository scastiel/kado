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
        let value = app.staticTexts[AccessibilityID.HabitDetail.DayEdit.value]
        XCTAssertTrue(value.waitForExistence(timeout: 10), "The day-edit popover never appeared.")
        XCTAssertEqual(
            value.value as? String, "0",
            "Day \(day) should start empty — the seed leaves even days-ago without a record."
        )

        for _ in 0..<3 {
            tapIncrement(in: app)
        }

        capture(app, "day-edit-after-three-taps")
        XCTAssertTrue(
            waited(for: value, toRead: "3"),
            "Three taps on + should read 3; the popover shows \(value.value ?? "nil") — this is issue #80."
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
        XCTAssertEqual(value.value as? String, "0", "Today should start empty in the seed.")

        let plus = app.buttons[AccessibilityID.HabitDetail.quickLogIncrement].firstMatch
        for _ in 0..<3 {
            plus.tap()
        }

        capture(app, "quick-log-after-three-taps")
        XCTAssertTrue(
            waited(for: value, toRead: "3"),
            "Three taps on the quick-log + should read 3; it shows \(value.value ?? "nil")."
        )
    }

    // MARK: - Driving

    /// Pushes the detail of the seeded counter habit.
    ///
    /// Today rows are keyed by a `UUID` the seed draws fresh each run,
    /// so the habit can't be addressed by identifier. Each row is
    /// pushed in turn and asked whether it shows the counter quick-log;
    /// the seed has one counter habit among a handful, so this is a
    /// few pushes at most.
    @MainActor
    private func openCounterHabitDetail(in app: XCUIApplication) {
        let rows = todayRows(in: app)
        let scoreCard = app.buttons[AccessibilityID.HabitDetail.scoreCard]
        let quickLogIncrement = app.buttons[AccessibilityID.HabitDetail.quickLogIncrement]
        for index in 0..<rows.count {
            rows.element(boundBy: index).tap()
            XCTAssertTrue(scoreCard.waitForExistence(timeout: 10), "Tapping a Today row should push its detail.")
            if quickLogIncrement.waitForExistence(timeout: 2) {
                return
            }
            app.navigationBars.buttons.firstMatch.tap()
            XCTAssertTrue(scoreCard.waitForNonExistence(timeout: 10), "Popping the detail should return to Today.")
        }
        XCTFail("No Today row pushed a counter habit's detail.")
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
            app.buttons[AccessibilityID.HabitDetail.previousMonthButton].firstMatch.tap()
        }
        let day = calendar.component(.day, from: target)
        let cell = app.descendants(matching: .any)[AccessibilityID.HabitDetail.calendarDay(day)]
        scrollTo(cell, in: app)
        cell.tap()
        return day
    }

    /// Taps the popover's `+`.
    ///
    /// Re-queried on every call rather than held: if the popover were
    /// ever re-presented under a tap, a held element would go stale.
    @MainActor
    private func tapIncrement(in app: XCUIApplication) {
        // Task 3 replaces the Stepper with a Button carrying
        // `AccessibilityID.HabitDetail.DayEdit.increment`.
        let plus = app.steppers.firstMatch.buttons["Increment"]
        XCTAssertTrue(plus.waitForExistence(timeout: 5), "The popover's + never appeared.")
        plus.tap()
    }

    /// Whether a text's accessibility value came to read `value` within
    /// the timeout. Re-read rather than compared once, because the
    /// read straight after a tap races the update.
    @MainActor
    private func waited(
        for element: XCUIElement, toRead value: String, timeout: TimeInterval = 5
    ) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", value),
            object: element
        )
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
