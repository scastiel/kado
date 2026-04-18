import Foundation
import SwiftData
@preconcurrency import WidgetKit

/// Timeline provider shared by the small and medium home-screen
/// widgets. Parameterized by `limit` (number of on-screen rows)
/// so one type serves both widget sizes.
///
/// Cadence: emits a single entry for "now" and asks iOS to reload
/// at the top of the next hour. App-side mutations also call
/// `WidgetCenter.shared.reloadAllTimelines()` (Task 14) so
/// completion-state drift between the widget and the app is
/// bounded by a second or two, not an hour.
public struct HabitTimelineProvider: TimelineProvider, Sendable {
    public let limit: Int

    public init(limit: Int) {
        self.limit = limit
    }

    public func placeholder(in context: Context) -> HabitTimelineEntry {
        HabitTimelineEntry.placeholder(limit: limit)
    }

    public func getSnapshot(in context: Context, completion: @escaping @Sendable (HabitTimelineEntry) -> Void) {
        Task { @MainActor in
            completion((try? Self.buildEntry(asOf: .now, limit: limit)) ?? .placeholder(limit: limit))
        }
    }

    public func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<HabitTimelineEntry>) -> Void) {
        Task { @MainActor in
            let now = Date.now
            let entry = (try? Self.buildEntry(asOf: now, limit: limit)) ?? .placeholder(limit: limit)
            let nextRefresh = Calendar.current.date(byAdding: .hour, value: 1, to: now)
                ?? now.addingTimeInterval(3600)
            completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
        }
    }

    @MainActor
    private static func buildEntry(asOf reference: Date, limit: Int) throws -> HabitTimelineEntry {
        let container = try IntentContainerResolver.sharedContainer()
        return try HabitTimelineEntry.build(
            from: container.mainContext,
            asOf: reference,
            calendar: .current,
            frequencyEvaluator: DefaultFrequencyEvaluator(),
            scoreCalculator: DefaultHabitScoreCalculator(),
            streakCalculator: DefaultStreakCalculator(),
            limit: limit
        )
    }
}
