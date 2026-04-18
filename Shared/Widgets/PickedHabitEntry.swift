import Foundation
import SwiftData
import WidgetKit

/// Timeline entry for the lock-screen widgets that show a single
/// user-picked habit. `habit` is nil when no habit is picked, the
/// picked habit was deleted, or the picked habit is archived —
/// the view handles that case with a "Pick a habit" nudge.
struct PickedHabitEntry: TimelineEntry, Sendable {
    let date: Date
    let habit: Habit?
    let state: HabitRowState?
    let streak: Int?
    let scorePercent: Int?

    static func empty(asOf date: Date = .now) -> PickedHabitEntry {
        PickedHabitEntry(date: date, habit: nil, state: nil, streak: nil, scorePercent: nil)
    }
}

extension PickedHabitEntry {
    /// Build an entry for `habitID`. Returns an empty entry when
    /// the id is nil, absent from the store, or archived.
    @MainActor
    static func build(
        for habitID: UUID?,
        from context: ModelContext,
        asOf reference: Date,
        calendar: Calendar,
        scoreCalculator: any HabitScoreCalculating,
        streakCalculator: any StreakCalculating
    ) throws -> PickedHabitEntry {
        guard let habitID else { return .empty(asOf: reference) }
        let descriptor = FetchDescriptor<HabitRecord>(
            predicate: #Predicate { $0.id == habitID }
        )
        guard let record = try context.fetch(descriptor).first,
              record.archivedAt == nil else {
            return .empty(asOf: reference)
        }
        let snap = record.snapshot
        let comps = (record.completions ?? []).map(\.snapshot)
        let state = HabitRowState.resolve(
            habit: snap,
            completions: comps,
            calendar: calendar,
            asOf: reference
        )
        let streak = streakCalculator.current(for: snap, completions: comps, asOf: reference)
        let score = scoreCalculator.currentScore(for: snap, completions: comps, asOf: reference)
        return PickedHabitEntry(
            date: reference,
            habit: snap,
            state: state,
            streak: streak,
            scorePercent: Int((score * 100).rounded())
        )
    }
}
