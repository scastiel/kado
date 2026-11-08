import Foundation

/// Per-day completion value for a habit, in `[0.0, 1.0]`. No smoothing
/// or history — just what happened on one specific day. Used by both
/// the habit-score calculator (as the EMA input) and the Overview
/// matrix (as the cell opacity source), so the two stay defined in
/// one place.
///
/// - Binary habits: 1 for a full day, `HardDay.value` for a hard day,
///   0 when nothing was logged.
/// - Negative habits: 0 or 1.
/// - Counter and timer habits: `achieved / target`, capped at 1.
public enum DailyValue {
    public static func compute(for habit: Habit, completionsOnDay: [Completion]) -> Double {
        let withValue = completionsOnDay.filter { $0.value > 0 }
        switch habit.type {
        case .binary:
            // The day's best record, so a hard day scores what it
            // recorded and a duplicate from a sync merge can't add up
            // past a full day.
            return min(1.0, withValue.map(\.value).max() ?? 0.0)
        case .counter(let target):
            guard target > 0 else { return 0.0 }
            let achieved = withValue.reduce(0.0) { $0 + $1.value }
            return min(1.0, achieved / target)
        case .timer(let targetSeconds):
            guard targetSeconds > 0 else { return 0.0 }
            let achievedSeconds = withValue.reduce(0.0) { $0 + $1.value }
            return min(1.0, achievedSeconds / targetSeconds)
        case .negative:
            return withValue.isEmpty ? 1.0 : 0.0
        }
    }
}
