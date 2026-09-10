import Foundation
import Testing
import KadoCore

/// The one all-done rule. Three surfaces read it — the confetti, the
/// review-prompt milestone and the lock-screen ring — so it is pinned
/// here rather than re-derived in each.
@Suite("DayProgress")
struct DayProgressTests {

    @Test("0/0 is not complete — a day with nothing scheduled is not a finished day")
    func emptyDayIsNotComplete() {
        #expect(!DayProgress(completed: 0, total: 0).isComplete)
        #expect(!DayProgress.empty.isComplete)
    }

    @Test("3/3 is complete")
    func fullDayIsComplete() {
        #expect(DayProgress(completed: 3, total: 3).isComplete)
    }

    @Test("2/3 is not complete")
    func partialDayIsNotComplete() {
        #expect(!DayProgress(completed: 2, total: 3).isComplete)
    }

    @Test("fraction is 0 for an empty day and clamps to 1")
    func fractionClamps() {
        #expect(DayProgress.empty.fraction == 0.0)
        #expect(DayProgress(completed: 1, total: 4).fraction == 0.25)
        // Off-schedule logging can count more completions than the
        // schedule asked for; the ring must not overshoot.
        #expect(DayProgress(completed: 5, total: 4).fraction == 1.0)
    }

    @Test("WidgetSnapshot.dayProgress mirrors its counts")
    func snapshotMirror() {
        let snapshot = WidgetSnapshot(
            generatedAt: .now,
            habits: [],
            today: [],
            totalDueToday: 5,
            completedToday: 2,
            matrix: [],
            matrixDays: []
        )
        #expect(snapshot.dayProgress == DayProgress(completed: 2, total: 5))
        #expect(WidgetSnapshot.empty.dayProgress == .empty)
    }
}
