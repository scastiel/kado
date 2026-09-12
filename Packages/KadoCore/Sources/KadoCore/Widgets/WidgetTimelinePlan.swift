import Foundation

/// The entries a widget hands WidgetKit, planned from the series on
/// disk: the current day at `now`, then one slot per pre-computed day
/// after it, dated at the instant that day begins. WidgetKit turns the
/// page at each date in its own render server, so the widget rolls
/// over at the boundary with neither the app nor the extension awake —
/// the reload iOS may throttle is no longer what the rollover rides on.
///
/// Both providers map this into their own entry type; the planning
/// itself imports nothing from WidgetKit so it can be pinned in the
/// unit suite, DST edges included.
public struct WidgetTimelinePlan: Sendable {
    public struct Slot: Sendable {
        public let date: Date
        public let snapshot: WidgetSnapshot
    }

    /// Never empty; `slots[0].date == now`.
    public let slots: [Slot]

    /// When to ask for a fresh plan: the hourly reload the providers
    /// always had, kept as the safety net for a write that reached the
    /// file without a `reloadAllTimelines` alongside it.
    public let reloadAfter: Date

    public static func make(
        series: WidgetSnapshotSeries,
        now: Date = .now,
        boundary: DayBoundary = DayStartDefaults.boundary()
    ) -> WidgetTimelinePlan {
        let current = boundary.startOfDay(for: now)
        var slots = [Slot(date: now, snapshot: series.snapshot(on: now, boundary: boundary))]

        // The series is consecutive, so each day after the current one
        // begins at the next rollover. A day that does not line up with
        // its edge — a zone change between write and read — is left
        // out rather than shown on the wrong date.
        var edge = boundary.nextRollover(after: now)
        for day in series.days where day.logicalDay > current {
            guard boundary.startOfDay(for: edge) == day.logicalDay else { continue }
            slots.append(Slot(date: edge, snapshot: day))
            edge = boundary.nextRollover(after: edge)
        }

        let calendar = boundary.calendar
        let reloadAfter = calendar.date(byAdding: .hour, value: 1, to: now)
            ?? now.addingTimeInterval(3600)
        return WidgetTimelinePlan(slots: slots, reloadAfter: reloadAfter)
    }
}
