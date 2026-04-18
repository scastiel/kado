import Foundation

/// A single recorded performance of a habit on a given day. `value`
/// semantics depend on the habit's type:
/// - `.binary` → ignored (presence means done).
/// - `.counter(target)` → units achieved (e.g. 6 of 8 glasses).
/// - `.timer(targetSeconds)` → seconds achieved.
/// - `.negative` → ignored; presence means "I had it" (failure).
///
/// Equality and hashing are by `id` only — same rationale as `Habit`.
public struct Completion: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var habitID: UUID
    public var date: Date
    public var value: Double
    public var note: String?

    public init(
        id: UUID = UUID(),
        habitID: UUID,
        date: Date,
        value: Double = 1.0,
        note: String? = nil
    ) {
        self.id = id
        self.habitID = habitID
        self.date = date
        self.value = value
        self.note = note
    }

    public static func == (lhs: Completion, rhs: Completion) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
