import Foundation
import SwiftData
import KadoCore

/// The day-edit popover's mutation path, shared by the detail
/// calendar and the Overview matrix. One method per popover
/// callback; each applies the change through `CompletionToggler` /
/// `CompletionLogger`, saves, and runs the app's post-mutation
/// postamble (`WidgetReloader`), so a screen that presents the
/// popover has nothing left to do but feed the returned `Change`
/// into its haptic.
///
/// The caller resolves `habit` from its own `@Query` and passes the
/// live record in. The editor never fetches: a fetch between a view's
/// tracked read and the mutation leaves the view un-notified on
/// value-only saves (issue #80, `ObservationAfterFetchTests`).
@MainActor
struct DayCompletionEditor {
    /// What a mutation moved the day's value from and to. `after` is
    /// derived from the mutation rather than read back, because a
    /// just-deleted record can still answer until the save lands.
    nonisolated struct Change: Equatable, Sendable {
        let before: Double
        let after: Double
    }

    let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    private var logger: CompletionLogger { CompletionLogger(calendar: calendar) }

    /// Binary / negative: flips the day between done and not done.
    @discardableResult
    func toggle(for habit: HabitRecord, on day: Date, in context: ModelContext) -> Change {
        let before = logger.value(for: habit, on: day)
        let result = CompletionToggler(calendar: calendar).toggleToday(for: habit, on: day, in: context)
        commit(in: context)
        return Change(before: before, after: result == .completed ? 1 : 0)
    }

    /// Counter: sets the day's count. Non-positive values clear the
    /// day, so `after` is clamped to 0 rather than echoing the input.
    @discardableResult
    func setCounter(_ value: Double, for habit: HabitRecord, on day: Date, in context: ModelContext) -> Change {
        let before = logger.value(for: habit, on: day)
        logger.setCounter(for: habit, on: day, to: value, in: context)
        commit(in: context)
        return Change(before: before, after: max(0, value))
    }

    /// Timer: sets the day's duration. `logTimerSession` would record
    /// a zero-value session for 0 seconds; a duration stepped down to
    /// nothing routes through `clear` instead so the day returns to
    /// missed.
    @discardableResult
    func setTimerSeconds(_ seconds: TimeInterval, for habit: HabitRecord, on day: Date, in context: ModelContext) -> Change {
        guard seconds > 0 else { return clear(for: habit, on: day, in: context) }
        let before = logger.value(for: habit, on: day)
        logger.logTimerSession(for: habit, seconds: seconds, on: day, in: context)
        commit(in: context)
        return Change(before: before, after: seconds)
    }

    /// Empties the day: deletes its record, or zeroes it when a note
    /// would otherwise be lost.
    @discardableResult
    func clear(for habit: HabitRecord, on day: Date, in context: ModelContext) -> Change {
        let before = logger.value(for: habit, on: day)
        logger.clear(for: habit, on: day, in: context)
        commit(in: context)
        return Change(before: before, after: 0)
    }

    /// Sets or removes the day's note. No `Change`: the value is
    /// untouched, so there is nothing for a haptic to compare.
    func setNote(_ note: String?, for habit: HabitRecord, on day: Date, in context: ModelContext) {
        logger.setNote(for: habit, on: day, to: note, in: context)
        commit(in: context)
    }

    private func commit(in context: ModelContext) {
        try? context.save()
        WidgetReloader.reloadAll(using: context)
    }
}
