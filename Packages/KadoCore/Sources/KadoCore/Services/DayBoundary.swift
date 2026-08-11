import Foundation

/// Resolves which **logical day** an instant belongs to, once the user
/// has moved the day's rollover off midnight ("Day starts at" in
/// Settings).
///
/// Someone who logs habits at 1am still thinks of that hour as
/// yesterday. Setting `startHour` to 4 means the logical day runs
/// `[04:00, next 04:00)` instead of `[00:00, next 00:00)`, so Today
/// keeps showing the previous day — and its one-tap rows — until the
/// user is actually asleep.
///
/// ## Where this gets applied
///
/// Wall-clock time enters the domain in exactly two shapes, and this
/// type is applied at both:
///
/// - **Reading** — the reference date handed to the calculators
///   (`asOf:` / `on:` / `today:`). Use ``startOfDay(for:)``.
/// - **Writing** — the date stamped on a new `CompletionRecord`.
///   Use ``loggingInstant(for:)``.
///
/// Everything downstream (`DefaultHabitScoreCalculator`,
/// `DefaultStreakCalculator`, `DefaultFrequencyEvaluator`,
/// `OverviewMatrix`) keeps bucketing by
/// `calendar.startOfDay(for: completion.date)` and needs no knowledge
/// of the boundary at all.
///
/// ## Why normalise on write
///
/// Because the day is fixed when the record is created, changing the
/// setting later cannot move anything already logged. Bucketing on
/// *read* instead would silently rewrite history the moment the user
/// touched the picker — a completion logged at 01:00 would jump to the
/// previous day. See `docs/plans/2026-08/day-start-hour/`.
///
/// A `startHour` of `0` makes every method an exact no-op, which is
/// what keeps the default behaviour of the app unchanged.
nonisolated public struct DayBoundary: Equatable, Sendable {
    /// Calendar used for all day arithmetic. Injected so tests can pin
    /// to UTC for determinism and to a DST-crossing zone for boundary
    /// behaviour.
    public let calendar: Calendar

    /// Hour at which the day rolls over, `0...23`. Values outside that
    /// range are clamped rather than trapping — this is read from
    /// `UserDefaults`, which any process can write.
    public let startHour: Int

    public init(calendar: Calendar = .current, startHour: Int = 0) {
        self.calendar = calendar
        self.startHour = min(max(startHour, 0), 23)
    }

    /// Midnight of the logical day containing `date`.
    ///
    /// Returns a *calendar* midnight, not the rollover instant, so the
    /// result drops straight into the existing `startOfDay`-keyed
    /// bucketing without translating anything.
    public func startOfDay(for date: Date) -> Date {
        let midnight = calendar.startOfDay(for: date)
        guard startHour > 0 else { return midnight }
        guard let rollover = rolloverInstant(onDayStartingAt: midnight) else { return midnight }
        guard date < rollover else { return midnight }
        return calendar.date(byAdding: .day, value: -1, to: midnight) ?? midnight
    }

    /// Whether two instants fall in the same logical day.
    public func isDate(_ date: Date, inSameDayAs other: Date) -> Bool {
        startOfDay(for: date) == startOfDay(for: other)
    }

    /// The instant to stamp on a record being logged at `date`.
    ///
    /// Keeps the wall-clock time and moves only the calendar date, so
    /// a tap at 02:15 on the 11th stores `10th 02:15`. That lands the
    /// record in the logical day the user is looking at while leaving
    /// the time of day meaningful.
    ///
    /// Shifting a day back can land on a clock time that doesn't exist
    /// (02:15 on a spring-forward day). `Calendar` adjusts it, and the
    /// *day* — the only part anything downstream reads — stays right.
    public func loggingInstant(for date: Date) -> Date {
        let logicalDay = startOfDay(for: date)
        guard logicalDay != calendar.startOfDay(for: date) else { return date }
        return calendar.date(byAdding: .day, value: -1, to: date) ?? logicalDay
    }

    /// When the logical day containing `date` ends and the next one
    /// begins. Drives the in-app rollover tick and the "still
    /// yesterday" caption on Today.
    public func nextRollover(after date: Date) -> Date {
        let logicalDay = startOfDay(for: date)
        let nextMidnight = calendar.date(byAdding: .day, value: 1, to: logicalDay) ?? logicalDay
        return rolloverInstant(onDayStartingAt: nextMidnight) ?? nextMidnight
    }

    // MARK: - Internals

    /// The wall-clock rollover instant on the calendar day starting at
    /// `midnight`.
    ///
    /// Uses `date(bySettingHour:)` rather than adding hours: on a
    /// spring-forward day, adding `startHour` hours to midnight
    /// overshoots by the skipped hour, whereas searching for the wall
    /// clock reading lands on the right time — and, when that reading
    /// doesn't exist at all (02:00 on 2026-03-29 in Paris),
    /// `.nextTime` falls forward to the first instant that does.
    private func rolloverInstant(onDayStartingAt midnight: Date) -> Date? {
        calendar.date(
            bySettingHour: startHour,
            minute: 0,
            second: 0,
            of: midnight,
            matchingPolicy: .nextTime,
            repeatedTimePolicy: .first,
            direction: .forward
        )
    }
}
