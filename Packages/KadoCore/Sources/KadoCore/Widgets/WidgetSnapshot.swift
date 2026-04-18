import Foundation

/// The data the widget extension reads. Two SwiftData processes
/// can't both attach CloudKit to the same store, so widgets stop
/// using SwiftData altogether. The main app builds this snapshot
/// after every mutation and writes it as JSON into the App Group;
/// widgets just decode it.
public struct WidgetSnapshot: Codable, Sendable {
    public let generatedAt: Date
    public let habits: [WidgetHabit]
    public let today: [WidgetTodayRow]
    public let totalDueToday: Int
    public let completedToday: Int
    public let matrix: [WidgetMatrixRow]
    public let matrixDays: [Date]

    public init(
        generatedAt: Date,
        habits: [WidgetHabit],
        today: [WidgetTodayRow],
        totalDueToday: Int,
        completedToday: Int,
        matrix: [WidgetMatrixRow],
        matrixDays: [Date]
    ) {
        self.generatedAt = generatedAt
        self.habits = habits
        self.today = today
        self.totalDueToday = totalDueToday
        self.completedToday = completedToday
        self.matrix = matrix
        self.matrixDays = matrixDays
    }

    public static var empty: WidgetSnapshot {
        WidgetSnapshot(
            generatedAt: .now,
            habits: [],
            today: [],
            totalDueToday: 0,
            completedToday: 0,
            matrix: [],
            matrixDays: []
        )
    }
}

/// Minimum representation of a habit the widgets need. Carries
/// type + target so the widget cell can render counter/timer
/// progress without round-tripping through `HabitType`.
public struct WidgetHabit: Codable, Sendable, Identifiable, Hashable {
    public let id: UUID
    public let name: String
    public let color: HabitColor
    public let icon: String
    public let typeKind: WidgetHabitTypeKind
    public let target: Double?

    public init(
        id: UUID,
        name: String,
        color: HabitColor,
        icon: String,
        typeKind: WidgetHabitTypeKind,
        target: Double?
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.icon = icon
        self.typeKind = typeKind
        self.target = target
    }
}

public enum WidgetHabitTypeKind: String, Codable, Sendable {
    case binary
    case negative
    case counter
    case timer
}

public enum WidgetStatus: String, Codable, Sendable {
    case none
    case partial
    case complete
}

/// One habit row for the today-focused widgets. Score + streak
/// pre-computed app-side; widget just renders.
public struct WidgetTodayRow: Codable, Sendable, Identifiable, Hashable {
    public var id: UUID { habit.id }
    public let habit: WidgetHabit
    public let status: WidgetStatus
    public let progress: Double
    public let valueToday: Double?
    public let streak: Int
    public let scorePercent: Int

    public init(
        habit: WidgetHabit,
        status: WidgetStatus,
        progress: Double,
        valueToday: Double?,
        streak: Int,
        scorePercent: Int
    ) {
        self.habit = habit
        self.status = status
        self.progress = progress
        self.valueToday = valueToday
        self.streak = streak
        self.scorePercent = scorePercent
    }
}

/// One row of the weekly matrix. Cells carry the raw daily value
/// so the widget can apply the same opacity curve the main app's
/// Overview tab uses.
public struct WidgetMatrixRow: Codable, Sendable, Hashable {
    public let habit: WidgetHabit
    public let cells: [WidgetDayCell]

    public init(habit: WidgetHabit, cells: [WidgetDayCell]) {
        self.habit = habit
        self.cells = cells
    }
}

public enum WidgetDayCell: Codable, Sendable, Hashable {
    case future
    case notDue
    case scored(Double)

    /// Same linear remap the main app's `DayCell.colorOpacity`
    /// uses. Copied rather than reused so widgets don't depend on
    /// `DayCell` (which conflicts with `OverviewMatrix` internals).
    public var colorOpacity: Double? {
        switch self {
        case .future, .notDue:
            return nil
        case .scored(let s):
            let clamped = max(0.0, min(1.0, s))
            return 0.2 + 0.8 * clamped
        }
    }
}
