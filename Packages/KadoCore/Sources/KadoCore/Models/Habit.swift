import Foundation

/// Lightweight value-type representation of a habit, used by the score
/// and frequency services. The SwiftData `@Model` wrapper projects to
/// / from this struct via `HabitRecord.snapshot`.
///
/// Equality and hashing are by `id` only: two snapshots of the same
/// habit at different times (e.g. before and after a rename) compare
/// equal, matching the persistence-identity model SwiftData uses.
public struct Habit: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var frequency: Frequency
    public var type: HabitType
    public var createdAt: Date
    public var archivedAt: Date?
    public var color: HabitColor
    public var icon: String
    public var remindersEnabled: Bool
    public var reminderHour: Int
    public var reminderMinute: Int
    public var sortOrder: Int

    public init(
        id: UUID = UUID(),
        name: String,
        frequency: Frequency,
        type: HabitType,
        createdAt: Date,
        archivedAt: Date? = nil,
        color: HabitColor = .blue,
        icon: String = HabitIcon.default,
        remindersEnabled: Bool = false,
        reminderHour: Int = 9,
        reminderMinute: Int = 0,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.frequency = frequency
        self.type = type
        self.createdAt = createdAt
        self.archivedAt = archivedAt
        self.color = color
        self.icon = icon
        self.remindersEnabled = remindersEnabled
        self.reminderHour = reminderHour
        self.reminderMinute = reminderMinute
        self.sortOrder = sortOrder
    }

    public func effectiveStart(completions: [Completion], calendar: Calendar) -> Date {
        if case .negative = type { return createdAt }
        let earliest = completions
            .filter { $0.habitID == id && $0.value > 0 }
            .map(\.date)
            .min()
        return earliest ?? createdAt
    }

    /// Whether `day` falls before `effectiveStart` — a day the score,
    /// the streak and the Overview treat as "before tracking" rather
    /// than as a miss. Compared by calendar day, not by instant.
    public func isBeforeStart(_ day: Date, completions: [Completion], calendar: Calendar) -> Bool {
        let startDay = calendar.startOfDay(for: effectiveStart(completions: completions, calendar: calendar))
        return calendar.startOfDay(for: day) < startDay
    }

    /// Whether logging `day` would move `effectiveStart` back to it,
    /// turning every day in between from "before tracking" into a
    /// miss (issue #104). Never for a negative habit, whose start
    /// stays at `createdAt` whatever it logs.
    public func loggingBackdatesStart(on day: Date, completions: [Completion], calendar: Calendar) -> Bool {
        if case .negative = type { return false }
        return isBeforeStart(day, completions: completions, calendar: calendar)
    }

    public static func == (lhs: Habit, rhs: Habit) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
