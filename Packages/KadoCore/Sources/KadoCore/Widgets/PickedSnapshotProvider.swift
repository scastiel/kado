import AppIntents
import Foundation
@preconcurrency import WidgetKit

/// `AppIntentTimelineProvider` for the lock widgets that pick a
/// single habit. Emits an entry with the snapshot + the configured
/// habit ID; the view plucks the matching row out of the snapshot.
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
        let now = Date.now
        let entry = PickedSnapshotEntry(
            date: now,
            snapshot: WidgetSnapshotStore.read(),
            habitID: configuration.habit?.id
        )
        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 1, to: now)
            ?? now.addingTimeInterval(3600)
        return Timeline(entries: [entry], policy: .after(nextRefresh))
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
