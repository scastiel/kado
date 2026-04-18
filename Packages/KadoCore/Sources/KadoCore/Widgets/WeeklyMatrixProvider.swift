import Foundation
import SwiftData
import WidgetKit

public struct WeeklyMatrixProvider: TimelineProvider {
    public func placeholder(in context: Context) -> WeeklyMatrixEntry {
        .placeholder()
    }

    public func getSnapshot(in context: Context, completion: @escaping @Sendable (WeeklyMatrixEntry) -> Void) {
        Task { @MainActor in
            completion((try? Self.buildEntry(asOf: .now)) ?? .placeholder())
        }
    }

    public func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<WeeklyMatrixEntry>) -> Void) {
        Task { @MainActor in
            let now = Date.now
            let entry = (try? Self.buildEntry(asOf: now)) ?? .placeholder()
            let nextRefresh = Calendar.current.date(byAdding: .hour, value: 1, to: now)
                ?? now.addingTimeInterval(3600)
            completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
        }
    }

    @MainActor
    private static func buildEntry(asOf reference: Date) throws -> WeeklyMatrixEntry {
        let container = try IntentContainerResolver.sharedContainer()
        return try WeeklyMatrixEntry.build(
            from: container.mainContext,
            asOf: reference,
            calendar: .current,
            frequencyEvaluator: DefaultFrequencyEvaluator()
        )
    }
}
