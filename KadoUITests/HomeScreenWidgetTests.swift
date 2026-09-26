import XCTest

/// Places each home widget on the Home Screen, picks habits for it in
/// the widget-edit sheet, and checks that the tile draws that pick.
///
/// The one thing no unit test can see: a widget that ignores its stored
/// configuration. A tile that dropped its pick and a tile that was never
/// configured are pixel-identical — both show every habit — so
/// `WidgetHabitSelection`'s tests can be green while the extension
/// decodes nothing (#76, which cost the feature its first attempt).
/// Here the verdict is read off the placed tile itself: the picked
/// habits in pick order, and a habit that wasn't picked, absent.
///
/// **Not part of `make e2e`.** It drives SpringBoard, not Kadō, so it
/// leans on Apple's accessibility labels ("Edit", "Add Widget", "Edit
/// Widget") and takes over a minute per tile. `make widgets-e2e` runs it,
/// alone and serially — see the Makefile for why it re-signs the build.
///
/// Every step goes through the English labels SpringBoard uses on this
/// simulator; a French simulator will fail at the first `buttons["Edit"]`.
final class HomeScreenWidgetTests: KadoUITestCase {

    private let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    /// Which page of Kadō's widget gallery each family sits on — the
    /// order `KadoWidgetsBundle` declares them in.
    private enum Family: Int, CustomStringConvertible {
        case small = 0, medium, large

        var description: String {
            switch self {
            case .small: "small"
            case .medium: "medium"
            case .large: "large"
            }
        }

        /// Whether a placed tile of this frame is this family. Sizes on
        /// an iPhone 17 Pro: small ≈ 170pt square, medium ≈ 364 × 170,
        /// large ≈ 364 × 382. Compared by shape rather than exact size
        /// so another iPhone model still matches.
        func matches(_ frame: CGRect) -> Bool {
            let wide = frame.width > frame.height * 1.5
            switch self {
            case .small: return !wide && frame.width < 250
            case .medium: return wide
            case .large: return !wide && frame.width >= 250
            }
        }
    }

    /// Two seeded habits, picked in the opposite order to the app's own
    /// — `DevModeSeed` lists "Morning meditation" first — so a tile that
    /// fell back to "show everything" fails on order as well as on the
    /// unpicked habit. English, because `launchApp` pins the language.
    private let picks = ["Read", "Morning meditation"]
    /// Seeded, due every day, and not picked: on every family's
    /// unconfigured tile, and must not be on a configured one. Daily
    /// matters — "Gym" is Monday/Wednesday/Friday, so on a weekend an
    /// unconfigured tile doesn't show it and the "before" check fails.
    private let unpicked = "Drink water"

    @MainActor
    func testSmallWidgetDrawsThePick() throws {
        try placePickAndCheck(.small)
    }

    @MainActor
    func testMediumWidgetDrawsThePick() throws {
        try placePickAndCheck(.medium)
    }

    @MainActor
    func testLargeWidgetDrawsThePick() throws {
        try placePickAndCheck(.large)
    }

    // MARK: - The scenario

    @MainActor
    private func placePickAndCheck(_ family: Family) throws {
        // Seeds the redirected store and — through `UITestSupport` —
        // writes the App Group snapshot the widget and its habit picker
        // both read. Waiting on a Today row is waiting for that write.
        let app = launchApp(seedProduction: true)
        waitForTodayRows(in: app)
        goHome()
        // A placed widget outlives the run, and a failed run leaves its
        // tile behind. Cleared first rather than in `tearDown`, so the
        // cleanup happens whether or not the last run got that far.
        removeKadoWidgets()

        placeWidget(family)
        let tile = try placedTile(family)
        dump("placed \(family)")

        // Unconfigured, the tile shows every habit it has room for. The
        // unpicked habit being there first is what makes its absence
        // afterwards mean something.
        XCTAssertTrue(
            waitFor(tile, toShow: unpicked),
            "A fresh \(family) widget should show every habit, “\(unpicked)” among them."
        )

        editWidget(tile)
        pick(picks)
        commitEdit()

        let configured = try placedTile(family)
        XCTAssertTrue(
            waitFor(configured, toHide: unpicked, timeout: 30),
            "The \(family) widget still shows “\(unpicked)” — it ignored its pick."
        )
        let names = habitNames(on: configured)
        XCTAssertEqual(
            names.filter(picks.contains), picks,
            "The \(family) widget should draw the picked habits in pick order; it drew \(names)."
        )
        capture(springboard, "configured \(family)")
        removeKadoWidgets()
    }

