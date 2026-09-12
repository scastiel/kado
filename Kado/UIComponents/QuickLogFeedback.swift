import SwiftUI

/// The haptic a quick-log control plays when the day's recorded value
/// changes. One rule for every stepper and chip — the Today row, the
/// detail quick-log, the calendar day popover — so a tap feels the same
/// wherever it lands.
///
/// Exactly one feedback per change:
/// - `.success` when the change carries the value from below the
///   target to at or above it — the moment the day is done.
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
/// Apply through `sensoryFeedback(trigger:) { old, new in … }` on the
/// value the control reads, so it also fires for VoiceOver rotor
/// actions that drive the same state.
nonisolated enum QuickLogFeedback {
    static func feedback(oldValue: Double, newValue: Double, target: Double) -> SensoryFeedback? {
        guard newValue != oldValue else { return nil }
        if oldValue < target && newValue >= target {
            return .success
        }
        return .selection
    }
}
