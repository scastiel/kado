import Foundation

/// What the App Group file holds: the day the app wrote it on, followed
/// by the days after it — each one computed as of that morning with
/// nothing further logged.
///
/// The widget cannot rebuild a snapshot (it never opens SwiftData) and
/// the app cannot be relied on to rebuild one at the boundary (asleep,
/// it never fires). But every calculator is a pure function of the data
/// and a reference day, so the app can compute tomorrow *today*, and the
/// day after, and hand WidgetKit one timeline entry per day. Whatever is
/// logged later rewrites the whole series, so a future day is never
/// stale relative to what the app knows.
public struct WidgetSnapshotSeries: Codable, Sendable {
    public let generatedAt: Date
    /// Ascending by `logicalDay`, consecutive, `days[0]` being the day
    /// the series was written on.
    public let days: [WidgetSnapshot]

    public init(generatedAt: Date, days: [WidgetSnapshot]) {
        self.generatedAt = generatedAt
        self.days = days
    }

    public static var empty: WidgetSnapshotSeries {
        WidgetSnapshotSeries(generatedAt: .now, days: [])
    }

    /// The snapshot that answers for `now`: the latest day not after
    /// the logical day `now` falls in.
    ///
    /// Past the horizon that is the last day we have — a "nothing
    /// logged" state that can be wrong about which habits are due, but
    /// can never show ticks from a day that is over. Before the first
    /// day (a clock set back) the first day answers. An empty series
    /// resolves to `.empty`, so a missing or unreadable file renders
    /// the same rest-day state it always has.
    public func snapshot(on now: Date, boundary: DayBoundary) -> WidgetSnapshot {
        let current = boundary.startOfDay(for: now)
        return days.last(where: { $0.logicalDay <= current })
            ?? days.first
            ?? .empty
    }
}