    // MARK: - SpringBoard steps

    @MainActor
    private func goHome() {
        XCUIDevice.shared.press(.home)
        sleep(1)
        // Twice: the first press can land on a page other than the
        // first, and widgets are placed on the page that is showing.
        XCUIDevice.shared.press(.home)
        sleep(1)
    }

    /// Enters jiggle mode, adds Kadō's `family` widget from the gallery,
    /// and leaves jiggle mode.
    @MainActor
    private func placeWidget(_ family: Family) {
        springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
            .press(forDuration: 2.0)
        tap(springboard.buttons["Edit"], "the Home Screen’s Edit button")
        tap(springboard.buttons["Add Widget"], "Add Widget")

        let search = springboard.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10), "The widget gallery has no search field.")
        search.tap()
        search.typeText("Kad")
        tap(springboard.cells["Kadō"].firstMatch, "Kadō in the gallery’s results")
        sleep(1)

        for _ in 0..<family.rawValue {
            springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.55))
                .press(
                    forDuration: 0.1,
                    thenDragTo: springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.55))
                )
            sleep(1)
        }
        // The label carries a leading glyph, so no exact match.
        tap(
            springboard.buttons.matching(NSPredicate(format: "label CONTAINS 'Add Widget'")).firstMatch,
            "the gallery’s Add Widget button for the \(family) widget"
        )
        sleep(2)
        tap(springboard.buttons["Done"], "Done, to leave jiggle mode")
        sleep(1)
    }

    /// Every Kadō widget on the Home Screen.
    private var kadoTiles: XCUIElementQuery {
        springboard.icons.matching(NSPredicate(format: "label == 'Kadō' AND value == 'Widget'"))
    }

    /// The placed tile of `family`, scrolled onto the visible page.
    ///
    /// Chosen by frame: SpringBoard's icon order is not placement order.
    @MainActor
    private func placedTile(_ family: Family) throws -> XCUIElement {
        XCTAssertTrue(kadoTiles.firstMatch.waitForExistence(timeout: 10), "No Kadō widget on the Home Screen.")
        let tile = try XCTUnwrap(
            kadoTiles.allElementsBoundByIndex.first { family.matches($0.frame) },
            "No \(family) Kadō widget among \(kadoTiles.allElementsBoundByIndex.map(\.frame))."
        )
        var swipes = 0
        while !tile.isHittable && swipes < 3 {
            springboard.swipeLeft()
            sleep(1)
            swipes += 1
        }
        XCTAssertTrue(tile.isHittable, "The \(family) widget never came onto the screen.")
        return tile
    }

    @MainActor
    private func editWidget(_ tile: XCUIElement) {
        tile.press(forDuration: 1.5)
        tap(springboard.buttons["Edit Widget"], "Edit Widget in the tile’s menu")
        sleep(2)
        dump("edit sheet")
    }

    /// Checks each of `names` in the sheet's habit checklist, in order.
    ///
    /// The checklist is a full-screen page titled "Habits", one text row
    /// per habit and a checkmark beside each checked one — not the list
    /// editor (`editor.list.add-item`) an intent with a `size:` gets; see
    /// `SelectHabitsIntent` for why it's this one.
    @MainActor
    private func pick(_ names: [String]) {
        // The parameter row is a "Habits" text beside a "Choose" button;
        // the sheet takes a few seconds to load it, spinner first.
        tap(springboard.buttons["Choose"].firstMatch, "the Habits parameter’s Choose button", timeout: 20)
        let checklist = springboard.navigationBars["Habits"]
        XCTAssertTrue(checklist.waitForExistence(timeout: 10), "The habit checklist never opened.")
        dump("habit checklist")
        for name in names {
            tap(springboard.staticTexts[name].firstMatch, "“\(name)” in the habit checklist")
            sleep(1)
        }
        dump("after picks")
        tap(checklist.buttons["Done"], "the checklist’s Done button")
        sleep(1)
    }

    /// Closes the edit sheet, which is what saves the pick. Tapping
    /// above the sheet does it; the status bar does not.
    @MainActor
    private func commitEdit() {
        springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)).tap()
        sleep(3)
        dump("after commit")
    }

    /// Removes every Kadō widget, so runs don't pile tiles up and a
    /// test never finds the last run's configured tile.
    @MainActor
    private func removeKadoWidgets() {
        for _ in 0..<6 {
            guard let tile = kadoTiles.allElementsBoundByIndex.first(where: \.exists) else { return }
            if !tile.isHittable {
                springboard.swipeLeft()
                sleep(1)
                if !tile.isHittable { goHome(); return }
            }
            tile.press(forDuration: 1.5)
            let remove = springboard.buttons["Remove Widget"]
            guard remove.waitForExistence(timeout: 5) else {
                dump("no Remove Widget")
                return
            }
            remove.tap()
            // The confirmation alert's own button.
            let confirm = springboard.alerts.buttons["Remove"]
            if confirm.waitForExistence(timeout: 5) { confirm.tap() }
            sleep(2)
        }
    }

    // MARK: - Reading the tile

    /// The habit names drawn on `tile`, top to bottom.
    ///
    /// `HabitWidgetCell` labels each row with the habit's name and the
    /// large widget draws the name as text, so the tile's descendants
    /// carry them; anything that isn't a seeded name ("Today", "2 / 3
    /// done", weekday letters) is filtered out by the caller.
    ///
    /// One `snapshot()` rather than a query per descendant: a tile is
    /// forty-odd elements, and the timeline reloading between two of
    /// those queries fails the walk with "no matches found for element
    /// at index 42".
    @MainActor
    private func habitNames(on tile: XCUIElement) -> [String] {
        guard let root = try? tile.snapshot() else { return [] }
        var labelled: [(label: String, frame: CGRect)] = []
        func walk(_ node: any XCUIElementSnapshot) {
            if !node.label.isEmpty { labelled.append((node.label, node.frame)) }
            node.children.forEach(walk)
        }
        root.children.forEach(walk)
        // A row carries its name three times over — the combined button,
        // its text, the inner text — so only the first of each counts.
        var seen = Set<String>()
        return labelled
            .sorted { ($0.frame.minY, $0.frame.minX) < ($1.frame.minY, $1.frame.minX) }
            .map(\.label)
            .filter { seen.insert($0).inserted }
    }

    @MainActor
    private func waitFor(_ tile: XCUIElement, toShow name: String, timeout: TimeInterval = 15) -> Bool {
        let deadline = Date.now.addingTimeInterval(timeout)
        repeat {
            if habitNames(on: tile).contains(name) { return true }
            sleep(1)
        } while Date.now < deadline
        return false
    }

    @MainActor
    private func waitFor(_ tile: XCUIElement, toHide name: String, timeout: TimeInterval) -> Bool {
        let deadline = Date.now.addingTimeInterval(timeout)
        repeat {
            if !habitNames(on: tile).contains(name) { return true }
            sleep(1)
        } while Date.now < deadline
        return false
    }

    // MARK: - Plumbing

    @MainActor
    private func tap(
        _ element: XCUIElement,
        _ what: String,
        timeout: TimeInterval = 10,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard element.waitForExistence(timeout: timeout) else {
            dump("missing \(what)")
            XCTFail("SpringBoard never showed \(what).", file: file, line: line)
            return
        }
        element.tap()
    }

    /// Attaches SpringBoard's accessibility tree. A step that can't find
    /// its button is almost always a label that changed with the OS,
    /// and the tree is the only way to see what it became.
    @MainActor
    ///
    /// Printed as well: `xcodebuild test` on iOS 27 sometimes never exits
    /// after the suite, and a run killed there leaves no result bundle —
    /// only the log.
    private func dump(_ name: String) {
        let tree = springboard.debugDescription
        print("===== springboard: \(name) =====\n\(tree)\n===== end \(name) =====")
        let attachment = XCTAttachment(string: tree)
        attachment.name = "springboard: \(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
