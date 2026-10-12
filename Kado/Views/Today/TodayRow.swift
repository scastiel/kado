import Foundation
import KadoCore

/// Value-type snapshot of one row in the Today list.
///
/// `ForEach` retains the collection it was handed and re-reads
/// `Identifiable.id` during the list diff — and that diff can run
/// *after* a dev-mode `ModelContainer` swap has invalidated every
/// `HabitRecord` the previous store vended. Reading any persisted
/// property on an invalidated managed object traps inside SwiftData,
/// so the list must never hold one (issue #63).
///
/// Handing `ForEach` plain structs leaves nothing to invalidate.
/// Mutations resolve the record by `id` against the live `@Query`,
/// which always reflects whichever store is currently mounted.
struct TodayRow: Identifiable {
    let habit: Habit
    let completions: [Completion]

    var id: UUID { habit.id }

    init(habit: Habit, completions: [Completion]) {
        self.habit = habit
        self.completions = completions
    }

    init(_ record: HabitRecord) {
        self.init(
            habit: record.snapshot,
            completions: (record.completions ?? []).compactMap(\.snapshot)
        )
    }
}

extension TodayRow {
    /// Snapshots every record, then splits the rows into the two
    /// sections Today renders: the ones the schedule asks for today
    /// (or that already have progress logged today), and the rest.
    ///
    /// The snapshot happens once, up front, so the two sections and
    /// every derived metric read the same frozen data — and so nothing
    /// downstream keeps a reference to a managed object.
    static func sections(
        from records: [HabitRecord],
        on now: Date,
        evaluator: any FrequencyEvaluating,
        calendar: Calendar
    ) -> (due: [TodayRow], other: [TodayRow]) {
        var due: [TodayRow] = []
        var other: [TodayRow] = []
        // Spelled out rather than `map(TodayRow.init)`: passing a
        // MainActor-isolated initializer as a function value to a
        // nonisolated generic loses the isolation and warns.
        for row in records.map({ TodayRow($0) }) {
            let isDue = evaluator.isDueOrLogged(
                habit: row.habit,
                on: now,
                completions: row.completions,
                calendar: calendar
            )
            if isDue {
                due.append(row)
            } else {
                other.append(row)
            }
        }
        return (due, other)
    }
}

extension TodayRow {
    /// The habit the regular-width Today shows beside its list: the
    /// one the user `picked`, while Today still lists it, otherwise
    /// the first row (issue #140).
    ///
    /// A picked habit that was archived or deleted — from its own
    /// detail, from the row's menu, by a sync landing — falls back
    /// rather than leaving the detail column on a habit the list no
    /// longer has, or on nothing.
    static func selection(picked: UUID?, due: [TodayRow], other: [TodayRow]) -> UUID? {
        if let picked, due.contains(where: { $0.id == picked }) || other.contains(where: { $0.id == picked }) {
            return picked
        }
        return (due.first ?? other.first)?.id
    }
}

/// Navigation value for a pushed habit-detail screen.
///
/// Carries the habit's id rather than the `HabitRecord` itself: a
/// `NavigationPath` outlives a dev-mode container swap, and a managed
/// object it retained from the previous store traps the moment SwiftUI
/// re-reads it. `HabitDetailLoader` turns the id back into a live
/// record against the store that is mounted now.
struct HabitRoute: Hashable {
    let id: UUID
}
