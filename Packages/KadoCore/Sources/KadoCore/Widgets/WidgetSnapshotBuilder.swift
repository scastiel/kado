import Foundation
import SwiftData

/// Builds a `WidgetSnapshot` from SwiftData state. Called on the
/// app side (main process) after every mutation so the widget
/// always reads fresh data.
@MainActor
public enum WidgetSnapshotBuilder {
    /// Gather everything the widgets need from `context` and
    /// serialize to a single `WidgetSnapshot` value.
    public static func build(
        from context: ModelContext,
        asOf reference: Date = .now,
        calendar: Calendar = .current,
        matrixWindowDays: Int = 7,
        scoreCalculator: any HabitScoreCalculating = DefaultHabitScoreCalculator(),
        streakCalculator: any StreakCalculating = DefaultStreakCalculator(),
        frequencyEvaluator: any FrequencyEvaluating = DefaultFrequencyEvaluator()
    ) -> WidgetSnapshot {
        let descriptor = FetchDescriptor<HabitRecord>(
            sortBy: [SortDescriptor(\.createdAt)]
        )
        let records = (try? context.fetch(descriptor)) ?? []
        let active = records.filter { $0.archivedAt == nil }

        let widgetHabits = active.map { record in
            WidgetHabit(
                id: record.id,
                name: record.name,
                color: record.color,
                icon: record.icon,
                typeKind: mapTypeKind(record.type),
                target: mapTarget(record.type)
            )
        }

        var todayRows: [WidgetTodayRow] = []
        var completed = 0
        for record in active {
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
            let widgetHabit = WidgetHabit(
                id: snap.id,
                name: snap.name,
                color: snap.color,
                icon: snap.icon,
                typeKind: mapTypeKind(snap.type),
                target: mapTarget(snap.type)
            )
            todayRows.append(
                WidgetTodayRow(
                    habit: widgetHabit,
                    status: mapStatus(state.status),
                    progress: state.progress,
                    valueToday: state.valueToday,
                    streak: streak,
                    scorePercent: Int((score * 100).rounded())
                )
            )
            if state.status == .complete { completed += 1 }
        }

        // Matrix window (last N days ending today).
        let today = calendar.startOfDay(for: reference)
        let matrixDays: [Date] = (0..<matrixWindowDays).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today)
        }
        let habits = active.map(\.snapshot)
        let allCompletions = active.flatMap { ($0.completions ?? []).map(\.snapshot) }
        let matrix = OverviewMatrix.compute(
            habits: habits,
            completions: allCompletions,
            days: matrixDays,
            today: reference,
            calendar: calendar,
            frequencyEvaluator: frequencyEvaluator
        )
        let widgetMatrix = matrix.map { row in
            let wh = WidgetHabit(
                id: row.habit.id,
                name: row.habit.name,
                color: row.habit.color,
                icon: row.habit.icon,
                typeKind: mapTypeKind(row.habit.type),
                target: mapTarget(row.habit.type)
            )
            return WidgetMatrixRow(
                habit: wh,
                cells: row.days.map(mapDayCell)
            )
        }

        return WidgetSnapshot(
            generatedAt: reference,
            habits: widgetHabits,
            today: todayRows,
            totalDueToday: todayRows.count,
            completedToday: completed,
            matrix: widgetMatrix,
            matrixDays: matrixDays
        )
    }

    /// Convenience: build from the production container and write
    /// to the App Group JSON in one shot. Safe to call from any
    /// mutation site.
    public static func rebuildAndWrite(using context: ModelContext) {
        let snapshot = build(from: context)
        WidgetSnapshotStore.write(snapshot)
    }

    // MARK: - Mapping helpers

    private static func mapTypeKind(_ type: HabitType) -> WidgetHabitTypeKind {
        switch type {
        case .binary: .binary
        case .negative: .negative
        case .counter: .counter
        case .timer: .timer
        }
    }

    private static func mapTarget(_ type: HabitType) -> Double? {
        switch type {
        case .binary, .negative: nil
        case .counter(let target): target
        case .timer(let targetSeconds): targetSeconds
        }
    }

    private static func mapStatus(_ status: HabitRowState.Status) -> WidgetStatus {
        switch status {
        case .none: .none
        case .partial: .partial
        case .complete: .complete
        }
    }

    private static func mapDayCell(_ cell: DayCell) -> WidgetDayCell {
        switch cell {
        case .future: .future
        case .notDue: .notDue
        case .scored(let v): .scored(v)
        }
    }
}
