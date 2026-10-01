import XCTest

/// Today's bottom slot holds one card at a time: the Appearance
/// announcement, or the tip nudge, never both.
///
/// `TodayCardTests` in the unit suite pins the rule; this pins that
/// Today follows it — that the two cards really are drawn from one
/// slot, that the announcement's button reaches Appearance, and that
/// coming back from there doesn't uncover the tip nudge.
final class TodayCardSlotTests: KadoUITestCase {

    private func openButton(in app: XCUIApplication) -> XCUIElement {
        app.buttons[AccessibilityID.Today.appearanceAnnouncementOpenButton].firstMatch
    }

    private func tipButton(in app: XCUIApplication) -> XCUIElement {
        app.buttons[AccessibilityID.Today.tipNudgeTipButton].firstMatch
    }

    /// Both due at once — an existing user on their first launch after
    /// the update. The announcement takes the slot.
    @MainActor
    func testAnnouncementTakesTheSlotAndOpensAppearance() {
        let app = launchApp(seedProduction: true, appearanceAnnouncement: true, tipNudgeReady: true)
        waitForTodayRows(in: app)

        let open = openButton(in: app)
        scrollTo(open, in: app)
        scrollClearOfTabBar(open, in: app)
        XCTAssertFalse(tipButton(in: app).exists, "The tip nudge must not share the slot.")
        capture(app, "today-appearance-announcement")

        open.tap()
        let firstTheme = app.descendants(matching: .any)
            .matching(identifier: AccessibilityID.Settings.habitThemeRow("kado"))
            .firstMatch
        XCTAssertTrue(
            firstTheme.waitForExistence(timeout: 10),
            "Open Appearance should open the Appearance screen."
        )
        capture(app, "today-appearance-sheet")

        app.buttons["Close"].firstMatch.tap()
        waitForTodayRows(in: app)
        // Gone for good once Appearance has been seen, and the tip
        // nudge waits until tomorrow rather than taking its place.
        XCTAssertFalse(openButton(in: app).exists, "Opening Appearance should retire the card.")
        XCTAssertFalse(tipButton(in: app).exists, "The tip nudge must wait a day.")
    }

    @MainActor
    func testNotNowPutsTheAnnouncementAwayWithoutUncoveringTheTip() {
        let app = launchApp(seedProduction: true, appearanceAnnouncement: true, tipNudgeReady: true)
        waitForTodayRows(in: app)

        let hide = app.buttons[AccessibilityID.Today.appearanceAnnouncementHideButton].firstMatch
        scrollTo(hide, in: app)
        scrollClearOfTabBar(hide, in: app)
        hide.tap()

        XCTAssertTrue(
            hide.waitForNonExistence(timeout: 5), "Not now should take the card away."
        )
        XCTAssertFalse(tipButton(in: app).exists, "The tip nudge must wait a day.")
    }

    /// The announcement long since put away: the slot is the tip
    /// nudge's again.
    @MainActor
    func testTipNudgeHasTheSlotOnceTheAnnouncementIsLongGone() {
        let app = launchApp(seedProduction: true, tipNudgeReady: true)
        waitForTodayRows(in: app)

        let tip = tipButton(in: app)
        scrollTo(tip, in: app)
        XCTAssertFalse(openButton(in: app).exists)
    }
}
