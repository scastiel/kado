import XCTest

/// Deleting a completion from the detail's History list, end to end
/// (issue #87).
///
/// The list draws its rows in a `LazyVStack`, and the delete on them
/// was `swipeActions` — which SwiftUI honours only on the rows of a
/// `List`. It compiled, was rewired and described as working, and
/// never fired. Nothing short of the real gesture on the real screen
/// can tell an inert modifier from a working one, so this drives it:
/// the seeded counter habit, a long-press on its newest row, Delete,
/// and a look at what is left.
final class CompletionHistoryTests: KadoUITestCase {

    @MainActor
    func testDeletingARowFromItsLongPressMenuRemovesIt() {
        let app = launchApp(devMode: true)

        tapTab(.today, in: app)
        waitForTodayRows(in: app)
        openCounterHabitDetail(in: app)

        // History sits under the calendar, below the fold, and its rows
        // are lazy: none is in the hierarchy until it scrolls in. Coming
        // down from the top, the first row realized is the newest —
        // yesterday's, since the seed logs the counter habit on odd
        // days-ago only. Its id is taken here, before any further
        // scrolling can change what `firstMatch` resolves to.
        let first = historyRows(in: app).firstMatch
        scrollTo(first, in: app)
        let deleted = first.identifier
        let row = app.descendants(matching: .any)[deleted]
        scrollClearOfTabBar(row, in: app)

        row.press(forDuration: 1)
        let delete = app.buttons[AccessibilityID.HabitDetail.historyDeleteButton].firstMatch
        XCTAssertTrue(
            delete.waitForExistence(timeout: 5),
            "Long-pressing a History row should open a menu with Delete in it."
        )
        capture(app, "history-row-menu")
        delete.tap()

        XCTAssertTrue(
            row.waitForNonExistence(timeout: 5),
            "Delete should remove the row it was chosen on — this is issue #87."
        )
        // Only that row: the list is still there, headed by another one.
        let remaining = historyRows(in: app).firstMatch
        XCTAssertTrue(remaining.waitForExistence(timeout: 5), "The History list should still have rows.")
        XCTAssertNotEqual(remaining.identifier, deleted)
        capture(app, "history-after-delete")
    }

    /// The History rows currently realized, addressed by the identifier
    /// prefix: the seed draws completion ids fresh each run.
    @MainActor
    private func historyRows(in app: XCUIApplication) -> XCUIElementQuery {
        elements(withIdentifierPrefix: AccessibilityID.HabitDetail.historyRowPrefix, in: app)
    }
}
