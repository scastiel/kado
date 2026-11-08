import XCTest

/// Logging a yes/no habit as a hard day, end to end, from both places
/// it is offered: a Today row's long-press menu, and the day popover on
/// the detail calendar. Both are gestures wired for the first time, and
/// a menu item or a button that never fires looks exactly like one that
/// does until somebody taps it.
final class HardDayTests: KadoUITestCase {

    @MainActor
    func testLoggingTodayAsAHardDayFromTheRowMenu() {
        let app = launchApp(devMode: true)

        tapTab(.today, in: app)
        waitForTodayRows(in: app)

        let row = meditationRow(in: app)
        scrollClearOfTabBar(row, in: app)
        row.press(forDuration: 1)
        let item = app.buttons[AccessibilityID.Today.hardDayMenuItem].firstMatch
        XCTAssertTrue(
            item.waitForExistence(timeout: 5),
            "Long-pressing a yes/no row should offer to log a hard day."
        )
        capture(app, "today-row-menu")
        item.tap()

        XCTAssertTrue(
            waited(for: row, toEndWith: "hard day"),
            "The row should read as a hard day after the menu item; it reads \(row.label)."
        )
        capture(app, "today-hard-day")
    }

    @MainActor
    func testLoggingAPastHardDayShowsTheMonthSummary() {
        let app = launchApp(devMode: true)

        tapTab(.today, in: app)
        waitForTodayRows(in: app)
        meditationRow(in: app).tap()
        XCTAssertTrue(
            app.buttons[AccessibilityID.HabitDetail.scoreCard].waitForExistence(timeout: 10),
            "Tapping a Today row should push its detail."
        )

        // `DevModeSeed` logs on odd days-ago only, so two days ago is
        // empty: the hard day is the month's first.
        let summary = app.descendants(matching: .any)[AccessibilityID.HabitDetail.hardDaySummary]
        XCTAssertFalse(summary.exists, "A month without hard days shouldn't show the summary.")
        openDayEditPopover(daysAgo: 2, in: app)
        let hardDay = app.buttons[AccessibilityID.DayEdit.hardDay].firstMatch
        XCTAssertTrue(hardDay.waitForExistence(timeout: 10), "The popover should offer a hard day.")
        capture(app, "day-edit-hard-day")
        hardDay.tap()
        XCTAssertTrue(hardDay.waitForNonExistence(timeout: 5), "Logging a hard day should close the popover.")
        capture(app, "detail-calendar-hard-day")

        scrollTo(summary, in: app)
        XCTAssertTrue(summary.waitForExistence(timeout: 5), "The month should now count its hard day.")
        XCTAssertTrue(summary.label.contains("1 hard day"), "The summary reads \(summary.label).")
        capture(app, "detail-month-summary")
    }

    // MARK: - Helpers

    /// The seeded daily yes/no habit's row. By its label, which leads
    /// with the habit's name: `launchApp` pins English, and the seed
    /// draws row ids fresh each run.
    @MainActor
    private func meditationRow(in app: XCUIApplication) -> XCUIElement {
        let row = todayRows(in: app)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Morning meditation"))
            .firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "The seeded meditation habit has no Today row.")
        return row
    }

    @MainActor
    private func waited(for element: XCUIElement, toEndWith suffix: String) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label ENDSWITH %@", suffix),
            object: element
        )
        return XCTWaiter().wait(for: [expectation], timeout: 5) == .completed
    }

    /// Taps the detail calendar's cell for `daysAgo`, stepping back a
    /// month first when it falls in the previous one. The same walk as
    /// `DayEditPopoverTests`.
    @MainActor
    private func openDayEditPopover(daysAgo: Int, in app: XCUIApplication) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let target = calendar.date(byAdding: .day, value: -daysAgo, to: today)!
        if !calendar.isDate(target, equalTo: today, toGranularity: .month) {
            let previous = app.buttons[AccessibilityID.HabitDetail.previousMonthButton].firstMatch
            scrollTo(previous, in: app)
            previous.tap()
        }
        let day = calendar.component(.day, from: target)
        let cell = app.descendants(matching: .any)[AccessibilityID.HabitDetail.calendarDay(day)]
        scrollTo(cell, in: app)
        cell.tap()
    }
}
