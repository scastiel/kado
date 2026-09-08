import AppIntents
import Foundation
import OSLog
@preconcurrency import WidgetKit

/// `AppIntentTimelineProvider` for the home widgets, which show
/// several user-picked habits. Emits the snapshot alongside the
/// configured ids; each view narrows it with its own family capacity
/// through `WidgetHabitSelection`.
///
/// The static-configuration `SnapshotTimelineProvider` stays for the
/// inline lock widget, which shows a summary and has nothing to pick.
public struct SelectedSnapshotProvider: AppIntentTimelineProvider {
    public typealias Intent = SelectHabitsIntent
    public typealias Entry = SelectedSnapshotEntry

    public init() {}

    public func placeholder(in context: Context) -> SelectedSnapshotEntry {
        SelectedSnapshotEntry(date: .now, snapshot: .empty, habitIDs: [])
    }

    public func snapshot(
        for configuration: SelectHabitsIntent,
        in context: Context
    ) async -> SelectedSnapshotEntry {
        SelectedSnapshotEntry(
            date: .now,
            snapshot: WidgetSnapshotStore.read(),
            habitIDs: configuration.habitIDs
        )
    }

    public func timeline(
        for configuration: SelectHabitsIntent,
        in context: Context
    ) async -> Timeline<SelectedSnapshotEntry> {
        let now = Date.now
        let entry = SelectedSnapshotEntry(
            date: now,
            snapshot: WidgetSnapshotStore.read(),
            habitIDs: configuration.habitIDs
        )
        #if DEBUG
        // A widget that ignores its configuration and one that was
        // never configured render identically, and neither the unit
        // suite nor a screenshot can tell them apart. Counts only —
        // never a habit name — so the log stays as private as the app.
        //
        //   xcrun simctl spawn booted log stream \
        //     --predicate 'subsystem == "dev.scastiel.kado"'
        Logger(subsystem: "dev.scastiel.kado", category: "widget")
            .debug("""
                timeline family=\(String(describing: context.family), privacy: .public) \
                picked=\(configuration.habitIDs.count, privacy: .public) \
                snapshotHabits=\(entry.snapshot.habits.count, privacy: .public) \
                todayRows=\(entry.snapshot.today.count, privacy: .public) \
                matrixRows=\(entry.snapshot.matrix.count, privacy: .public)
                """)
        #endif
        // Same hourly cadence the other providers use: the app pushes
        // a reload on every mutation, so this is only the floor under
        // a day that rolls over untouched.
        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 1, to: now)
            ?? now.addingTimeInterval(3600)
        return Timeline(entries: [entry], policy: .after(nextRefresh))
    }
}

/// Entry for the home widgets. `habitIDs` is the user's pick, in pick
/// order; empty means they haven't chosen, which shows everything.
public struct SelectedSnapshotEntry: TimelineEntry, Sendable {
    public let date: Date
    public let snapshot: WidgetSnapshot
    public let habitIDs: [UUID]

    public init(date: Date, snapshot: WidgetSnapshot, habitIDs: [UUID]) {
        self.date = date
        self.snapshot = snapshot
        self.habitIDs = habitIDs
    }

    /// The today rows this widget should draw, given its family's
    /// capacity.
    public func todayRows(limit: Int) -> [WidgetTodayRow] {
        WidgetHabitSelection.todayRows(from: snapshot, selecting: habitIDs, limit: limit)
    }

    /// The weekly-matrix rows this widget should draw.
    public func matrixRows(limit: Int) -> [WidgetMatrixRow] {
        WidgetHabitSelection.matrixRows(from: snapshot, selecting: habitIDs, limit: limit)
    }

    /// The "N / M done" summary for the medium widget.
    public func progress(limit: Int) -> (completed: Int, total: Int) {
        WidgetHabitSelection.progress(from: snapshot, selecting: habitIDs, limit: limit)
    }
}
