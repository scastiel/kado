import Foundation

/// DTO mirror of `Habit` with completions nested underneath. The
/// nested shape avoids orphan completions on import (no dangling
/// `habitID` references) and matches the SwiftData relationship graph.
public struct HabitBackup: Hashable, Codable, Sendable {
    public var id: UUID
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
    public var completions: [CompletionBackup]

    public init(
        id: UUID,
        name: String,
        frequency: Frequency,
        type: HabitType,
        createdAt: Date,
        archivedAt: Date? = nil,
        color: HabitColor,
        icon: String,
        remindersEnabled: Bool,
        reminderHour: Int,
        reminderMinute: Int,
        completions: [CompletionBackup]
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
        self.completions = completions
    }
}

public extension HabitBackup {
    /// Build a backup DTO from a domain `Habit` and its associated
    /// completions. The completions are filtered to those whose
    /// `habitID` matches this habit, then sorted by date for a stable
    /// on-disk order.
    init(habit: Habit, completions: [Completion]) {
        self.init(
            id: habit.id,
            name: habit.name,
            frequency: habit.frequency,
            type: habit.type,
            createdAt: habit.createdAt,
            archivedAt: habit.archivedAt,
            color: habit.color,
            icon: habit.icon,
            remindersEnabled: habit.remindersEnabled,
            reminderHour: habit.reminderHour,
            reminderMinute: habit.reminderMinute,
            completions: completions
                .filter { $0.habitID == habit.id }
                .sorted { $0.date < $1.date }
                .map(CompletionBackup.init(completion:))
        )
    }

    /// Project this DTO back to a domain `Habit` (completions excluded;
    /// they travel as their own array via `completionSnapshots`).
    var habitSnapshot: Habit {
        Habit(
            id: id,
            name: name,
            frequency: frequency,
            type: type,
            createdAt: createdAt,
            archivedAt: archivedAt,
            color: color,
            icon: icon,
            remindersEnabled: remindersEnabled,
            reminderHour: reminderHour,
            reminderMinute: reminderMinute
        )
    }

    /// Project the nested completion DTOs back to domain values, each
    /// stamped with this habit's id.
    var completionSnapshots: [Completion] {
        completions.map { $0.completionSnapshot(habitID: id) }
    }
}
