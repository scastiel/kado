import Testing
import SwiftUI
@testable import Kado
import KadoCore

/// The haptic a quick-log control plays for a change of the day's
/// recorded value. One feedback per change: `.success` on the edge
/// where the target is met, `.selection` for every other tap — the
/// taps past the target that used to be silent (#81) included.
@Suite("QuickLogFeedback")
struct QuickLogFeedbackTests {

    private func feedback(_ old: Double, _ new: Double, target: Double = 8) -> SensoryFeedback? {
        QuickLogFeedback.feedback(oldValue: old, newValue: new, target: target)
    }

    @Test("An unchanged value plays nothing")
    func unchanged() {
        #expect(feedback(3, 3) == nil)
        #expect(feedback(0, 0) == nil)
        #expect(feedback(12, 12) == nil)
    }

    @Test("A step below the target is a selection tick")
    func belowToBelow() {
        #expect(feedback(3, 4) == .selection)
        #expect(feedback(0, 1) == .selection)
    }

    @Test("Reaching the target is a success")
    func belowToAt() {
        #expect(feedback(7, 8) == .success)
    }

    @Test("Jumping past the target in one step is still a success")
    func belowToPast() {
        #expect(feedback(7, 12) == .success)
    }

    @Test("A step from the target upward is a selection tick, not silence")
    func atToAbove() {
        #expect(feedback(8, 9) == .selection)
    }

    @Test("Every step past the target keeps ticking")
    func aboveToAbove() {
        #expect(feedback(11, 12) == .selection)
        #expect(feedback(12, 13) == .selection)
    }

    @Test("A decrement below the target is a selection tick")
    func decrementBelow() {
        #expect(feedback(4, 3) == .selection)
    }

    @Test("Stepping down off the target is a selection tick, never a success")
    func decrementOffTarget() {
        #expect(feedback(8, 7) == .selection)
        #expect(feedback(9, 8) == .selection)
    }

    @Test("A zero target is met by the first recorded value, as HabitRowState resolves it")
    func zeroTarget() {
        #expect(feedback(0, 1, target: 0) == .success)
        #expect(feedback(1, 2, target: 0) == .selection)
        #expect(feedback(1, 0, target: 0) == .selection)
    }

    // MARK: - QuickLogEvent

    @Test("Events are sequenced so identical consecutive steps still differ")
    func eventSequence() {
        let first = QuickLogEvent.next(after: nil, type: .counter(target: 8), oldValue: 3, newValue: 4)
        let second = QuickLogEvent.next(after: first, type: .counter(target: 8), oldValue: 3, newValue: 4)
        #expect(first?.sequence == 1)
        #expect(second?.sequence == 2)
        #expect(first != second)
        #expect(first?.feedback == .selection)
        #expect(second?.feedback == .selection)
    }

    @Test("An event carries the rule's feedback for the habit's own target")
    func eventFeedback() {
        let counter = QuickLogEvent.next(after: nil, type: .counter(target: 8), oldValue: 7, newValue: 8)
        #expect(counter?.feedback == .success)
        let timer = QuickLogEvent.next(after: nil, type: .timer(targetSeconds: 1800), oldValue: 1500, newValue: 1800)
        #expect(timer?.feedback == .success)
        let past = QuickLogEvent.next(after: nil, type: .timer(targetSeconds: 1800), oldValue: 1800, newValue: 2100)
        #expect(past?.feedback == .selection)
    }

    @Test("Binary and negative habits produce no event")
    func noEventForToggles() {
        #expect(QuickLogEvent.next(after: nil, type: .binary, oldValue: 0, newValue: 1) == nil)
        #expect(QuickLogEvent.next(after: nil, type: .negative, oldValue: 0, newValue: 1) == nil)
    }
}
