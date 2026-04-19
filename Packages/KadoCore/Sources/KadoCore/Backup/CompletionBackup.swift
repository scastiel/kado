import Foundation

/// DTO mirror of `Completion`, minus `habitID` — the parent
/// `HabitBackup` holds the habit identity via nesting.
public struct CompletionBackup: Hashable, Codable, Sendable {
    public var id: UUID
    public var date: Date
    public var value: Double
    public var note: String?

    public init(
        id: UUID,
        date: Date,
        value: Double = 1.0,
        note: String? = nil
    ) {
        self.id = id
        self.date = date
        self.value = value
        self.note = note
    }
}

public extension CompletionBackup {
    init(completion: Completion) {
        self.init(
            id: completion.id,
            date: completion.date,
            value: completion.value,
            note: completion.note
        )
    }

    func completionSnapshot(habitID: UUID) -> Completion {
        Completion(
            id: id,
            habitID: habitID,
            date: date,
            value: value,
            note: note
        )
    }
}
