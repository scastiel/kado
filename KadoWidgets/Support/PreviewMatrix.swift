import Foundation
import KadoCore

/// Sample `WeeklyMatrixEntry` for SwiftUI previews.
enum PreviewMatrix {
    static func sampleEntry() -> WeeklyMatrixEntry {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let days: [Date] = (0..<7).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today)
        }
        let colors: [HabitColor] = [.green, .blue, .teal, .orange, .purple, .mint, .yellow]
        let names = ["Meditate", "Read", "Water", "Focus", "Workout", "Stretch", "Journal"]
        let icons = ["leaf.fill", "book.fill", "drop.fill", "timer", "dumbbell.fill", "figure.cooldown", "square.and.pencil"]

        let rows: [MatrixRow] = zip(zip(names, icons), colors).enumerated().map { index, pair in
            let ((name, icon), color) = pair
            let habit = Habit(
                id: UUID(),
                name: name,
                frequency: .daily,
                type: .binary,
                createdAt: .now.addingTimeInterval(TimeInterval(-7 * 86400)),
                color: color,
                icon: icon
            )
            let cells: [DayCell] = days.enumerated().map { dayIndex, _ in
                // Seed a plausible pattern — some habits are perfectionists,
                // others partial, one has gaps.
                let roll = Double((dayIndex + index) % 5) / 4.0
                return .scored(roll)
            }
            return MatrixRow(habit: habit, days: cells)
        }

        return WeeklyMatrixEntry(date: .now, days: days, rows: rows)
    }
}
