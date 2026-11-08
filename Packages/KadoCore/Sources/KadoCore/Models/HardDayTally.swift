import Foundation

/// How the days a yes/no habit was done over a period split between
/// full days and hard days (`HardDay`) — the "26 full days · 4 hard
/// days" line under the detail calendar.
///
/// Counts days, not records: a day holding more than one record (two
/// devices logging before a sync merges them) counts once, as full if
/// any of its records is.
nonisolated public struct HardDayTally: Equatable, Sendable {
    public let fullDays: Int
    public let hardDays: Int

    public init(fullDays: Int, hardDays: Int) {
        self.fullDays = fullDays
        self.hardDays = hardDays
    }

    public static func tally(
        habit: Habit,
        completions: [Completion],
        in interval: DateInterval,
        calendar: Calendar
    ) -> HardDayTally {
        guard habit.type == .binary else { return HardDayTally(fullDays: 0, hardDays: 0) }
        var bestByDay: [Date: Double] = [:]
        for completion in completions
        where completion.habitID == habit.id
            && completion.value > 0
            && completion.date >= interval.start
            && completion.date < interval.end {
            let day = calendar.startOfDay(for: completion.date)
            bestByDay[day] = max(bestByDay[day] ?? 0, completion.value)
        }
        let hardDays = bestByDay.values.filter { HardDay.isHardDay(value: $0, for: habit.type) }.count
        return HardDayTally(fullDays: bestByDay.count - hardDays, hardDays: hardDays)
    }
}
