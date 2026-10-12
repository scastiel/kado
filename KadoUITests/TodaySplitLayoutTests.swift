import XCTest

/// Today in a regular-width window — the iPad, and the iPhone Duo's
/// inner display — shows the list and the selected habit's detail side
/// by side (issue #140).
///
/// Skipped where Today is compact, which includes `make e2e`'s iPhone:
/// run it against an iPad, or a Duo unfolded by hand in Device Hub.
/// It exists for the two things the split could break without a unit
/// test noticing: that picking a row drives the detail column at all,
/// and that a row's own `+` still logs inside a list that now selects
/// rows on tap.
final class TodaySplitLayoutTests: KadoUITestCase {

    @MainActor
    func testPickingARowShowsItsDetailBesideTheList() throws {
        let app = launchApp(seedProduction: true, seedForScreenshots: true)
        waitForTodayRows(in: app)
        let scoreCard = app.buttons[AccessibilityID.HabitDetail.scoreCard]
        try XCTSkipUnless(
            scoreCard.waitForExistence(timeout: 5),
            "Today is compact here, so its detail is pushed rather than shown beside the list."
        )

        // Which habit the detail shows, told by a control only a
        // counter's detail has: the first row is a yes/no habit, and
        // Drink water is the seed's counter. Not by name — the row's own
        // name is a static text too.
        let counterDetail = app.buttons[AccessibilityID.HabitDetail.quickLogIncrement]
        let water = row(named: "Drink water", in: app)
        XCTAssertFalse(
            counterDetail.exists,
            "The detail should open on the first row, not on Drink water."
        )
        // Toward the leading edge: the trailing side of this row is its
        // own − 5 + stepper.
        water.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5)).tap()
        XCTAssertTrue(
            counterDetail.waitForExistence(timeout: 10),
            "Picking a row should show that habit in the detail column."
        )
        XCTAssertTrue(water.isHittable, "The list should stay on screen beside the detail.")

        // The row collapses to one element, so its + is reached by
        // where it sits — the trailing end — rather than by name. The
        // detail column's own increment is a different control.
        let before = water.value as? String
        water.coordinate(withNormalizedOffset: CGVector(dx: 0.96, dy: 0.5)).tap()
        XCTAssertTrue(
            waited(for: water, toChangeValueFrom: before),
            "The row's + should still log in a selectable list; the row still reads \(before ?? "nil")."
        )
    }

    @MainActor
    private func row(named name: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(
                format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "today.row.", name
            ))
            .firstMatch
    }

    @MainActor
    private func waited(for element: XCUIElement, toChangeValueFrom old: String?) -> Bool {
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline {
            if element.value as? String != old { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return false
    }
}
