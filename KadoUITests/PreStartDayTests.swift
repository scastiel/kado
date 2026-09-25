import XCTest

/// Days before a habit's start, end to end (issue #104).
///
/// Logging one of them moves the habit's effective start back to it
/// and turns every day in between into a miss. The Overview puts a
/// month of those days on screen looking like any other grey cell, so
/// there they are inert; the detail calendar is where back-dating
/// lives, and there the popover says what logging the day will do.
/// Both halves are about which element a tap reaches, which only the
/// running app can answer.
final class PreStartDayTests: KadoUITestCase {

    /// The issue's repro: a habit created today, and a tap on a grey
    /// cell to the left of it.
    @MainActor
    func testAPreStartOverviewCellOpensNothing() throws {
        let app = launchApp(seedProduction: false)
        tapTab(.today, in: app)
        createHabit(named: "Stretch", in: app)
        let habitID = try XCTUnwrap(createdHabitID(in: app))

        tapTab(.overview, in: app)
        let toggle = app.buttons[AccessibilityID.DayEdit.toggle]

        // Three days back is on screen at the matrix's trailing anchor
        // and, for a habit created today, before its start.
        let preStartID = AccessibilityID.Overview.cell(habitID, daysAgo: 3)
        let preStart = app.descendants(matching: .any)[preStartID]
        XCTAssertTrue(preStart.waitForExistence(timeout: 10), "The pre-start cell never appeared.")
        XCTAssertFalse(app.buttons[preStartID].exists, "A pre-start cell should not be a button.")
        preStart.tap()
        XCTAssertFalse(
            toggle.waitForExistence(timeout: 2),
            "Tapping a day before the habit's start should not open the day editor."
        )

        // Today's cell, beside it, still edits.
        let todayCell = app.buttons[AccessibilityID.Overview.cell(habitID, daysAgo: 0)]
        XCTAssertTrue(todayCell.waitForExistence(timeout: 5))
        todayCell.tap()
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), "Today's cell should open the day editor.")
    }

    /// The detail calendar keeps back-dating, and says so first.
    @MainActor
    func testAPreStartCalendarDayWarnsBeforeBackdating() throws {
        let app = launchApp(seedProduction: false)
        tapTab(.today, in: app)
        createHabit(named: "Stretch", in: app)
        waitForTodayRows(in: app)
        todayRows(in: app).firstMatch.tap()
        XCTAssertTrue(
            app.buttons[AccessibilityID.HabitDetail.scoreCard].waitForExistence(timeout: 10),
            "Tapping the Today row should push its detail."
        )

        openCalendarDay(daysAgo: 3, in: app)
        XCTAssertTrue(
            app.buttons[AccessibilityID.DayEdit.toggle].waitForExistence(timeout: 5),
            "A pre-start day on the detail calendar should still open the day editor."
        )
        capture(app, "pre-start-calendar-popover")
        XCTAssertTrue(
            app.staticTexts[AccessibilityID.DayEdit.backdateNotice].exists,
            "The popover should say that logging this day moves the habit's start."
        )
    }

    // MARK: - Driving

    /// The id of the only habit on Today, read off its row.
    @MainActor
    private func createdHabitID(in app: XCUIApplication) -> UUID? {
        waitForTodayRows(in: app)
        let identifier = todayRows(in: app).firstMatch.identifier
        return UUID(uuidString: String(identifier.dropFirst("today.row.".count)))
    }

    /// Taps the calendar cell `daysAgo` days back, going to the
    /// previous month first when it falls there.
    @MainActor
    private func openCalendarDay(daysAgo: Int, in app: XCUIApplication) {
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
