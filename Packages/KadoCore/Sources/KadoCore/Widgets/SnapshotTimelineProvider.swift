import Foundation
@preconcurrency import WidgetKit

/// Static-configuration provider for widgets that just read the
/// current `WidgetSnapshotSeries`. Each reload re-reads the App Group
/// JSON file the main app writes on mutations, so the widget
/// reflects the latest state without ever opening SwiftData.
///
/// The timeline carries one entry per pre-computed day, dated at that
/// day's rollover — under the user's "Day starts at" hour, read from
/// the same App Group suite the app writes — so the widget shows the
/// fresh day the moment it begins, app asleep or not. The hourly
/// reload is the safety net, not the rollover.
public struct SnapshotTimelineProvider: TimelineProvider, Sendable {
    public init() {}

    public func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: .now, snapshot: .empty)
    }

    public func getSnapshot(in context: Context, completion: @escaping @Sendable (SnapshotEntry) -> Void) {
        let snapshot = WidgetSnapshotStore.read()
        completion(SnapshotEntry(date: .now, snapshot: snapshot))
    }

    public func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<SnapshotEntry>) -> Void) {
        let plan = WidgetTimelinePlan.make(series: WidgetSnapshotStore.readSeries())
        let entries = plan.slots.map { SnapshotEntry(date: $0.date, snapshot: $0.snapshot) }
        completion(Timeline(entries: entries, policy: .after(plan.reloadAfter)))
    }
}

/// Timeline entry wrapping a `WidgetSnapshot` plus the effective
/// time. Used by every widget that doesn't need intent
/// configuration (today-grid, weekly, inline).
public struct SnapshotEntry: TimelineEntry, Sendable {
    public let date: Date
    public let snapshot: WidgetSnapshot

    public init(date: Date, snapshot: WidgetSnapshot) {
        self.date = date
        self.snapshot = snapshot
    }
}
