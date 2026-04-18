import Foundation
@preconcurrency import WidgetKit

/// Static-configuration provider for widgets that just read the
/// current `WidgetSnapshot`. Each reload re-reads the App Group
/// JSON file the main app writes on mutations, so the widget
/// reflects the latest state without ever opening SwiftData.
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
        let now = Date.now
        let snapshot = WidgetSnapshotStore.read()
        let entry = SnapshotEntry(date: now, snapshot: snapshot)
        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 1, to: now)
            ?? now.addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
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
