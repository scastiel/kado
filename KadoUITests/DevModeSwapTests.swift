import XCTest

/// The regression suite for issue #63: toggling Dev mode swaps the
/// `ModelContainer` underneath a live SwiftUI tree, and anything that
/// retained a `HabitRecord` from the old store traps inside SwiftData
/// the moment the update pass re-reads it.
///
/// A crash during a SwiftUI update pass is structurally invisible to a
/// unit test — the trap happens inside
/// `UICollectionViewListCoordinatorBase.updateListContents`, with no
/// seam to assert on. `XCTAssertEqual(app.state, .runningForeground)`
/// is the real assertion in both tests below: the bug is a crash, so
/// "still alive afterwards" is the whole check. What is rendered after
/// the swap is a bonus.
final class DevModeSwapTests: KadoUITestCase {

    /// The `ForEach` half, on #63's own repro: a fresh install, where
    /// the real store is empty and turning dev mode off leaves the list
    /// diffing six rows away to nothing. That removal is what re-reads
    /// `Identifiable.id` on records the swap has already invalidated —
    /// `ForEach.IDGenerator.makeID` is the frame directly above
    /// `HabitRecord.id.getter` in the original crash.
    ///
    /// Deliberately *not* seeded: with rows on both sides the list takes
    /// a different path through the update and survives, so a seeded
    /// version of this test passes on the unfixed code and proves
    /// nothing. `testTogglingDevModeOffWithBothStoresPopulated` covers
    /// that shape separately.
    @MainActor
    func testTogglingDevModeOffWithHabitsOnScreenDoesNotCrash() {
        let app = launchApp(devMode: true, seedProduction: false)

        tapTab(.today, in: app)
        waitForTodayRows(in: app)

        toggleDevModeOff(in: app)

        tapTab(.today, in: app)
        capture(app, "today-after-swap")
        XCTAssertEqual(app.state, .runningForeground)
    }

    /// The same swap with the real store populated — what a returning
    /// user actually has. Six rows are replaced by six different ones
    /// rather than removed, which is a different path through the list
    /// update and worth holding separately.
    @MainActor
    func testTogglingDevModeOffWithBothStoresPopulated() {
        let app = launchApp(devMode: true, seedProduction: true)

        tapTab(.today, in: app)
        waitForTodayRows(in: app)

        toggleDevModeOff(in: app)

        tapTab(.today, in: app)
        waitForTodayRows(in: app)
        capture(app, "today-after-swap-populated")
        XCTAssertEqual(app.state, .runningForeground)
    }

    /// The half that wasn't in #63: a `NavigationPath` outlives the
    /// swap still holding the record that was pushed onto it. Reachable
    /// because tabs stay alive — Today, into a habit, over to Settings,
    /// toggle, back to Today, and the detail screen is still on the
    /// stack with a dead object in it.
    @MainActor
    func testTogglingDevModeWithADetailScreenPushedDoesNotCrash() {
        let app = launchApp(devMode: true, seedProduction: true)

        tapTab(.today, in: app)
        waitForTodayRows(in: app)
        todayRows(in: app).firstMatch.tap()

        toggleDevModeOff(in: app)

        tapTab(.today, in: app)
        capture(app, "detail-after-swap")
        XCTAssertEqual(app.state, .runningForeground)
    }

    /// Flips the toggle and waits for it to actually read as off.
    ///
    /// Launching with `hasConfirmedDevMode: true` means no confirmation
    /// alert stands in the way; the wait afterwards is for the swap
    /// itself, which rebuilds a container and can take a moment.
    @MainActor
    private func toggleDevModeOff(in app: XCUIApplication) {
        tapTab(.settings, in: app)

        // Developer is the last section in Settings, so it starts below
        // the fold and is not in the hierarchy at all until scrolled to.
        let toggle = app.switches[AccessibilityID.Settings.devModeToggle]
        scrollTo(toggle, in: app)
        expect(toggle, toRead: "1", "Dev mode should have started on.")

        // The identified element spans the whole row — label included —
        // so its centre is over the text, not over the control. The
        // inner switch is the part that answers a tap.
        let control = toggle.switches.firstMatch
        (control.exists ? control : toggle).tap()

        // The swap happens here, and so does the crash when it happens.
        // Checking the app is still alive *before* blaming the toggle
        // matters: a dead app can't move a switch either, and "the
        // toggle never turned off" would send the next reader looking in
        // entirely the wrong place.
        if !waited(for: toggle, toRead: "0") {
            XCTAssertEqual(
                app.state, .runningForeground,
                "The app crashed during the dev-mode container swap — this is issue #63."
            )
            XCTFail("The Dev mode toggle never turned off.")
        }
    }

    /// Asserts a switch reads a given value, waiting for it.
    @MainActor
    private func expect(
        _ toggle: XCUIElement,
        toRead value: String,
        _ message: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(waited(for: toggle, toRead: value), message, file: file, line: line)
    }

    /// Whether a switch came to read a given value within the timeout.
    ///
    /// `value` comes back as a string for a switch, but reading it once
    /// straight after a tap races the animation — hence a predicate that
    /// re-reads rather than a single comparison.
    @MainActor
    private func waited(
        for toggle: XCUIElement, toRead value: String, timeout: TimeInterval = 30
    ) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", value),
            object: toggle
        )
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
