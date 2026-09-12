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
        // are lazy: none is in the hierarchy until it scrolls in. The
        // newest row is yesterday's — the seed logs the counter habit on
        // odd days-ago only, so today is empty.
        let rows = historyRows(in: app)
        let first = rows.firstMatch
        scrollTo(first, in: app)
        scrollClearOfTabBar(first, in: app)
        let deleted = first.identifier
        XCTAssertTrue(
            deleted.hasPrefix(AccessibilityID.HabitDetail.historyRowPrefix),
            "Expected a History row, got “\(deleted)”."
        )

        first.press(forDuration: 1)
        let delete = app.buttons[AccessibilityID.HabitDetail.historyDeleteButton].firstMatch
        XCTAssertTrue(
            delete.waitForExistence(timeout: 5),
            "Long-pressing a History row should open a menu with Delete in it."
        )
        capture(app, "history-row-menu")
        delete.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)[deleted].waitForNonExistence(timeout: 5),
            "Delete should remove the row it was chosen on — this is issue #87."
        )
        // The list itself stays: fourteen completions remain, and the
        // one below has moved up into the first slot.
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 5), "The History list should still have rows.")
        XCTAssertNotEqual(rows.firstMatch.identifier, deleted)
        capture(app, "history-after-delete")
    }

    /// Scrolls until `element` sits wholly above the floating tab bar.
    ///
    /// `scrollTo` stops as soon as the element's *centre* can be tapped,
    /// which leaves a row at the bottom of the screen with its lower
    /// half under the bar. That is enough for a tap, but not for a
    /// long-press: the menu opens, and then the tap on its Delete is
    /// dropped — reproduced on the first run of this test, with the
    /// tap landing dead centre on the item and the menu staying up.
    /// One swipe further and the same tap goes through. iPad has no
    /// bar at the bottom, so there is nothing to clear there.
    @MainActor
    private func scrollClearOfTabBar(_ element: XCUIElement, in app: XCUIApplication) {
        let bar = app.tabBars.firstMatch
        guard bar.exists else { return }
        var swipes = 0
        while element.frame.maxY > bar.frame.minY && swipes < 3 {
            app.swipeUp(velocity: .slow)
            swipes += 1
        }
        XCTAssertTrue(
            element.exists && element.frame.maxY <= bar.frame.minY,
            "Never scrolled \(element) clear of the tab bar."
        )
    }

    /// The History rows currently realized, addressed by the identifier
    /// prefix: the seed draws completion ids fresh each run.
    @MainActor
    private func historyRows(in app: XCUIApplication) -> XCUIElementQuery {
        app.descendants(matching: .any)
            .matching(NSPredicate(
                format: "identifier BEGINSWITH %@",
                AccessibilityID.HabitDetail.historyRowPrefix
            ))
    }
}
