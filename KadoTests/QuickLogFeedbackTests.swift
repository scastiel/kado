import Testing
import SwiftUI
@testable import Kado

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

    @Test("A zero target never reports a success edge")
    func zeroTarget() {
        #expect(feedback(0, 1, target: 0) == .selection)
        #expect(feedback(1, 2, target: 0) == .selection)
    }
}
