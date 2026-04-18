import Foundation

/// Canned data for widget SwiftUI previews. Covers the four habit
/// types + representative state-shape combos (done, partial, not
/// done) so previews catch visual regressions without having to
/// spin up a live ModelContainer.
enum PreviewRows {
    static let mixed5: [HabitTimelineRow] = [
        row(
            name: "Meditate",
            icon: "leaf.fill",
            color: .green,
            type: .binary,
            status: .complete,
            progress: 1.0,
            value: 1
        ),
        row(
            name: "Read",
            icon: "book.fill",
            color: .blue,
            type: .binary,
            status: .complete,
            progress: 1.0,
            value: 1
        ),
        row(
            name: "Water",
            icon: "drop.fill",
            color: .teal,
            type: .counter(target: 8),
            status: .partial,
            progress: 3.0 / 8.0,
            value: 3
        ),
        row(
            name: "Focus",
            icon: "timer",
            color: .orange,
            type: .timer(targetSeconds: 25 * 60),
            status: .partial,
            progress: 15.0 / 25.0,
            value: 15 * 60
        ),
        row(
            name: "Workout",
            icon: "dumbbell.fill",
            color: .purple,
            type: .binary,
            status: .none,
            progress: 0,
            value: nil
        ),
    ]

    static let mixed8: [HabitTimelineRow] = mixed5 + [
        row(
            name: "Stretch",
            icon: "figure.cooldown",
            color: .mint,
            type: .binary,
            status: .none,
            progress: 0,
            value: nil
        ),
        row(
            name: "Journal",
            icon: "square.and.pencil",
            color: .yellow,
            type: .binary,
            status: .none,
            progress: 0,
            value: nil
        ),
        row(
            name: "No snack",
            icon: "nosign",
            color: .red,
            type: .negative,
            status: .complete,
            progress: 1.0,
            value: 1
        ),
    ]

    private static func row(
        name: String,
        icon: String,
        color: HabitColor,
        type: HabitType,
        status: HabitRowState.Status,
        progress: Double,
        value: Double?
    ) -> HabitTimelineRow {
        HabitTimelineRow(
            id: UUID(),
            habit: Habit(
                id: UUID(),
                name: name,
                frequency: .daily,
                type: type,
                createdAt: .now,
                color: color,
                icon: icon
            ),
            state: HabitRowState(status: status, progress: progress, valueToday: value),
            streak: Int.random(in: 1...14),
            scorePercent: Int((progress * 100).rounded())
        )
    }
}
