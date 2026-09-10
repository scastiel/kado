import Foundation

/// How far today has come: habits done against habits the schedule
/// asked for (or that were logged anyway — the Today tab's
/// `isDueOrLogged` rule). "Done" is `HabitRowState.isDone(for:)`,
/// which is where a negative habit counts as done *until* it slips.
///
/// The one home for "the day is done". The confetti, the review-prompt
/// milestone and the lock-screen ring all read `isComplete` from here
/// rather than each deciding what a finished day is — and in
/// particular all three agree that a day with *nothing* scheduled is
/// not a finished one, which `allSatisfy` on an empty list would
/// happily claim.
nonisolated public struct DayProgress: Hashable, Sendable {
    public let completed: Int
    public let total: Int

    public init(completed: Int, total: Int) {
        self.completed = completed
        self.total = total
    }

    public static let empty = DayProgress(completed: 0, total: 0)

    /// `true` only when there was something to do and all of it is
    /// done.
    public var isComplete: Bool {
        total > 0 && completed >= total
    }

    /// 0…1, for a gauge. Zero when nothing is scheduled; clamped so an
    /// off-schedule completion counted past the quota can't overshoot
    /// the ring.
    public var fraction: Double {
        guard total > 0 else { return 0 }
        return min(1, Double(completed) / Double(total))
    }
}
