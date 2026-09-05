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

        /// The SF Symbol each tab carries, which is how the suite
        /// reaches it on iPad.
        ///
        /// iPad has no tab bar to count positions in: `app.tabBars` is
        /// empty there, and the tabs are drawn as plain buttons across
        /// the top. SwiftUI does put the symbol's name on those buttons
        /// as their identifier — verified by dumping the live hierarchy
        /// on an iPad Pro 13" — so it is the one address that works on
        /// a device where position doesn't. (Each button is nested
        /// inside a second one carrying the same identifier, so a query
        /// for it needs `firstMatch`.)
        ///
        /// Keep in step with `ContentView`, the same as `rawValue`.
        var symbolName: String {
            switch self {
            case .today: "list.bullet.clipboard"
            case .overview: "square.grid.2x2"
            case .settings: "gearshape"
            }
        }
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
        /// The toolbar's + button. Identified rather than matched on
        /// its label, which is localized, or on its SF Symbol name,
        /// which SwiftUI does not reliably surface for a `Label`.
        static let newHabitButton = "today.newHabit"
    }

    enum HabitDetail {
        /// The score card. A `Button`, so it is already a single
        /// accessibility element and this lands on a leaf. Waited on
        /// rather than a navigation title, which this screen
        /// deliberately leaves empty.
        static let scoreCard = "habitDetail.scoreCard"
        /// The monthly calendar's ‹ arrow. Its label is localized, and
        /// the screenshot run steps back a month so the calendar it
        /// photographs is a whole one — a capture taken on the 5th
        /// otherwise shows five filled days and twenty-five empty.
        static let previousMonthButton = "habitDetail.previousMonth"
    }

    enum Overview {
        /// One habit's label in the matrix's overlay column, keyed by
        /// the habit's `UUID` for the same reason `Today.row` is:
        /// names are localized and user-editable.
        static func habitLabel(_ habitID: UUID) -> String {
            "overview.label.\(habitID.uuidString)"
        }
    }

    enum NewHabit {
        /// The habit-name text field — the first row the sheet draws,
        /// so it is what says "the sheet is up".
        static let nameField = "newHabit.nameField"
        /// The sheet's Cancel button. Same reason as
        /// `Today.newHabitButton`: "Cancel" is "Annuler" on the French
        /// simulator, and the suite has to close the sheet on both.
        static let cancelButton = "newHabit.cancel"
    }

    enum Settings {
        static let devModeToggle = "settings.devMode.toggle"
        /// The destructive button in the first-activation confirmation
        /// alert. A test that launches with the flag already confirmed
        /// never sees it.
        static let devModeConfirmButton = "settings.devMode.confirm"
    }
}
