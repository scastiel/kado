import Foundation
import SwiftData
import WidgetKit
import KadoCore

/// Rebuilds the App Group JSON snapshot the widget reads, then
/// asks WidgetKit to reload all timelines so the changes surface
/// within a second or two.
///
/// The widget extension can't safely open SwiftData (two
/// processes can't both attach CloudKit to the same store), so
/// the snapshot-through-file-system dance is the bridge between
/// app writes and widget reads.
@MainActor
enum WidgetReloader {
    static func reloadAll(using context: ModelContext) {
        WidgetSnapshotBuilder.rebuildAndWrite(using: context)
        WidgetCenter.shared.reloadAllTimelines()
        // Reminders share the same "after a habit mutation" cadence
        // as widgets. Piggyback here so callers don't have to
        // remember two sync calls.
        RemindersSync.rescheduleAll(using: context)
    }
}
