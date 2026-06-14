import Foundation
import SwiftData

public extension KadoSchemaV1 {
    /// Persistent representation of a single completion event.
    /// `habit` is optional because CloudKit forbids required
    /// relationships, and during a CloudKit import the inverse is
    /// transiently nil while records arrive out of order, so
    /// `snapshot` returns nil rather than force-unwrapping (issue #54).
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

        /// Pure value-type projection, or nil when the parent `habit`
        /// inverse isn't set (e.g. mid CloudKit import). Map with
        /// `compactMap(\.snapshot)`.
        public var snapshot: Completion? {
            guard let habitID = habit?.id else { return nil }
            return Completion(
                id: id,
                habitID: habitID,
                date: date,
                value: value,
                note: note
            )
        }
    }
}
