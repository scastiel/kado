import Foundation

/// One logical day as the widgets render it. Two SwiftData processes
/// can't both attach CloudKit to the same store, so widgets stop
/// using SwiftData altogether. The main app builds this after every
/// mutation and writes it as JSON into the App Group; widgets just
/// decode it.
///
/// A snapshot describes exactly one day — `today`, the counts and the
/// matrix are all "as of `logicalDay`". The file on disk is a
/// `WidgetSnapshotSeries`: this day and the ones after it, each
/// computed as if nothing further were logged, so the widget can turn
/// the page at the day boundary without either process being awake.
public struct WidgetSnapshot: Codable, Sendable {
    public let generatedAt: Date
    /// Midnight of the day this snapshot describes — the logical day
    /// under the user's "Day starts at" hour, so under a 4 AM start
    /// a snapshot built at 02:00 names the previous calendar day.
    public let logicalDay: Date
    public let habits: [WidgetHabit]
    public let today: [WidgetTodayRow]
    public let totalDueToday: Int
    public let completedToday: Int
    public let matrix: [WidgetMatrixRow]
    public let matrixDays: [Date]

    /// `logicalDay` defaults to the trailing matrix day, which the
    /// builder already anchors to the logical day — one fewer thing
    /// for previews and tests to spell out.
    public init(
        generatedAt: Date,
        habits: [WidgetHabit],
        today: [WidgetTodayRow],
        totalDueToday: Int,
        completedToday: Int,
        matrix: [WidgetMatrixRow],
        matrixDays: [Date],
        logicalDay: Date? = nil
    ) {
        self.generatedAt = generatedAt
        self.habits = habits
        self.today = today
        self.totalDueToday = totalDueToday
        self.completedToday = completedToday
        self.matrix = matrix
        self.matrixDays = matrixDays
        self.logicalDay = logicalDay
            ?? Self.impliedLogicalDay(matrixDays: matrixDays, generatedAt: generatedAt)
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

    /// The calendar a decoder falls back on for a legacy file's
    /// `logicalDay` when it has no matrix days to anchor on, passed in
    /// `Decoder.userInfo`. `WidgetSnapshotStore.decode` sets it; without
    /// it the device calendar is used.
    public static let calendarUserInfoKey = CodingUserInfoKey(rawValue: "dev.scastiel.kado.calendar")!

    // Backward-compatible decoding: a file written before the series
    // existed carries no `logicalDay`. Its trailing matrix day *is*
    // the logical day it was built for (the builder has always ended
    // the window there), so the fallback loses nothing.
    private enum CodingKeys: String, CodingKey {
        case generatedAt, logicalDay, habits, today
        case totalDueToday, completedToday, matrix, matrixDays
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.generatedAt = try c.decode(Date.self, forKey: .generatedAt)
        self.habits = try c.decode([WidgetHabit].self, forKey: .habits)
        self.today = try c.decode([WidgetTodayRow].self, forKey: .today)
        self.totalDueToday = try c.decode(Int.self, forKey: .totalDueToday)
        self.completedToday = try c.decode(Int.self, forKey: .completedToday)
        self.matrix = try c.decode([WidgetMatrixRow].self, forKey: .matrix)
        self.matrixDays = try c.decode([Date].self, forKey: .matrixDays)
        let calendar = decoder.userInfo[Self.calendarUserInfoKey] as? Calendar ?? .current
        self.logicalDay = try c.decodeIfPresent(Date.self, forKey: .logicalDay)
            ?? Self.impliedLogicalDay(matrixDays: matrixDays, generatedAt: generatedAt, calendar: calendar)
    }

    private static func impliedLogicalDay(
        matrixDays: [Date],
        generatedAt: Date,
        calendar: Calendar = .current
    ) -> Date {
        matrixDays.last ?? calendar.startOfDay(for: generatedAt)
    }

    /// The two counts as one value, so the lock-screen ring and the
    /// day-complete celebration read the same "is the day done" rule.
    /// Derived, not stored: the JSON on disk keeps its shape.
    public var dayProgress: DayProgress {
        DayProgress(completed: completedToday, total: totalDueToday)
    }
}

/// Minimum representation of a habit the widgets need. Carries
/// type + target so the widget cell can render counter/timer
/// progress without round-tripping through `HabitType`.
///
/// `currentStreak`, `bestStreak`, and `currentScore` are populated
/// for the top-level `WidgetSnapshot.habits` array so
/// `GetHabitStatsIntent` can read per-habit stats without touching
/// SwiftData. The same values are replicated into the nested
/// habits inside `today` and `matrix` rows for consistency.
public struct WidgetHabit: Codable, Sendable, Identifiable, Hashable {
    public let id: UUID
    public let name: String
    public let color: HabitColor
    public let icon: String
    public let typeKind: WidgetHabitTypeKind
    public let target: Double?
    public let currentStreak: Int
    public let bestStreak: Int
    public let currentScore: Double

