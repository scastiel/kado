import Foundation

/// Per-day completion value for a habit, in `[0.0, 1.0]`. No smoothing
/// or history — just what happened on one specific day. Used by both
/// the habit-score calculator (as the EMA input) and the Overview
/// matrix (as the cell opacity source), so the two stay defined in
/// one place.
///
/// - Binary and negative habits: 0 or 1.
/// - Counter and timer habits: `achieved / target`, capped at 1.
enum DailyValue {
    static func compute(for habit: Habit, completionsOnDay: [Completion]) -> Double {
        switch habit.type {
        case .binary:
            return completionsOnDay.isEmpty ? 0.0 : 1.0
        case .counter(let target):
            guard target > 0 else { return 0.0 }
            let achieved = completionsOnDay.reduce(0.0) { $0 + $1.value }
            return min(1.0, achieved / target)
        case .timer(let targetSeconds):
            guard targetSeconds > 0 else { return 0.0 }
            let achievedSeconds = completionsOnDay.reduce(0.0) { $0 + $1.value }
            return min(1.0, achievedSeconds / targetSeconds)
        case .negative:
            return completionsOnDay.isEmpty ? 1.0 : 0.0
        }
    }
}
