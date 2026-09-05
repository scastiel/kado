import XCTest

/// Shared setup for the UI suites.
///
/// Every test declares the state it starts from through `launchApp`,
/// so none inherits what a previous one left behind. The app never
/// reads the developer's real store: `-uiTestRun` redirects both the
/// production and dev stores to throwaway files and drops CloudKit
/// (see `UITestSupport`).
class KadoUITestCase: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// - Parameters:
    ///   - devMode: start with the demo sandbox mounted instead of the
    ///     real store. Goes through `UITestSupport` rather than through
    ///     a `-kado.devMode` launch argument: the argument domain
    ///     outranks every stored value, which would pin the flag on and
    ///     leave the toggle unable to move — see `UITestSupport`.
    ///   - hasConfirmedDevMode: start past the first-activation
    ///     confirmation alert. Pass `false` only when the alert itself
    ///     is what's under test — otherwise `DevModeSection`'s
    ///     `onChange` interception reverts the flip and the test taps a
    ///     toggle that doesn't move.
    ///   - seedProduction: fill the (redirected) production store with
    ///     the demo dataset, so toggling dev mode *off* lands on a
    ///     populated list rather than the empty state.
    ///   - resetState: wipe both throwaway stores first.
    ///   - language: which language to run the app in. Pinned rather
    ///     than inherited so a run is the same on a French simulator as
    ///     on an English one — and so the suite is worth something as
    ///     evidence either way, since the assertions go through
    ///     identifiers rather than labels.
    ///   - locale: the region to format dates and numbers with,
    ///     defaulting to `language`. Only the screenshot run needs a
    ///     region of its own — a French listing with US dates in it is
    ///     the kind of thing nobody notices until it has shipped.
    ///   - seedForScreenshots: fill the store with `ScreenshotSeed`'s
    ///     authored dataset rather than `DevModeSeed`'s every-state
    ///     one. Only the screenshot run wants this.
    ///   - suppressNameAutoFocus: leave the New Habit sheet's name
    ///     field unfocused, so the keyboard stays out of a screenshot.
    @MainActor
    func launchApp(
        devMode: Bool = false,
        hasConfirmedDevMode: Bool = true,
        seedProduction: Bool = false,
        resetState: Bool = true,
        language: String = "en",
        locale: String? = nil,
        seedForScreenshots: Bool = false,
        suppressNameAutoFocus: Bool = false
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestRun"]

        if resetState {
            app.launchArguments.append("-uiTestResetState")
        }
        if seedProduction {
            app.launchArguments.append("-uiTestSeedProduction")
        }
        if seedForScreenshots {
            app.launchArguments.append("-uiTestSeedForScreenshots")
        }
        if suppressNameAutoFocus {
            app.launchArguments.append("-uiTestSuppressNameAutoFocus")
        }
        app.launchArguments += [
            "-uiTestDevMode", devMode ? "1" : "0",
            "-uiTestDevModeConfirmed", hasConfirmedDevMode ? "1" : "0",
            "-AppleLanguages", "(\(language))",
            // The *region*, not just the language, when one is given:
            // it is what decides how dates and numbers are written
            // inside the screenshots.
            "-AppleLocale", locale ?? language,
        ]

        app.launch()
        return app
    }

    /// Switches tabs.
    ///
    /// By position on iPhone, because SwiftUI's `Tab` gives no seam for
    /// an accessibility identifier — see `AccessibilityID.Tab`. Going
    /// through the tab bar rather than `app.buttons[…]` also keeps this
    /// from matching a same-named button inside the tab's content.
    ///
    /// **iPad has no tab bar at all**, so position is not an address
    /// there: `app.tabBars` is empty and the tabs are drawn as plain
    /// buttons across the top. The fallback below reaches them by SF
    /// Symbol name, which is the only property of a tab that is neither
    /// localized nor device-dependent.
    @MainActor
    func tapTab(
        _ tab: AccessibilityID.Tab,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        // iPhone: a real tab bar at the bottom, addressed by position.
        // Short wait, because it is there the moment the app is.
        let bar = app.tabBars.firstMatch
        if bar.waitForExistence(timeout: 5) {
            bar.buttons.element(boundBy: tab.rawValue).tap()
            return
        }

        // iPad: no tab bar element exists at all. The tabs are plain
        // buttons across the top, each carrying its SF Symbol name as
        // its identifier — see `AccessibilityID.Tab.symbolName`.
        let button = app.buttons[tab.symbolName].firstMatch
        guard button.waitForExistence(timeout: 30) else {
            // The hierarchy, not just the miss. A tab that cannot be
            // found is nearly always a tab bar that lives somewhere
            // else on this device, and the only way to know where is to
            // look. This attachment is how the iPad layout above was
            // established in the first place.
            let dump = XCTAttachment(string: app.debugDescription)
            dump.name = "hierarchy-no-tab-bar"
            dump.lifetime = .keepAlways
            add(dump)
            XCTFail(
                "Found neither a tab bar nor a “\(tab.symbolName)” tab button.",
                file: file, line: line
            )
            return
        }
        button.tap()
    }

    /// Scrolls until `element` exists and can be tapped.
    ///
    /// `waitForExistence` alone is not enough for anything below the
    /// fold of a `Form`: an unrealized row is not in the hierarchy at
    /// all, so the wait watches for something that cannot appear until
    /// something scrolls. This is the whole reason the Dev mode toggle —
    /// the last section in Settings — looked missing for a full 30s
    /// timeout on the first run of this suite.
    ///
    /// Slow swipes on purpose: a thrown scroll coasts, and XCUITest
    /// answers `isHittable` only once the app looks idle, so every query
    /// during the glide burns its whole quiescence budget and then
    /// answers about a row that has already moved.
    @MainActor
    func scrollTo(
        _ element: XCUIElement,
        in app: XCUIApplication,
        swipes: Int = 10,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for _ in 0..<swipes {
            if element.exists && element.isHittable { return }
            app.swipeUp(velocity: .slow)
        }
        XCTAssertTrue(
            element.exists && element.isHittable,
            "Never scrolled \(element) into view.",
            file: file, line: line
        )
    }

    /// The Today rows currently on screen, addressed by the identifier
    /// prefix rather than by habit name.
    ///
    /// Names come from `DevModeSeed`, which translates them — so a test
    /// that looked for "Morning meditation" would pass in English and
    /// fail in French. The prefix says "a Today row, any of them",
    /// which is what these tests actually mean.
    @MainActor
    func todayRows(in app: XCUIApplication) -> XCUIElementQuery {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "today.row."))
    }

    /// Waits for the Today list to have rows in it.
    @MainActor
    func waitForTodayRows(
        in app: XCUIApplication,
        timeout: TimeInterval = 30,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            todayRows(in: app).firstMatch.waitForExistence(timeout: timeout),
            "The Today list never showed a row.",
            file: file,
            line: line
        )
    }

    /// Saves a screenshot into the result bundle, so a failing run can
    /// be looked at without re-running it.
    @MainActor
    func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
