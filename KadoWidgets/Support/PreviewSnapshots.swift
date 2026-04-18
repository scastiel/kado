import Foundation
import KadoCore

/// Canned `WidgetSnapshot` values for SwiftUI widget previews.
enum PreviewSnapshots {
    static let firstHabitID = UUID()

    static var populated: WidgetSnapshot {
        let today = makeTodayRows()
        let (matrix, days) = makeMatrix()
        return WidgetSnapshot(
            generatedAt: .now,
            habits: today.map(\.habit),
            today: today,
            totalDueToday: today.count,
            completedToday: today.filter { $0.status == .complete }.count,
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
            WidgetTodayRow(
                habit: WidgetHabit(
                    id: id,
                    name: name,
                    color: color,
                    icon: icon,
                    typeKind: typeKind,
                    target: target
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
        let colors: [HabitColor] = [.green, .blue, .teal, .orange, .purple, .mint, .yellow]
        let names = ["Meditate", "Read", "Water", "Focus", "Workout", "Stretch", "Journal"]
        let icons = ["leaf.fill", "book.fill", "drop.fill", "timer", "dumbbell.fill", "figure.cooldown", "square.and.pencil"]

        let rows: [WidgetMatrixRow] = zip(zip(names, icons), colors).enumerated().map { index, pair in
            let ((name, icon), color) = pair
            let habit = WidgetHabit(
                id: index == 0 ? firstHabitID : UUID(),
                name: name,
                color: color,
                icon: icon,
                typeKind: .binary,
                target: nil
            )
            let cells: [WidgetDayCell] = days.enumerated().map { dayIndex, _ in
                let roll = Double((dayIndex + index) % 5) / 4.0
                return .scored(roll)
            }
            return WidgetMatrixRow(habit: habit, cells: cells)
        }

        return (rows, days)
    }
}
