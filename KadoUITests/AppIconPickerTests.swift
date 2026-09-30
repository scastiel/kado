import XCTest

/// The App icon picker (#114) changes the Home Screen icon.
///
/// `AppIconTests` pins the gating and the names; what it can't see is
/// the system taking the name — an `.appiconset` the asset compiler
/// dropped, or a name the bundle doesn't declare, only fails here — and
/// the Home Screen actually wearing it. Also where the picker and the
/// Home Screen get photographed for the PR, in whichever appearance the
/// simulator is in.
final class AppIconPickerTests: KadoUITestCase {

    private let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    private func iconRow(_ rawValue: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: AccessibilityID.Settings.appIconRow(rawValue))
            .firstMatch
    }

    @MainActor
    private func openAppearance(in app: XCUIApplication) {
        tapTab(.settings, in: app)
        let row = app.descendants(matching: .any)[AccessibilityID.Settings.appearanceRow].firstMatch
        scrollTo(row, in: app)
        row.tap()
    }

    /// The system confirms every switch with an alert of its own —
    /// hosted by SpringBoard on some runtimes, by the app on others.
    @MainActor
    private func dismissIconChangedAlert(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline {
            for alert in [app.alerts.firstMatch, springboard.alerts.firstMatch] where alert.exists {
                alert.buttons.firstMatch.tap()
                return
            }
            Thread.sleep(forTimeInterval: 0.25)
        }
        XCTFail("The system never confirmed the icon change.", file: file, line: line)
    }

    @MainActor
    private func pick(_ rawValue: String, in app: XCUIApplication) {
        let row = iconRow(rawValue, in: app)
        scrollTo(row, in: app)
        scrollClearOfTabBar(row, in: app)
        row.tap()
        dismissIconChangedAlert(in: app)
        XCTAssertTrue(row.isSelected, "\(rawValue) should read as the chosen icon.")
    }

    @MainActor
    func testPickingAnIconChangesTheHomeScreen() {
        let app = launchApp(supporter: true)
        openAppearance(in: app)
        let umi = iconRow("umi", in: app)
        scrollTo(umi, in: app)
        scrollClearOfTabBar(umi, in: app)
        capture(app, "app-icon-picker-supporter")

        pick("umi", in: app)
        capture(app, "app-icon-picker-umi")

        XCUIDevice.shared.press(.home)
        let icon = springboard.icons["Kadō"]
        XCTAssertTrue(icon.waitForExistence(timeout: 10), "Kadō should be on the Home Screen.")
        Thread.sleep(forTimeInterval: 1.0)
        let attachment = XCTAttachment(screenshot: springboard.screenshot())
        attachment.name = "app-icon-home-umi"
        attachment.lifetime = .keepAlways
        add(attachment)

        // Leave the simulator on the default, so the next run's launch
        // has nothing to reconcile and no alert to raise.
        app.activate()
        pick("kado", in: app)
    }

    /// A paid icon without the pack opens the pack instead of being
    /// picked — through the destination `AppearanceView` already holds
    /// for the habit colour themes.
    @MainActor
    func testTappingALockedIconOpensTheSupporterPack() {
        let app = launchApp()
        openAppearance(in: app)
        let fuji = iconRow("fuji", in: app)
        scrollTo(fuji, in: app)
        scrollClearOfTabBar(fuji, in: app)
        capture(app, "app-icon-picker-locked")

        fuji.tap()
        let restore = app.buttons[AccessibilityID.SupporterPack.restoreButton]
        XCTAssertTrue(
            restore.waitForExistence(timeout: 10),
            "A locked icon should open the Supporter pack."
        )
    }
}
