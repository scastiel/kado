import Foundation
import SwiftData

extension KadoSchemaV1 {
    /// Persistent representation of a single completion event.
    /// `habit` is optional because CloudKit forbids required
    /// relationships — but a completion without a parent is a bug
    /// (cascade delete should remove orphans), so `snapshot`
    /// force-unwraps `habit?.id`.
    @Model
    final class CompletionRecord {
        var id: UUID = UUID()
        var date: Date = Date()
        var value: Double = 1.0
        var note: String?
        var habit: HabitRecord?

        init(
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
        var snapshot: Completion {
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
