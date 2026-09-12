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

        // Each later day is dated from its own `logicalDay`, never
        // relative to its neighbours, so a gap in the series costs
        // nothing and a day that isn't a midnight in this zone — a zone
        // change between write and read — costs only that day, rather
        // than landing on a neighbour's date.
        let calendar = boundary.calendar
        for day in series.days where day.logicalDay > current {
            guard calendar.startOfDay(for: day.logicalDay) == day.logicalDay else { continue }
            slots.append(Slot(date: boundary.rollover(into: day.logicalDay), snapshot: day))
        }

        let reloadAfter = calendar.date(byAdding: .hour, value: 1, to: now)
            ?? now.addingTimeInterval(3600)
        return WidgetTimelinePlan(slots: slots, reloadAfter: reloadAfter)
    }
}
