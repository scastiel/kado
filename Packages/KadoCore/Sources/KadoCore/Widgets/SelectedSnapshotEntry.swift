import Foundation
import WidgetKit

/// Entry for the home widgets, which show several user-picked habits.
/// `habitIDs` is the pick, in pick order; empty means the user hasn't
/// chosen, which shows everything — the state every freshly added
/// widget starts in, and the one an already-placed widget inherits
/// when a build swaps `StaticConfiguration` for `AppIntentConfiguration`
/// under it.
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

    /// `true` when the user picked habits and none of them can be
    /// drawn — not due today, archived, deleted. Distinct from an empty
    /// day: the tile says "no picked habits to show", never "all done".
    public func isFilteredOut(limit: Int) -> Bool {
        !habitIDs.isEmpty && todayRows(limit: limit).isEmpty
    }
}
