import SwiftUI
import WidgetKit

/// The one-line Lock Screen summary above the clock.
/// `LockInlineWidget` in the extension wraps it; the app draws it
/// directly for the listing's widget screenshot.
public struct LockInlineView: View {
    let entry: SnapshotEntry

    public init(entry: SnapshotEntry) {
        self.entry = entry
    }

    public var body: some View {
        if entry.snapshot.totalDueToday == 0 {
            Label {
                Text("No habits due today")
            } icon: {
                Image(systemName: "checkmark.circle")
            }
        } else {
            Label {
                Text(
                    String(
                        localized: "\(entry.snapshot.completedToday) of \(entry.snapshot.totalDueToday) done today",
                        comment: "Inline lock widget summary. Arg 1 completed, arg 2 total."
                    )
                )
            } icon: {
                Image(systemName: summaryIcon)
            }
        }
    }

    private var summaryIcon: String {
        if entry.snapshot.totalDueToday == 0 { return "checkmark.circle" }
        if entry.snapshot.completedToday == entry.snapshot.totalDueToday { return "checkmark.circle.fill" }
        return "circle.dotted"
    }
}
