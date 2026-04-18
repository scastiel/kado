import Foundation

/// Lightweight value-type representation of a habit, used by the score
/// and frequency services. The SwiftData `@Model` wrapper projects to
/// / from this struct via `HabitRecord.snapshot`.
///
/// Equality and hashing are by `id` only: two snapshots of the same
/// habit at different times (e.g. before and after a rename) compare
/// equal, matching the persistence-identity model SwiftData uses.
struct Habit: Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    var frequency: Frequency
    var type: HabitType
    var createdAt: Date
    var archivedAt: Date?
    var color: HabitColor
    var icon: String

    init(
        id: UUID = UUID(),
        name: String,
        frequency: Frequency,
        type: HabitType,
        createdAt: Date,
        archivedAt: Date? = nil,
        color: HabitColor = .blue,
        icon: String = HabitIcon.default
    ) {
        self.id = id
        self.name = name
        self.frequency = frequency
        self.type = type
        self.createdAt = createdAt
        self.archivedAt = archivedAt
        self.color = color
        self.icon = icon
    }

    static func == (lhs: Habit, rhs: Habit) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
