import Foundation
import SwiftData

/// In-memory `ModelContainer` seeded with a small, realistic habit
/// set covering each `Frequency` and `HabitType` variant. Use from
/// SwiftUI previews via `.modelContainer(PreviewContainer.shared)`.
///
/// Lives in `Preview Content/` so it ships only with Debug builds.
@MainActor
enum PreviewContainer {
    static let shared: ModelContainer = {
        do {
            let container = try ModelContainer(
                for: HabitRecord.self, CompletionRecord.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
            seed(container.mainContext)
            return container
        } catch {
            fatalError("Failed to construct preview ModelContainer: \(error)")
        }
    }()

    static func seed(_ context: ModelContext) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        let habits: [HabitRecord] = [
            HabitRecord(
                name: "Morning meditation",
                frequency: .daily,
                type: .binary,
                createdAt: calendar.date(byAdding: .day, value: -45, to: today)!
            ),
            HabitRecord(
                name: "Gym",
                frequency: .specificDays([.monday, .wednesday, .friday]),
                type: .binary,
                createdAt: calendar.date(byAdding: .day, value: -60, to: today)!
            ),
            HabitRecord(
                name: "Drink water",
                frequency: .daily,
                type: .counter(target: 8),
                createdAt: calendar.date(byAdding: .day, value: -30, to: today)!
            ),
            HabitRecord(
                name: "Read",
                frequency: .daily,
                type: .timer(targetSeconds: 1800),
                createdAt: calendar.date(byAdding: .day, value: -20, to: today)!
            ),
            HabitRecord(
                name: "No social media",
                frequency: .daily,
                type: .negative,
                createdAt: calendar.date(byAdding: .day, value: -14, to: today)!
            ),
        ]

        for habit in habits {
            context.insert(habit)
            for daysAgo in stride(from: 1, through: 14, by: 2) {
                let date = calendar.date(byAdding: .day, value: -daysAgo, to: today)!
                let value: Double = switch habit.type {
                case .counter: 6
                case .timer: 1500
                default: 1
                }
                let completion = CompletionRecord(date: date, value: value, habit: habit)
                context.insert(completion)
            }
        }

        try? context.save()
    }
}
