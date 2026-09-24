import AppIntents
import Foundation
import OSLog
@preconcurrency import WidgetKit

/// `AppIntentTimelineProvider` for the lock widgets that pick a
/// single habit. Emits an entry with the snapshot + the configured
/// habit ID; the view plucks the matching row out of the snapshot.
///
/// Same timeline shape as `SnapshotTimelineProvider`: one entry per
/// pre-computed day at its rollover, hourly reload as the safety net.
public struct PickedSnapshotProvider: AppIntentTimelineProvider {
    public typealias Intent = PickHabitIntent
    public typealias Entry = PickedSnapshotEntry

    public init() {}

    public func placeholder(in context: Context) -> PickedSnapshotEntry {
        PickedSnapshotEntry(date: .now, snapshot: .empty, habitID: nil)
    }

    public func snapshot(for configuration: PickHabitIntent, in context: Context) async -> PickedSnapshotEntry {
        PickedSnapshotEntry(
            date: .now,
            snapshot: WidgetSnapshotStore.read(),
            habitID: configuration.habit?.id
        )
    }

    public func timeline(for configuration: PickHabitIntent, in context: Context) async -> Timeline<PickedSnapshotEntry> {
        let plan = WidgetTimelinePlan.make(series: WidgetSnapshotStore.readSeries())
        let habitID = configuration.habit?.id
        // A widget that ignores its configuration and one that was never
        // configured render identically, and neither the unit suite nor a
        // screenshot can tell them apart. Counts only — never a habit name —
        // so the log stays as private as the app.
        //
        //   xcrun simctl spawn <sim> log stream --level debug \
        //     --predicate 'subsystem == "dev.scastiel.kado"'
        //
        // Not behind `#if DEBUG`: whether a package target gets `-DDEBUG`
        // from the app's configuration is not something to bet a diagnostic
        // on, and `.debug` is dropped unless someone is streaming for it.
        Logger(subsystem: "dev.scastiel.kado", category: "widget")
            .debug("""
                timeline family=\(String(describing: context.family), privacy: .public) \
                picked=\(habitID == nil ? 0 : 1, privacy: .public) \
                snapshotHabits=\(plan.slots.first?.snapshot.habits.count ?? 0, privacy: .public)
                """)
        let entries = plan.slots.map {
            PickedSnapshotEntry(date: $0.date, snapshot: $0.snapshot, habitID: habitID)
        }
        return Timeline(entries: entries, policy: .after(plan.reloadAfter))
    }
}

/// Entry for the lock widgets that show one user-picked habit.
/// `habitID` is nil when the user hasn't picked one yet or the
/// picked habit was deleted.
public struct PickedSnapshotEntry: TimelineEntry, Sendable {
    public let date: Date
    public let snapshot: WidgetSnapshot
    public let habitID: UUID?

    public init(date: Date, snapshot: WidgetSnapshot, habitID: UUID?) {
        self.date = date
        self.snapshot = snapshot
        self.habitID = habitID
    }

    /// Convenience: resolve the picked habit's today row from the
    /// snapshot (or nil if not picked / deleted / archived).
    public var pickedRow: WidgetTodayRow? {
        guard let habitID else { return nil }
        return snapshot.today.first(where: { $0.habit.id == habitID })
    }

    /// Fallback when the picked habit exists but isn't due today
    /// (so it's missing from `snapshot.today`). Pulls from the
    /// habits list and fabricates a "not due" row so the view can
    /// still render the name.
    public var pickedHabit: WidgetHabit? {
        guard let habitID else { return nil }
        return snapshot.habits.first(where: { $0.id == habitID })
    }
}
