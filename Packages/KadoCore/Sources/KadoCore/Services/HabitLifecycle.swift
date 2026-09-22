import Foundation
import SwiftData

/// Moves a habit between active, archived and gone.
///
/// The three writes are each a line long, and they used to live inline
/// in whichever view offered them — Today's long-press menu and the
/// detail toolbar had one copy of `archive` apiece. One home means one
/// place to read what "archive" does, and one place to pin that
/// deleting a habit takes its history with it (`HabitLifecycleTests`).
///
/// Callers are views on the main actor; each follows a call with
/// `WidgetReloader.reloadAll(using:)`, which rebuilds the widget
/// snapshot *and* re-syncs reminders — so an unarchived habit's
/// reminders come back and a deleted one's go away without either
/// being spelled out here.
@MainActor
public struct HabitLifecycle {
    public init() {}

    /// Stamps `archivedAt`. The habit leaves Today, Overview, the
    /// widgets and the reminder schedule, and keeps its completions.
    ///
    /// - Parameter instant: the moment to record — callers pass the
    ///   day-boundary-aware `loggingInstant`, so a habit archived after
    ///   midnight but before the user's day start is stamped on the
    ///   day they were looking at.
    public func archive(_ habit: HabitRecord, at instant: Date, in context: ModelContext) {
        habit.archivedAt = instant
        try? context.save()
    }

    /// Clears `archivedAt`. The habit comes back everywhere `archive`
    /// removed it from, with its history and its old `sortOrder`.
    public func unarchive(_ habit: HabitRecord, in context: ModelContext) {
        habit.archivedAt = nil
        try? context.save()
    }

    /// Deletes the habit for good. Its completions go with it through
    /// the `.cascade` rule on `HabitRecord.completions`, and CloudKit
    /// mirrors each as its own record deletion.
    public func delete(_ habit: HabitRecord, in context: ModelContext) {
        context.delete(habit)
        try? context.save()
    }
}
