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
            DevModeSeed.seed(into: container.mainContext)
            return container
        } catch {
            fatalError("Failed to construct preview ModelContainer: \(error)")
        }
    }()

    /// In-memory container with no habits — exercises the empty state.
    static func emptyContainer() -> ModelContainer {
        do {
            return try ModelContainer(
                for: HabitRecord.self, CompletionRecord.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        } catch {
            fatalError("Failed to construct preview ModelContainer: \(error)")
        }
    }

    /// In-memory container with habits that exist but aren't due today —
    /// exercises the "nothing due today" state. Seeds one habit scheduled
    /// only on a weekday we know isn't today.
    static func noneDueTodayContainer() -> ModelContainer {
        do {
            let container = try ModelContainer(
                for: HabitRecord.self, CompletionRecord.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
            let calendar = Calendar.current
            let todayWeekdayInt = calendar.component(.weekday, from: .now)
            let offDays = Set(Weekday.allCases).filter { $0.rawValue != todayWeekdayInt }
            let habit = HabitRecord(
                name: "Weekend ritual",
                frequency: .specificDays(offDays),
                type: .binary,
                createdAt: calendar.date(byAdding: .day, value: -30, to: .now)!
            )
            container.mainContext.insert(habit)
            try? container.mainContext.save()
            return container
        } catch {
            fatalError("Failed to construct preview ModelContainer: \(error)")
        }
    }

}
