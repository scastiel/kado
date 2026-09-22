import Foundation
import KadoCore

/// Canned `WidgetSnapshot` values for SwiftUI widget previews.
enum PreviewSnapshots {
    static let firstHabitID = UUID()

    /// A pick for the today widgets, deliberately out of snapshot
    /// order so the previews show that the widget follows the *pick*
    /// order rather than the app's.
    static var pickedTodayIDs: [UUID] {
        let rows = populated.today
        guard rows.count >= 4 else { return rows.map(\.habit.id) }
        return [rows[3].habit.id, rows[0].habit.id]
    }

    /// A pick with one habit the app knows but hasn't scheduled today,
    /// so the previews show it dimmed with "Not today" rather than
    /// silently absent.
    static var pickedWithNotDueIDs: [UUID] {
        [notDueHabit.id] + Array(pickedTodayIDs.prefix(1))
    }

    /// Same idea for the weekly grid.
    static var pickedMatrixIDs: [UUID] {
        let rows = populated.matrix
        guard rows.count >= 6 else { return rows.map(\.habit.id) }
        return [rows[5].habit.id, rows[1].habit.id, rows[0].habit.id]
    }

    /// Stored, not computed. Every habit here gets a fresh `UUID` on
    /// construction, so a computed property would hand each caller a
    /// different set of ids — and `pickedTodayIDs` would then name
    /// habits that aren't in the snapshot the preview renders,
    /// silently showing the "nothing picked" placeholder instead of
    /// the pick.
    /// In `habits` but not in `today`: what a picked habit looks like
    /// on a day it isn't scheduled.
    static let notDueHabit = WidgetHabit(
        id: UUID(),
        name: "Running",
        color: .green,
        icon: "figure.run",
        typeKind: .binary,
        target: nil,
        currentStreak: 5,
        bestStreak: 12,
        currentScore: 0.54
    )

    static let populated: WidgetSnapshot = {
        let today = makeTodayRows()
        let (matrix, days) = makeMatrix()
        return WidgetSnapshot(
            generatedAt: .now,
            habits: today.map(\.habit) + [notDueHabit],
            today: today,
            totalDueToday: today.count,
            completedToday: today.filter { $0.status == .complete }.count,
            matrix: matrix,
            matrixDays: days
        )
    }()

    /// `populated` with every row finished — the closed ring on the
    /// day-progress widget, and the small widget's grid with nothing
    /// left to tap.
    static var allDone: WidgetSnapshot {
        let today = makeTodayRows().map { row in
            WidgetTodayRow(
                habit: row.habit,
                status: .complete,
                progress: 1,
                valueToday: row.habit.target ?? 1,
                streak: row.streak,
                scorePercent: row.scorePercent
            )
        }
        let (matrix, days) = makeMatrix()
        return WidgetSnapshot(
            generatedAt: .now,
            habits: today.map(\.habit),
            today: today,
            totalDueToday: today.count,
            completedToday: today.count,
            matrix: matrix,
            matrixDays: days
        )
    }

    private static func makeTodayRows() -> [WidgetTodayRow] {
        func row(
            id: UUID = UUID(),
            name: String,
            icon: String,
            color: HabitColor,
            typeKind: WidgetHabitTypeKind,
            target: Double?,
            status: WidgetStatus,
            progress: Double,
            value: Double?,
            streak: Int = 7,
            score: Int = 70
        ) -> WidgetTodayRow {
            // The nested habit carries the same streak and score the
            // row does. `populated` publishes `today.map(\.habit)` as
            // `snapshot.habits`, so leaving these at their zero
            // defaults would put one habit id in the fixture twice
            // with contradictory stats — exactly what
            // `scorePercentAgreesAcrossSurfaces` forbids in a real
            // build.
            WidgetTodayRow(
                habit: WidgetHabit(
                    id: id,
                    name: name,
                    color: color,
                    icon: icon,
                    typeKind: typeKind,
                    target: target,
                    currentStreak: streak,
                    bestStreak: streak,
                    currentScore: Double(score) / 100
                ),
                status: status,
                progress: progress,
                valueToday: value,
                streak: streak,
                scorePercent: score
            )
        }

        return [
            row(
                id: firstHabitID,
                name: "Meditate",
                icon: "leaf.fill",
                color: .green,
                typeKind: .binary,
                target: nil,
                status: .complete,
                progress: 1,
                value: 1
            ),
            row(
                name: "Read",
                icon: "book.fill",
                color: .blue,
                typeKind: .binary,
                target: nil,
                status: .complete,
                progress: 1,
                value: 1
            ),
            row(
                name: "Water",
                icon: "drop.fill",
                color: .teal,
                typeKind: .counter,
                target: 8,
                status: .partial,
                progress: 3.0 / 8.0,
                value: 3
            ),
            row(
                name: "Focus",
                icon: "timer",
                color: .orange,
                typeKind: .timer,
                target: 25 * 60,
                status: .partial,
                progress: 15.0 / 25.0,
                value: 15 * 60
            ),
            row(
                name: "Workout",
                icon: "dumbbell.fill",
                color: .purple,
                typeKind: .binary,
                target: nil,
                status: .none,
                progress: 0,
                value: nil
            ),
        ]
    }

    private static func makeMatrix() -> ([WidgetMatrixRow], [Date]) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let days: [Date] = (0..<7).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today)
        }
        // One row per tuple rather than five arrays zipped by index:
        // parallel arrays only stay safe while they stay the same
        // length, and adding an eighth habit to some of them traps on
        // a subscript rather than failing to compile.
        //
        // Two streaks sit at zero on purpose — the chip drops the
        // flame there, and that arm needs eyes on it too — and one is
        // three-digit, so the widest chip is in the picture.
        let specs: [(name: String, icon: String, color: HabitColor, streak: Int, score: Double)] = [
            ("Meditate", "leaf.fill", .green, 12, 0.92),
            ("Read", "book.fill", .blue, 5, 0.78),
            ("Water", "drop.fill", .teal, 0, 0.41),
            ("Focus", "timer", .orange, 31, 0.86),
            ("Workout", "dumbbell.fill", .purple, 0, 0.12),
            ("Stretch", "figure.cooldown", .mint, 128, 1.0),
            ("Journal", "square.and.pencil", .yellow, 3, 0.55),
        ]

        let rows: [WidgetMatrixRow] = specs.enumerated().map { index, spec in
            let habit = WidgetHabit(
                id: index == 0 ? firstHabitID : UUID(),
                name: spec.name,
                color: spec.color,
                icon: spec.icon,
                typeKind: .binary,
                target: nil,
                currentStreak: spec.streak,
                bestStreak: spec.streak,
                currentScore: spec.score
            )
            let cells: [WidgetDayCell] = days.enumerated().map { dayIndex, _ in
                let roll = Double((dayIndex + index) % 5) / 4.0
                // Sprinkle the two non-scored states through the
                // preview so the hollow off-schedule treatment and
                // the neutral not-due cell both get eyes on them at
                // widget scale.
                switch (dayIndex + index) % 7 {
                case 3: return .offSchedule(1.0)
                case 6: return .notDue
                default: return .scored(roll)
                }
            }
            return WidgetMatrixRow(habit: habit, cells: cells)
        }

        return (rows, days)
    }
}
