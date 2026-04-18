import Foundation
import SwiftData
import WidgetKit

/// Timeline entry for the lock-screen widgets that show a single
/// user-picked habit. `habit` is nil when no habit is picked, the
/// picked habit was deleted, or the picked habit is archived —
/// the view handles that case with a "Pick a habit" nudge.
public struct PickedHabitEntry: TimelineEntry, Sendable {
    public let date: Date
    public let habit: Habit?
    public let state: HabitRowState?
    public let streak: Int?
    public let scorePercent: Int?

    public init(date: Date, habit: Habit?, state: HabitRowState?, streak: Int?, scorePercent: Int?) {
        self.date = date
        self.habit = habit
        self.state = state
        self.streak = streak
        self.scorePercent = scorePercent
    }

    public static func empty(asOf date: Date = .now) -> PickedHabitEntry {
        PickedHabitEntry(date: date, habit: nil, state: nil, streak: nil, scorePercent: nil)
    }
}

public extension PickedHabitEntry {
    /// Build an entry for `habitID`. Returns an empty entry when
    /// the id is nil, absent from the store, or archived.
    @MainActor
    public static func build(
        for habitID: UUID?,
        from context: ModelContext,
        asOf reference: Date,
        calendar: Calendar,
        scoreCalculator: any HabitScoreCalculating,
        streakCalculator: any StreakCalculating
    ) throws -> PickedHabitEntry {
        guard let habitID else { return .empty(asOf: reference) }
        // Widget extension can't compile `#Predicate` — fetch all
        // and search in Swift. See HabitEntity.fetchSuggestions.
        let descriptor = FetchDescriptor<HabitRecord>()
        guard let record = try context.fetch(descriptor).first(where: { $0.id == habitID }),
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
