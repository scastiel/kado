import Foundation
import SwiftData

/// Toggles the "done today" state for a habit by inserting or deleting
/// a `CompletionRecord` on the given day.
///
/// Binary and negative habits use this directly from Today-tab rows.
/// Counter and timer habits will use it too once the detail view ships
/// with per-type input affordances.
@MainActor
struct CompletionToggler {
    let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    /// Inserts a unit completion for `habit` on `date`'s day if none
    /// exists; otherwise deletes the existing one. Day comparison uses
    /// the injected calendar so DST and timezone boundaries behave.
    func toggleToday(
        for habit: HabitRecord,
        on date: Date = .now,
        in context: ModelContext
    ) {
        if let existing = habit.completions.first(where: {
            calendar.isDate($0.date, inSameDayAs: date)
        }) {
            context.delete(existing)
        } else {
            let completion = CompletionRecord(date: date, value: 1, habit: habit)
            context.insert(completion)
        }
    }
}
