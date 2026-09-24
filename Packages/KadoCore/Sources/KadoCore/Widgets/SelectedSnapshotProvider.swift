import AppIntents
import Foundation
import OSLog
@preconcurrency import WidgetKit

/// `AppIntentTimelineProvider` for the home widgets, which show several
/// user-picked habits. Emits the snapshot alongside the configured ids;
/// each view narrows it with its own family capacity.
///
/// Same timeline shape as `PickedSnapshotProvider`: one entry per
/// pre-computed day at its rollover, hourly reload as the safety net.
public struct SelectedSnapshotProvider: AppIntentTimelineProvider {
    public typealias Intent = SelectHabitsIntent
    public typealias Entry = SelectedSnapshotEntry

    public init() {}

    public func placeholder(in context: Context) -> SelectedSnapshotEntry {
        SelectedSnapshotEntry(date: .now, snapshot: .empty, habitIDs: [])
    }

    public func snapshot(for configuration: SelectHabitsIntent, in context: Context) async -> SelectedSnapshotEntry {
        SelectedSnapshotEntry(
            date: .now,
            snapshot: WidgetSnapshotStore.read(),
            habitIDs: configuration.habitIDs
        )
    }

    public func timeline(for configuration: SelectHabitsIntent, in context: Context) async -> Timeline<SelectedSnapshotEntry> {
        let plan = WidgetTimelinePlan.make(series: WidgetSnapshotStore.readSeries())
        let habitIDs = configuration.habitIDs
        // See `PickedSnapshotProvider.timeline` for why this is logged, and
        // how to read it. `paramNil` separates "the decode failed" from
        // "the user cleared the pick" — the two arrive as the same empty
        // list otherwise, and that ambiguity is what cost #76.
        Logger(subsystem: "dev.scastiel.kado", category: "widget")
            .debug("""
                timeline family=\(String(describing: context.family), privacy: .public) \
                picked=\(habitIDs.count, privacy: .public) \
                paramNil=\(configuration.habits == nil, privacy: .public) \
                snapshotHabits=\(plan.slots.first?.snapshot.habits.count ?? 0, privacy: .public)
                """)
        let entries = plan.slots.map {
            SelectedSnapshotEntry(date: $0.date, snapshot: $0.snapshot, habitIDs: habitIDs)
        }
        return Timeline(entries: entries, policy: .after(plan.reloadAfter))
    }
}
