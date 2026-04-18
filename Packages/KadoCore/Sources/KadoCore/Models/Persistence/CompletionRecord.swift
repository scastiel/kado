import Foundation
import SwiftData

public extension KadoSchemaV1 {
    /// Persistent representation of a single completion event.
    /// `habit` is optional because CloudKit forbids required
    /// relationships — but a completion without a parent is a bug
    /// (cascade delete should remove orphans), so `snapshot`
    /// force-unwraps `habit?.id`.
    @Model
    public final class CompletionRecord {
        public var id: UUID = UUID()
        public var date: Date = Date()
        public var value: Double = 1.0
        public var note: String?
        public var habit: HabitRecord?

        public init(
            id: UUID = UUID(),
            date: Date = .now,
            value: Double = 1.0,
            note: String? = nil,
            habit: HabitRecord? = nil
        ) {
            self.id = id
            self.date = date
            self.value = value
            self.note = note
            self.habit = habit
        }

        /// Pure value-type projection. Traps if the completion has no
        /// parent habit — that state should not exist outside
        /// transient CloudKit sync windows the app does not project from.
        public var snapshot: Completion {
            Completion(
                id: id,
                habitID: habit!.id,
                date: date,
                value: value,
                note: note
            )
        }
    }
}
