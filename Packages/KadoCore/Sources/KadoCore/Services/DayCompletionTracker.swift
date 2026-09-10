import Foundation

/// Spots the moment a day becomes complete.
///
/// Fed one `DayProgress` per snapshot rebuild — which is to say after
/// every mutation, from every surface — and answers whether *that*
/// observation is the edge worth celebrating. The rule is deliberately
/// narrow: the previous observation was for the **same logical day**
/// and **not complete**, and this one is. Everything else is a
/// baseline:
///
/// - The first observation (launching into a finished day is not the
///   moment it was finished).
/// - A change of logical day (the day-edge task reports the fresh day
///   as its own baseline; moving the day-start hour can relabel the
///   current day as a finished yesterday — a setting, not a tick).
/// - Anything after `reset()` (a dev-mode swap lands on a different
///   store's day).
///
/// A day that dips back to incomplete and is completed again fires
/// again: un-ticking and re-ticking is the user's own doing, and a
/// habit added after the first celebration deserves a second one when
/// it, too, is done.
nonisolated public struct DayCompletionTracker: Hashable, Sendable {
    private struct Observation: Hashable, Sendable {
        let day: Date
        let isComplete: Bool
    }

    private var last: Observation?

    public init() {}

    /// Records today's progress. Returns `true` exactly when this
    /// observation turned the day from not complete to complete.
    ///
    /// `day` is the logical day's anchor — what
    /// `DayBoundary.startOfDay(for:)` returns — so two reports for the
    /// same day carry the same instant and compare with `==`.
    public mutating func record(_ progress: DayProgress, on day: Date) -> Bool {
        let now = Observation(day: day, isComplete: progress.isComplete)
        defer { last = now }
        guard let last, last.day == now.day else { return false }
        return !last.isComplete && now.isComplete
    }

    /// Forgets the previous observation, so the next one is a
    /// baseline.
    public mutating func reset() {
        last = nil
    }
}
