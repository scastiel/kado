import Foundation

/// Identifiers the UI tests look for.
///
/// Kept in one place, and applied in the same commit that adds the
/// view. Retrofitting identifiers across a grown app is the thing that
/// makes UI suites get abandoned.
///
/// **Put these on leaves, never on containers.** SwiftUI's
/// `.accessibilityIdentifier` applies to every descendant of the view
/// it modifies, and an outer one silently replaces the identifiers set
/// inside it — so a screen-level identifier on a `NavigationStack`
/// erases the identifiers of every button beneath it. That is why there
/// is no `screen` entry here: to assert a screen is showing, look for
/// something only that screen has.
///
/// **Kadō ships French**, which makes these load-bearing rather than
/// merely convenient. A suite that matched on
/// `app.staticTexts["Dev mode"]` would pass on an English simulator and
/// fail on a French one. Identifiers are locale-independent; labels are
/// not.
enum AccessibilityID {

    /// The tab bar's items, addressed by **position** rather than by
    /// identifier.
    ///
    /// SwiftUI's `Tab` offers no seam for an accessibility identifier.
    /// One applied to a tab's *content* would stamp every element in the
    /// screen beneath it — the trap at the top of this file. One applied
    /// to its *label* compiles and looks right but never reaches the tab
    /// bar button: dumped live, all three buttons come through carrying
    /// their labels and an empty identifier. (It half-works by accident
    /// — the selected tab's label matches something in the content —
    /// which is worse than not working, because a suite built on it
    /// passes until the initial tab changes.)
    ///
    /// Position is the one property of a tab bar item that is neither
    /// localized nor user-editable, so that is what the suite addresses.
    /// Keep in step with `ContentView`.
    enum Tab: Int {
        case today = 0
        case overview = 1
        case settings = 2
    }

    enum Today {
        /// One row, keyed by the habit's `UUID` so a test can address a
        /// row without depending on its name — which is both localized
        /// and user-editable.
        ///
        /// `HabitRowView` collapses its subtree with
        /// `.accessibilityElement(children: .combine)`, so the row is
        /// already a single element and this identifier lands on a leaf.
        static func row(_ habitID: UUID) -> String { "today.row.\(habitID.uuidString)" }
    }

    enum Settings {
        static let devModeToggle = "settings.devMode.toggle"
        /// The destructive button in the first-activation confirmation
        /// alert. A test that launches with the flag already confirmed
        /// never sees it.
        static let devModeConfirmButton = "settings.devMode.confirm"
    }
}
