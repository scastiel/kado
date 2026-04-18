import Foundation
import SwiftData
import WidgetKit

/// One row in a widget timeline entry: everything the widget view
/// needs for a single habit, derived at provider time so the view
/// stays purely presentational.
struct HabitTimelineRow: Identifiable, Equatable, Sendable {
    let id: UUID
    let habit: Habit
    let state: HabitRowState
    let streak: Int
    let scorePercent: Int
}

/// Timeline entry for the small and medium home-screen widgets.
/// Carries a capped list of rows for the visible area plus an
/// uncapped total so the progress summary can read "3 of 5 done"
/// even when only 4 fit on screen.
struct HabitTimelineEntry: TimelineEntry, Sendable {
    let date: Date
    let rows: [HabitTimelineRow]
    let totalCount: Int
    let completedCount: Int

    static func placeholder(limit: Int) -> HabitTimelineEntry {
        HabitTimelineEntry(
            date: .now,
            rows: [],
            totalCount: 0,
            completedCount: 0
        )
    }
}

extension HabitTimelineEntry {
    /// Build an entry from the active habits in `context`. Applies
    /// `frequencyEvaluator` to the asked-for date so only habits
    /// actually due today show up, sorts them by creation order
    /// (matching the main-app Today view), caps the on-screen list
    /// to `limit` rows, and exposes `totalCount` / `completedCount`
    /// for the medium widget's summary line.
    @MainActor
    static func build(
        from context: ModelContext,
        asOf reference: Date,
        calendar: Calendar,
        frequencyEvaluator: any FrequencyEvaluating,
        scoreCalculator: any HabitScoreCalculating,
        streakCalculator: any StreakCalculating,
        limit: Int
    ) throws -> HabitTimelineEntry {
        let descriptor = FetchDescriptor<HabitRecord>(
            predicate: #Predicate { $0.archivedAt == nil },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        let records = try context.fetch(descriptor)

        var rows: [HabitTimelineRow] = []
        var completed = 0
        for record in records {
            let snap = record.snapshot
            let comps = (record.completions ?? []).map(\.snapshot)
            guard frequencyEvaluator.isDue(habit: snap, on: reference, completions: comps) else {
                continue
            }
            let state = HabitRowState.resolve(
                habit: snap,
                completions: comps,
                calendar: calendar,
                asOf: reference
            )
            let streak = streakCalculator.current(for: snap, completions: comps, asOf: reference)
            let score = scoreCalculator.currentScore(for: snap, completions: comps, asOf: reference)
            rows.append(
                HabitTimelineRow(
                    id: snap.id,
                    habit: snap,
                    state: state,
                    streak: streak,
                    scorePercent: Int((score * 100).rounded())
                )
            )
            if state.status == .complete {
                completed += 1
            }
        }

        return HabitTimelineEntry(
            date: reference,
            rows: Array(rows.prefix(limit)),
            totalCount: rows.count,
            completedCount: completed
        )
    }
}
