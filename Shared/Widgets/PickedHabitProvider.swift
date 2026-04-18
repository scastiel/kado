import AppIntents
import Foundation
import SwiftData
import WidgetKit

/// Timeline provider for the lock-screen widgets that render one
/// habit picked via `PickHabitIntent`.
struct PickedHabitProvider: AppIntentTimelineProvider {
    typealias Intent = PickHabitIntent
    typealias Entry = PickedHabitEntry

    func placeholder(in context: Context) -> PickedHabitEntry {
        .empty()
    }

    func snapshot(for configuration: PickHabitIntent, in context: Context) async -> PickedHabitEntry {
        await MainActor.run {
            (try? Self.buildEntry(for: configuration.habit?.id, asOf: .now)) ?? .empty()
        }
    }

    func timeline(for configuration: PickHabitIntent, in context: Context) async -> Timeline<PickedHabitEntry> {
        await MainActor.run {
            let now = Date.now
            let entry = (try? Self.buildEntry(for: configuration.habit?.id, asOf: now)) ?? .empty(asOf: now)
            let nextRefresh = Calendar.current.date(byAdding: .hour, value: 1, to: now)
                ?? now.addingTimeInterval(3600)
            return Timeline(entries: [entry], policy: .after(nextRefresh))
        }
    }

    @MainActor
    private static func buildEntry(for habitID: UUID?, asOf reference: Date) throws -> PickedHabitEntry {
        let container = try IntentContainerResolver.sharedContainer()
        return try PickedHabitEntry.build(
            for: habitID,
            from: container.mainContext,
            asOf: reference,
            calendar: .current,
            scoreCalculator: DefaultHabitScoreCalculator(),
            streakCalculator: DefaultStreakCalculator()
        )
    }
}
