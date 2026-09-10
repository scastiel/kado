import Foundation
import Testing
import KadoCore

/// The edge the confetti fires on. Every completion path in the app
/// reports today's progress here after saving; the tracker answers
/// "was that the moment the day became complete?" — and only that
/// moment, never a launch, never a change of day, never a swap of
/// store.
///
/// Each `record` result is bound to a constant before `#expect`: the
/// macro captures its operands, and a mutating call on a captured
/// `var` does not compile.
@Suite("DayCompletionTracker")
struct DayCompletionTrackerTests {
    private let calendar = TestCalendar.utc

    /// 2026-03-11 and the day after, as logical-day anchors.
    private var wednesday: Date {
        calendar.date(from: DateComponents(year: 2026, month: 3, day: 11))!
    }

    private var thursday: Date {
        calendar.date(byAdding: .day, value: 1, to: wednesday)!
    }

    private let done = DayProgress(completed: 3, total: 3)
    private let almost = DayProgress(completed: 2, total: 3)

    @Test("First observation is a baseline and never fires")
    func firstObservationIsBaseline() {
        var tracker = DayCompletionTracker()
        // Launching into an already-finished day is not the moment it
        // was finished.
        let fired = tracker.record(done, on: wednesday)
        #expect(!fired)
    }

    @Test("Same day, incomplete then complete fires once")
    func sameDayEdgeFires() {
        var tracker = DayCompletionTracker()
        let baseline = tracker.record(almost, on: wednesday)
        let edge = tracker.record(done, on: wednesday)
        #expect(!baseline)
        #expect(edge)
    }

    @Test("Staying complete does not fire again")
    func stayingCompleteIsQuiet() {
        var tracker = DayCompletionTracker()
        _ = tracker.record(almost, on: wednesday)
        _ = tracker.record(done, on: wednesday)
        // Reordering rows, editing a note, archiving something not due
        // — all rebuild the snapshot with the day still complete.
        let again = tracker.record(done, on: wednesday)
        #expect(!again)
    }

    @Test("Dipping and completing again fires again")
    func dipAndRecoverFiresAgain() {
        var tracker = DayCompletionTracker()
        _ = tracker.record(almost, on: wednesday)
        _ = tracker.record(done, on: wednesday)
        let dip = tracker.record(almost, on: wednesday)
        let recover = tracker.record(done, on: wednesday)
        #expect(!dip)
        #expect(recover)
    }

    @Test("A new day is a baseline even when already complete")
    func newDayIsBaseline() {
        var tracker = DayCompletionTracker()
        _ = tracker.record(almost, on: wednesday)
        // Moving the day-start hour can relabel the current day as a
        // finished yesterday. That is a setting change, not a
        // completion.
        let relabelled = tracker.record(done, on: thursday)
        #expect(!relabelled)
    }

    @Test("After the new-day baseline, completing fires")
    func completingAfterRolloverFires() {
        var tracker = DayCompletionTracker()
        _ = tracker.record(done, on: wednesday)
        // The app's day-edge task reports the fresh day first…
        let rollover = tracker.record(DayProgress(completed: 0, total: 1), on: thursday)
        // …so the first tick of Thursday is Thursday's moment, not a
        // repeat of Wednesday's.
        let firstTick = tracker.record(DayProgress(completed: 1, total: 1), on: thursday)
        #expect(!rollover)
        #expect(firstTick)
    }

    @Test("reset() forgets the previous observation")
    func resetForgets() {
        var tracker = DayCompletionTracker()
        _ = tracker.record(almost, on: wednesday)
        tracker.reset()
        // A dev-mode swap lands on a different store's day; its first
        // report must not be compared with the old store's.
        let afterReset = tracker.record(done, on: wednesday)
        #expect(!afterReset)
    }

    @Test("An empty day never fires")
    func emptyDayNeverFires() {
        var tracker = DayCompletionTracker()
        _ = tracker.record(DayProgress(completed: 0, total: 1), on: wednesday)
        // Archiving the only due habit leaves 0/0 — nothing to
        // celebrate.
        let archived = tracker.record(.empty, on: wednesday)
        let still = tracker.record(.empty, on: wednesday)
        #expect(!archived)
        #expect(!still)
    }
}
