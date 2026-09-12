import Foundation
import SwiftData
import KadoCore

/// The app's "after a habit mutation" postamble: rebuild the App Group
/// snapshot the widget reads (which reloads the timelines itself, so
/// the change surfaces within a second or two) and reconcile the
/// pending reminders.
///
/// The widget extension can't safely open SwiftData (two
/// processes can't both attach CloudKit to the same store), so
/// the snapshot-through-file-system dance is the bridge between
/// app writes and widget reads.
@MainActor
enum WidgetReloader {
    static func reloadAll(using context: ModelContext) {
        WidgetSnapshotBuilder.rebuildAndWrite(using: context)
        // Reminders share the same "after a habit mutation" cadence
        // as widgets. Piggyback here so callers don't have to
        // remember two sync calls.
        RemindersSync.rescheduleAll(using: context)
    }
}
