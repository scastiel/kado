import Foundation

/// Lightweight value-type representation of a habit, used by the score
/// and frequency services. The SwiftData `@Model` wrapper (next PR)
/// will project to / from this struct.
struct Habit: Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    var frequency: Frequency
    var type: HabitType
    var createdAt: Date
    var archivedAt: Date?

    init(
        id: UUID = UUID(),
        name: String,
        frequency: Frequency,
        type: HabitType,
        createdAt: Date,
        archivedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.frequency = frequency
        self.type = type
        self.createdAt = createdAt
        self.archivedAt = archivedAt
    }
}
