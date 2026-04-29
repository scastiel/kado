import Foundation
import SwiftData

/// Toggles the "done today" state for a habit by inserting or deleting
/// a `CompletionRecord` on the given day.
///
/// Binary and negative habits use this directly from Today-tab rows.
/// Counter and timer habits will use it too once the detail view ships
/// with per-type input affordances.
@MainActor
public struct CompletionToggler {
    public let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    /// Inserts a unit completion for `habit` on `date`'s day if none
    /// exists; otherwise deletes the existing one. Day comparison uses
    /// the injected calendar so DST and timezone boundaries behave.
    /// Returns which direction the toggle went so callers that need
    /// to react (e.g. spoken Siri dialog) can branch without a second
    /// round-trip to the store.
    @discardableResult
    public func toggleToday(
        for habit: HabitRecord,
        on date: Date = .now,
        in context: ModelContext
    ) -> ToggleResult {
        if let existing = habit.completions?.first(where: {
            calendar.isDate($0.date, inSameDayAs: date)
        }) {
            if existing.value == 0 {
                existing.value = 1
                return .completed
            } else if existing.note != nil {
                existing.value = 0
                return .uncompleted
            } else {
                context.delete(existing)
                return .uncompleted
            }
        } else {
            let completion = CompletionRecord(date: date, value: 1, habit: habit)
            context.insert(completion)
            return .completed
        }
    }

    public enum ToggleResult: Equatable, Sendable {
        case completed
        case uncompleted
    }

    /// Sets `value` as the completion record for `habit` on `date`'s
    /// day, overwriting any existing same-day completion. A zero
    /// value removes the day's completion — unless it carries a note,
    /// in which case the value is zeroed to preserve the note. Day
    /// comparison goes through the injected calendar.
    public func setValueToday(
        _ value: Double,
        for habit: HabitRecord,
        on date: Date = .now,
        in context: ModelContext
    ) {
        if let existing = habit.completions?.first(where: {
            calendar.isDate($0.date, inSameDayAs: date)
        }) {
            if value == 0 {
                if existing.note != nil {
                    existing.value = 0
                } else {
                    context.delete(existing)
                }
            } else {
                existing.value = value
                existing.date = date
            }
        } else if value != 0 {
            let completion = CompletionRecord(date: date, value: value, habit: habit)
            context.insert(completion)
        }
    }
}
