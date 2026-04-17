import Foundation

/// Habit kinds, each driving a different `value[n]` derivation in the
/// score calculator.
enum HabitType: Hashable, Codable, Sendable {
    case binary
    case counter(target: Double)
    case timer(targetSeconds: TimeInterval)
    case negative
}
