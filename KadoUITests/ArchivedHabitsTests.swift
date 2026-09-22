import XCTest

/// The archive's round trip, end to end (issue #99): a habit archived
/// from Today shows up under Settings › Archived habits, and from
/// there it can be put back or deleted for good.
///
/// Every action here is a gesture wired for the first time — a swipe
/// on a `List` row, a long-press menu, a toolbar button behind a
/// conditional — and issue #87 is the reason none of them is taken on
/// trust: a modifier that compiles and reads as wired can still never
/// fire. The seeded habits are keyed by ids the seed draws fresh each
/// run, so each test reads the id off a row and follows that one habit
/// from screen to screen.
///
/// Only the first test archives through Today's long-press menu.
/// XCUITest waits a full minute for the app to idle after that
/// long-press and another after the tap in the menu — the context menu
/// never reports its animations complete — so the path is driven once
/// and the other tests launch with a habit already archived
/// (`archiveFirstHabit`).
final class ArchivedHabitsTests: KadoUITestCase {

    @MainActor
    func testArchivedHabitIsListedInSettingsAndUnarchivesFromItsMenu() {
        let app = launchApp(devMode: true)
        let habitID = archiveFirstTodayRow(in: app)

        let row = openArchivedList(in: app, expecting: habitID)
        capture(app, "archived-list")

        row.press(forDuration: 1)
        let unarchive = app.buttons[AccessibilityID.Archived.unarchiveButton].firstMatch
        XCTAssertTrue(
            unarchive.waitForExistence(timeout: 5),
            "Long-pressing an Archived row should open a menu with Unarchive in it."
        )
        capture(app, "archived-row-menu")
        unarchive.tap()

        XCTAssertTrue(
            row.waitForNonExistence(timeout: 5),
            "Unarchive should take the row off the Archived list."
        )
        capture(app, "archived-list-after-unarchive")

        tapTab(.today, in: app)
        XCTAssertTrue(
            todayRow(habitID, in: app).waitForExistence(timeout: 10),
            "An unarchived habit should be back on Today."
        )
    }

    @MainActor
    func testSwipingAnArchivedRowUnarchivesIt() {
        let app = launchApp(devMode: true, archiveFirstHabit: true)

        let (row, habitID) = openArchivedList(in: app)
        row.swipeRight()
        let unarchive = app.buttons[AccessibilityID.Archived.swipeUnarchiveButton].firstMatch
        XCTAssertTrue(
            unarchive.waitForExistence(timeout: 5),
            "Swiping an Archived row to the right should reveal Unarchive — this is the issue #87 shape."
        )
        capture(app, "archived-row-swipe")
        unarchive.tap()

        XCTAssertTrue(row.waitForNonExistence(timeout: 5), "Unarchive should take the row off the list.")
        tapTab(.today, in: app)
        XCTAssertTrue(todayRow(habitID, in: app).waitForExistence(timeout: 10))
    }

    @MainActor
    func testDeletingAnArchivedHabitRemovesItForGood() {
        let app = launchApp(devMode: true, archiveFirstHabit: true)
        tapTab(.today, in: app)
        waitForTodayRows(in: app)
        let habitsBefore = todayHabitIDs(in: app)

        let (row, habitID) = openArchivedList(in: app)
        XCTAssertFalse(habitsBefore.contains(habitID), "An archived habit should not be on Today.")
        row.press(forDuration: 1)
        let delete = app.buttons[AccessibilityID.Archived.deleteButton].firstMatch
        XCTAssertTrue(delete.waitForExistence(timeout: 5), "The row's menu should offer Delete.")
        delete.tap()

        let confirm = app.buttons[AccessibilityID.Archived.deleteConfirmButton].firstMatch
        XCTAssertTrue(
            confirm.waitForExistence(timeout: 5),
            "Delete should ask first — it is the one action here that can't be undone."
        )
        capture(app, "archived-delete-dialog")
        confirm.tap()

        XCTAssertTrue(row.waitForNonExistence(timeout: 5), "Delete should take the row off the list.")
        XCTAssertTrue(
            archivedRows(in: app).firstMatch.waitForNonExistence(timeout: 5),
            "It was the only archived habit, so the list should be empty now."
        )
        capture(app, "archived-list-empty")

        tapTab(.today, in: app)
        waitForTodayRows(in: app)
        XCTAssertFalse(todayRow(habitID, in: app).exists, "A deleted habit must not come back to Today.")
        XCTAssertEqual(todayHabitIDs(in: app), habitsBefore, "Delete should leave the other habits alone.")
    }

