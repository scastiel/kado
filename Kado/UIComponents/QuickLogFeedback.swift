import SwiftUI
import KadoCore

/// The haptic a quick-log mutation plays when it moves the day's
/// recorded value. One rule for every stepper and chip — the Today
/// row, the detail quick-log, the calendar day popover — so a tap
/// feels the same wherever it lands.
///
/// Exactly one feedback per change:
/// - `.success` when the change carries the value from not-done to
///   done — the moment the target is met. "Done" is the same rule as
///   `HabitRowState`: at or above a positive target, anything above
///   zero when the target isn't positive.
/// - `.selection` for every other change: each step below the target,
///   each step past it, each decrement. This is the tick that was
///   missing past the target (#81), where the ring is already full
///   and there was nothing left to tell the user the tap registered.
/// - `nil` when the value didn't move.
///
/// `.selection`, not `.increase` / `.decrease`: those two compile on
/// iOS and never play — Apple's docs for both read *"Only plays
/// feedback on watchOS and visionOS."* `.selection` is the iOS kind
/// for movement through discrete values.
///
/// Apply at the **mutation site**, not on the control: the view that
/// saves records a `QuickLogEvent` and a stable ancestor carries
/// `.quickLogFeedback(_:)`. Keying a control on the value it displays
/// ticks for changes the user didn't make (a day rollover zeroes every
/// row at once, a CloudKit sync, a container swap) and misses the tap
/// that re-creates the control (a row moving between Today's sections).
nonisolated enum QuickLogFeedback {
    static func feedback(oldValue: Double, newValue: Double, target: Double) -> SensoryFeedback? {
        guard newValue != oldValue else { return nil }
        if !meets(oldValue, target: target) && meets(newValue, target: target) {
            return .success
        }
        return .selection
    }

    /// Mirrors `HabitRowState.resolveAgainstTarget`: a non-positive
    /// target is met by any recorded value.
    private static func meets(_ value: Double, target: Double) -> Bool {
        target > 0 ? value >= target : value > 0
    }
}

/// One quick-log mutation, as the haptic sees it. The view that
/// performed the mutation keeps the latest event in `@State`; the
/// `sequence` makes two identical consecutive steps distinct, so the
/// trigger still fires.
nonisolated struct QuickLogEvent: Equatable, Sendable {
    let sequence: Int
    let feedback: SensoryFeedback?

    /// The event for a mutation that moved a habit's day value
    /// `oldValue → newValue`, sequenced after `previous`. `nil` for
    /// binary and negative habits — a toggle has no step to tick.
    static func next(
        after previous: QuickLogEvent?,
        type: HabitType,
        oldValue: Double,
        newValue: Double
    ) -> QuickLogEvent? {
        let target: Double
        switch type {
        case .counter(let count):
            target = count
        case .timer(let seconds):
            target = seconds
        case .binary, .negative:
            return nil
        }
        return QuickLogEvent(
            sequence: (previous?.sequence ?? 0) + 1,
            feedback: QuickLogFeedback.feedback(oldValue: oldValue, newValue: newValue, target: target)
        )
    }
}

extension View {
    /// Plays the haptic for the latest quick-log mutation. Put it on an
    /// ancestor whose identity never changes — the Today `List`, the
    /// detail `ScrollView` — so a tap that re-creates the row it landed
    /// on still ticks, and nothing but a tap does.
    func quickLogFeedback(_ event: QuickLogEvent?) -> some View {
        sensoryFeedback(trigger: event) { _, new in new?.feedback }
    }
}
