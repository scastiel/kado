import Foundation
import SwiftData

/// Counter/timer completion operations for the detail view's
/// quick-log surface. Mirrors `CompletionToggler`'s shape but
/// handles value-carrying mutations rather than presence toggles.
@MainActor
struct CompletionLogger {
    let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    /// Adds `delta` to today's completion value, creating a record
    /// if none exists.
    func incrementCounter(
        for habit: HabitRecord,
        on date: Date = .now,
        by delta: Double = 1,
        in context: ModelContext
    ) {
        if let existing = todayCompletion(for: habit, on: date) {
            existing.value += delta
        } else {
            let completion = CompletionRecord(date: date, value: delta, habit: habit)
            context.insert(completion)
        }
    }

    /// Subtracts 1 from today's completion value. When the value
    /// drops below 1, the record is deleted so "no completion" ↔
    /// "not done today" stays a bijection.
    func decrementCounter(
        for habit: HabitRecord,
        on date: Date = .now,
        in context: ModelContext
    ) {
        guard let existing = todayCompletion(for: habit, on: date) else { return }
        if existing.value <= 1 {
            context.delete(existing)
        } else {
            existing.value -= 1
        }
    }

    /// Replaces today's completion with the exact value. Used by the
    /// "Log specific value…" sheet on the Today row's context menu —
    /// the row's `−/+` stepper handles unit changes; this handles
    /// "I forgot all day, set it to 5". A non-positive value deletes
    /// today's completion (preserves the "no completion ↔ not started"
    /// bijection).
    func setCounter(
        for habit: HabitRecord,
        on date: Date = .now,
        to value: Double,
        in context: ModelContext
    ) {
        let existing = todayCompletion(for: habit, on: date)
        if value <= 0 {
            if let existing { context.delete(existing) }
            return
        }
        if let existing {
            existing.value = value
        } else {
            let completion = CompletionRecord(date: date, value: value, habit: habit)
            context.insert(completion)
        }
    }

    /// Replaces today's completion with one recording the given
    /// session duration. Single-record-per-day invariant holds.
    func logTimerSession(
        for habit: HabitRecord,
        seconds: TimeInterval,
        on date: Date = .now,
        in context: ModelContext
    ) {
        if let existing = todayCompletion(for: habit, on: date) {
            context.delete(existing)
        }
        let completion = CompletionRecord(date: date, value: seconds, habit: habit)
        context.insert(completion)
    }

    /// Removes a specific completion (used by history-list swipes).
    func delete(_ completion: CompletionRecord, in context: ModelContext) {
        context.delete(completion)
    }

    private func todayCompletion(for habit: HabitRecord, on date: Date) -> CompletionRecord? {
        habit.completions?.first {
            calendar.isDate($0.date, inSameDayAs: date)
        }
    }
}
