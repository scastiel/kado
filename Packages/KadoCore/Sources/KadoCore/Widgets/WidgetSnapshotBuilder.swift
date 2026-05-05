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
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        let records = (try? context.fetch(descriptor)) ?? []
        let active = records.filter { $0.archivedAt == nil }

        // Compute per-habit stats once. Reused across the three
        // WidgetHabit construction sites (top-level, today rows,
        // matrix rows) so consumers see consistent values.
        struct HabitStats { let current: Int; let best: Int; let score: Double }
        var statsByID: [UUID: HabitStats] = [:]
        for record in active {
            let snap = record.snapshot
            let comps = (record.completions ?? []).map(\.snapshot)
            statsByID[snap.id] = HabitStats(
                current: streakCalculator.current(for: snap, completions: comps, asOf: reference),
                best: streakCalculator.best(for: snap, completions: comps, asOf: reference),
                score: scoreCalculator.currentScore(for: snap, completions: comps, asOf: reference)
            )
        }

        func makeWidgetHabit(from record: HabitRecord) -> WidgetHabit {
            let stats = statsByID[record.id]
            return WidgetHabit(
                id: record.id,
                name: record.name,
                color: record.color,
                icon: record.icon,
                typeKind: mapTypeKind(record.type),
                target: mapTarget(record.type),
                currentStreak: stats?.current ?? 0,
                bestStreak: stats?.best ?? 0,
                currentScore: stats?.score ?? 0
            )
        }

        func makeWidgetHabit(from snap: Habit) -> WidgetHabit {
            let stats = statsByID[snap.id]
            return WidgetHabit(
                id: snap.id,
                name: snap.name,
                color: snap.color,
                icon: snap.icon,
                typeKind: mapTypeKind(snap.type),
                target: mapTarget(snap.type),
                currentStreak: stats?.current ?? 0,
                bestStreak: stats?.best ?? 0,
                currentScore: stats?.score ?? 0
            )
        }

        let widgetHabits = active.map(makeWidgetHabit(from:))

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
            let stats = statsByID[snap.id]
            let widgetHabit = makeWidgetHabit(from: snap)
            todayRows.append(
                WidgetTodayRow(
                    habit: widgetHabit,
                    status: mapStatus(state.status),
                    progress: state.progress,
                    valueToday: state.valueToday,
                    streak: stats?.current ?? 0,
                    scorePercent: Int(((stats?.score ?? 0) * 100).rounded())
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
            WidgetMatrixRow(
                habit: makeWidgetHabit(from: row.habit),
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
