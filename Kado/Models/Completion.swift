import Foundation

/// A single recorded performance of a habit on a given day. `value`
/// semantics depend on the habit's type:
/// - `.binary` → ignored (presence means done).
/// - `.counter(target)` → units achieved (e.g. 6 of 8 glasses).
/// - `.timer(targetSeconds)` → seconds achieved.
/// - `.negative` → ignored; presence means "I had it" (failure).
struct Completion: Identifiable, Hashable, Sendable {
    let id: UUID
    var habitID: UUID
    var date: Date
    var value: Double
    var note: String?

    init(
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
}
