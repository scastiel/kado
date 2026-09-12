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
            number(in: value), "0",
            "Day \(day) should start empty — the seed leaves even days-ago without a record."
        )

        for _ in 0..<3 {
            tapIncrement(in: app)
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
        let value = app.staticTexts[AccessibilityID.HabitDetail.DayEdit.value]
        XCTAssertTrue(value.waitForExistence(timeout: 10), "The day-edit popover never appeared.")
        XCTAssertEqual(number(in: value), "0")

        tapIncrement(in: app)
        tapIncrement(in: app)
        XCTAssertTrue(
            waited(for: value, toRead: "2"),
            "Two taps on + should read 2 minutes; it shows \(value.label)."
        )

        let minus = app.buttons[AccessibilityID.HabitDetail.DayEdit.decrement].firstMatch
        minus.tap()
        minus.tap()
        capture(app, "timer-day-back-to-zero")
        XCTAssertTrue(
            waited(for: value, toRead: "0"),
            "Two taps on − should read 0; it shows \(value.label)."
        )
        XCTAssertFalse(
            app.buttons[AccessibilityID.HabitDetail.DayEdit.clear].exists,
            "Clear should go away once the day is empty again."
        )
    }

    // MARK: - Driving

    /// Pushes the detail of the seeded counter habit.
    @MainActor
    private func openCounterHabitDetail(in app: XCUIApplication) {
        openHabitDetail(showing: AccessibilityID.HabitDetail.quickLogIncrement, in: app)
    }

    /// Pushes the detail of the seeded timer habit.
    @MainActor
    private func openTimerHabitDetail(in app: XCUIApplication) {
        openHabitDetail(showing: AccessibilityID.HabitDetail.logSessionButton, in: app)
    }

    /// Pushes Today rows in turn until the detail shows the button with
    /// `marker`, and stays there.
    ///
    /// Today rows are keyed by a `UUID` the seed draws fresh each run,
    /// so a habit can't be addressed by identifier from the list. Each
    /// row is pushed and asked what it is; the seed has one habit of
    /// each type among a handful, so this is a few pushes at most.
    @MainActor
    private func openHabitDetail(showing marker: String, in app: XCUIApplication) {
        let rows = todayRows(in: app)
        let scoreCard = app.buttons[AccessibilityID.HabitDetail.scoreCard]
        let markerButton = app.buttons[marker]
        for index in 0..<rows.count {
            rows.element(boundBy: index).tap()
            XCTAssertTrue(scoreCard.waitForExistence(timeout: 10), "Tapping a Today row should push its detail.")
            if markerButton.waitForExistence(timeout: 2) {
                return
            }
            app.navigationBars.buttons.firstMatch.tap()
            XCTAssertTrue(scoreCard.waitForNonExistence(timeout: 10), "Popping the detail should return to Today.")
        }
        XCTFail("No Today row pushed a detail showing \(marker).")
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
        let plus = app.buttons[AccessibilityID.HabitDetail.DayEdit.increment].firstMatch
        XCTAssertTrue(plus.waitForExistence(timeout: 5), "The popover's + never appeared.")
        plus.tap()
    }

    /// The number a value text leads with — "3" out of "3 of 8", or the
    /// whole of the quick-log's "3".
    ///
    /// Read off the label rather than a separate `accessibilityValue`:
    /// giving the text one would have VoiceOver announce "3 of 8, 3".
    /// The run pins English, so the number does lead.
    @MainActor
    private func number(in element: XCUIElement) -> String {
        String(element.label.prefix { $0.isNumber })
    }

    /// Whether a text came to lead with `number` within the timeout.
    /// Re-read rather than compared once, because the read straight
    /// after a tap races the update.
    @MainActor
    private func waited(
        for element: XCUIElement, toRead number: String, timeout: TimeInterval = 5
    ) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label MATCHES %@", "^\(number)(\\D.*)?$"),
            object: element
        )
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
