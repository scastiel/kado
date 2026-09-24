import Foundation
import KadoCore

/// Value-type snapshot of one row in the Archived habits list.
///
/// Same shape as `TodayRow`, for the same reason: `ForEach` retains
/// what it is handed and re-reads it during the list diff, which can
/// run after a dev-mode container swap has invalidated every record
/// the previous store vended (issue #63). Rows hold structs; mutations
/// resolve the record by `id` against the live `@Query`.
struct ArchivedHabitRow: Identifiable {
    let habit: Habit
    /// How much history the habit carries — shown on the row so the
    /// user knows what Delete would take with it.
    let completionCount: Int

    var id: UUID { habit.id }

    /// When the habit was archived. Non-optional here: a row only
    /// exists for an archived habit, and the fallback is never read.
    var archivedAt: Date { habit.archivedAt ?? habit.createdAt }

    init(habit: Habit, completionCount: Int) {
        self.habit = habit
        self.completionCount = completionCount
    }

    init(_ record: HabitRecord) {
        self.init(
            habit: record.snapshot,
            completionCount: record.completions?.count ?? 0
        )
    }
}

extension ArchivedHabitRow {
    /// Snapshots every record and orders the rows most recently
    /// archived first — the one the user just put here is the one they
    /// are most likely looking for.
    static func rows(from records: [HabitRecord]) -> [ArchivedHabitRow] {
        // Spelled out rather than `map(ArchivedHabitRow.init)`: passing
        // a MainActor-isolated initializer as a function value to a
        // nonisolated generic loses the isolation and warns.
        var rows: [ArchivedHabitRow] = []
        for record in records {
            rows.append(ArchivedHabitRow(record))
        }
        return rows.sorted { $0.archivedAt > $1.archivedAt }
    }
}
