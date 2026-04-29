import Foundation

/// Derived presentation state for a single Today-tab row. Pure value,
/// resolved from a `Habit` plus its completions, the calendar, and a
/// reference date. Tests target `resolve(...)` directly so the row
/// renderer can stay logic-free.
///
/// `progress` is clamped to `0...1` for the progress ring; `valueToday`
/// preserves the raw recorded value (which may exceed the target for
/// counter / timer overshoot).
nonisolated public struct HabitRowState: Equatable, Sendable {
    public enum Status: Equatable, Sendable {
        case none
        case partial
        case complete
    }

    public let status: Status
    public let progress: Double
    public let valueToday: Double?

    public init(status: Status, progress: Double, valueToday: Double?) {
        self.status = status
        self.progress = progress
        self.valueToday = valueToday
    }

    public static func resolve(
        habit: Habit,
        completions: [Completion],
        calendar: Calendar,
        asOf reference: Date
    ) -> HabitRowState {
        let todays = completions.first {
            $0.value > 0 && calendar.isDate($0.date, inSameDayAs: reference)
        }

        guard let todays else {
            return HabitRowState(status: .none, progress: 0, valueToday: nil)
        }

        switch habit.type {
        case .binary, .negative:
            return HabitRowState(status: .complete, progress: 1, valueToday: todays.value)

        case .counter(let target):
            return resolveAgainstTarget(value: todays.value, target: target)

        case .timer(let targetSeconds):
            return resolveAgainstTarget(value: todays.value, target: targetSeconds)
        }
    }

    private static func resolveAgainstTarget(value: Double, target: Double) -> HabitRowState {
        guard target > 0 else {
            return HabitRowState(status: .complete, progress: 1, valueToday: value)
        }
        let clamped = min(value / target, 1)
        let status: Status = value >= target ? .complete : .partial
        return HabitRowState(status: status, progress: clamped, valueToday: value)
    }
}