    @MainActor
    func testArchivedDetailUnarchivesFromItsToolbar() {
        let app = launchApp(devMode: true, archiveFirstHabit: true)

        let (row, habitID) = openArchivedList(in: app)
        row.tap()
        let scoreCard = app.buttons[AccessibilityID.HabitDetail.scoreCard]
        XCTAssertTrue(scoreCard.waitForExistence(timeout: 10), "Tapping an Archived row should push its detail.")

        let unarchive = app.buttons[AccessibilityID.HabitDetail.unarchiveButton].firstMatch
        XCTAssertTrue(
            unarchive.waitForExistence(timeout: 5),
            "An archived habit's detail should offer Unarchive in its toolbar."
        )
        capture(app, "archived-detail")
        unarchive.tap()

        XCTAssertTrue(scoreCard.waitForNonExistence(timeout: 10), "Unarchive should pop back to the list.")
        XCTAssertTrue(row.waitForNonExistence(timeout: 5), "…and the habit should have left it.")

        tapTab(.today, in: app)
        XCTAssertTrue(todayRow(habitID, in: app).waitForExistence(timeout: 10))
    }

    // MARK: - Steps

    /// Archives Today's first row through its long-press menu and the
    /// confirmation, and returns the habit's id.
    @MainActor
    private func archiveFirstTodayRow(in app: XCUIApplication) -> UUID {
        tapTab(.today, in: app)
        waitForTodayRows(in: app)
        // The id is read off "any Today row" and the row is then
        // re-queried by that exact id: a prefix `firstMatch` would
        // resolve to the *next* row once this one is gone, and the
        // wait for its disappearance below would never end.
        let habitID = habitID(of: todayRows(in: app).firstMatch, prefix: "today.row.")
        let row = todayRow(habitID, in: app)
        scrollClearOfTabBar(row, in: app)

        row.press(forDuration: 1)
        let archive = app.buttons[AccessibilityID.Today.archiveButton].firstMatch
        XCTAssertTrue(archive.waitForExistence(timeout: 5), "The row's menu should offer Archive.")
        archive.tap()

        let confirm = app.buttons[AccessibilityID.Today.archiveConfirmButton].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "Archive should confirm first.")
        capture(app, "today-archive-dialog")
        confirm.tap()

        XCTAssertTrue(row.waitForNonExistence(timeout: 5), "Archive should take the row off Today.")
        return habitID
    }

    /// Settings › Archived habits, and the row for `habitID` in it.
    @MainActor
    private func openArchivedList(in app: XCUIApplication, expecting habitID: UUID) -> XCUIElement {
        pushArchivedList(in: app)
        let row = app.descendants(matching: .any)[AccessibilityID.Archived.row(habitID)].firstMatch
        XCTAssertTrue(
            row.waitForExistence(timeout: 10),
            "The habit archived from Today should be listed under Settings › Archived habits."
        )
        return row
    }

    /// Settings › Archived habits, and its one row — the habit
    /// `archiveFirstHabit` put there — with that habit's id.
    @MainActor
    private func openArchivedList(in app: XCUIApplication) -> (row: XCUIElement, habitID: UUID) {
        pushArchivedList(in: app)
        let any = archivedRows(in: app).firstMatch
        XCTAssertTrue(
            any.waitForExistence(timeout: 10),
            "The habit archived at launch should be listed under Settings › Archived habits."
        )
        let habitID = habitID(of: any, prefix: AccessibilityID.Archived.rowPrefix)
        let row = app.descendants(matching: .any)[AccessibilityID.Archived.row(habitID)].firstMatch
        return (row, habitID)
    }

    @MainActor
    private func pushArchivedList(in app: XCUIApplication) {
        tapTab(.settings, in: app)
        // Mid-list on an iPhone: below the fold until scrolled to.
        let entry = app.descendants(matching: .any)[AccessibilityID.Settings.archivedRow].firstMatch
        scrollTo(entry, in: app)
        entry.tap()
    }

    @MainActor
    private func archivedRows(in app: XCUIApplication) -> XCUIElementQuery {
        elements(withIdentifierPrefix: AccessibilityID.Archived.rowPrefix, in: app)
    }

    @MainActor
    private func todayRow(_ habitID: UUID, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[AccessibilityID.Today.row(habitID)].firstMatch
    }

    /// The distinct habits on Today. A set of ids rather than a count:
    /// the prefix query matches each row more than once, so the raw
    /// count is not a number of habits.
    @MainActor
    private func todayHabitIDs(in app: XCUIApplication) -> Set<UUID> {
        Set(todayRows(in: app).allElementsBoundByIndex.map { habitID(of: $0, prefix: "today.row.") })
    }

    @MainActor
    private func habitID(of element: XCUIElement, prefix: String) -> UUID {
        let id = UUID(uuidString: String(element.identifier.dropFirst(prefix.count)))
        XCTAssertNotNil(id, "\(element.identifier) should end in a UUID.")
        return id ?? UUID()
    }
}