    public init(
        id: UUID,
        name: String,
        color: HabitColor,
        icon: String,
        typeKind: WidgetHabitTypeKind,
        target: Double?,
        currentStreak: Int = 0,
        bestStreak: Int = 0,
        currentScore: Double = 0.0
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.icon = icon
        self.typeKind = typeKind
        self.target = target
        self.currentStreak = currentStreak
        self.bestStreak = bestStreak
        self.currentScore = currentScore
    }

    /// `currentScore` as the whole percent every widget surface
    /// displays. One rounding shared by all of them — the today
    /// widgets read it through `WidgetTodayRow.scorePercent` and the
    /// weekly grid straight off the habit, so the two can't disagree
    /// about the same habit by a point. Clamped because the value
    /// arrives from App Group JSON that nothing revalidates.
    public var scorePercent: Int {
        Int((max(0, min(1, currentScore)) * 100).rounded())
    }

    // Backward-compatible decoding: pre-upgrade snapshot files on
    // disk don't carry the stats fields; default them to zero.
    private enum CodingKeys: String, CodingKey {
        case id, name, color, icon, typeKind, target
        case currentStreak, bestStreak, currentScore
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.name = try c.decode(String.self, forKey: .name)
        self.color = try c.decode(HabitColor.self, forKey: .color)
        self.icon = try c.decode(String.self, forKey: .icon)
        self.typeKind = try c.decode(WidgetHabitTypeKind.self, forKey: .typeKind)
        self.target = try c.decodeIfPresent(Double.self, forKey: .target)
        self.currentStreak = (try? c.decode(Int.self, forKey: .currentStreak)) ?? 0
        self.bestStreak = (try? c.decode(Int.self, forKey: .bestStreak)) ?? 0
        self.currentScore = (try? c.decode(Double.self, forKey: .currentScore)) ?? 0.0
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
    /// Mirrors `DayCell.offSchedule` — logged on a day the schedule
    /// didn't ask for. Additive case: snapshots written before it
    /// existed decode unchanged, and the app and its extensions
    /// always ship together, so there is no version skew.
    case offSchedule(Double)

    /// Same linear remap the main app's `DayCell.colorOpacity`
    /// uses. Copied rather than reused so widgets don't depend on
    /// `DayCell` (which conflicts with `OverviewMatrix` internals).
    public var colorOpacity: Double? {
        switch self {
        case .future, .notDue:
            return nil
        case .scored(let s), .offSchedule(let s):
            let clamped = max(0.0, min(1.0, s))
            return 0.2 + 0.8 * clamped
        }
    }

    /// Mirrors `DayCell.borderOpacity` — floored at 0.6 so a logged
    /// off-schedule day never renders quieter than the neutral cell
    /// beside it.
    public var borderOpacity: Double? {
        guard case .offSchedule(let s) = self else { return nil }
        let clamped = max(0.0, min(1.0, s))
        return 0.6 + 0.4 * clamped
    }

    /// Mirrors `DayCell.offScheduleFillOpacity`.
    public var offScheduleFillOpacity: Double? {
        guard case .offSchedule = self else { return nil }
        return (colorOpacity ?? 0) * 0.25
    }
}
