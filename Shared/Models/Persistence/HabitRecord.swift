import Foundation
import SwiftData

extension KadoSchemaV1 {
    /// Persistent representation of a habit. CloudKit-shape: every
    /// stored property has a default value or is optional, no unique
    /// constraints, the to-many relationship has an explicit inverse
    /// with cascade delete.
    ///
    /// `completions` is nullable — CloudKit rejects a non-optional
    /// relationship on either side of an association at runtime
    /// (`NSCocoaErrorDomain 134060`). Callers coalesce with `?? []`.
    ///
    /// `Frequency` and `HabitType` are stored as their JSON-encoded
    /// `Data` blobs (computed accessors do the encode/decode), since
    /// SwiftData's `@Model` macro currently mishandles composite
    /// Codable enums as direct stored properties on this toolchain.
    @Model
    final class HabitRecord {
        var id: UUID = UUID()
        var name: String = ""
        private var frequencyData: Data = Data()
        private var typeData: Data = Data()
        var createdAt: Date = Date()
        var archivedAt: Date?

        @Relationship(deleteRule: .cascade, inverse: \CompletionRecord.habit)
        var completions: [CompletionRecord]? = []

        init(
            id: UUID = UUID(),
            name: String = "",
            frequency: Frequency = .daily,
            type: HabitType = .binary,
            createdAt: Date = .now,
            archivedAt: Date? = nil,
            completions: [CompletionRecord]? = []
        ) {
            self.id = id
            self.name = name
            self.frequencyData = Self.encode(frequency)
            self.typeData = Self.encode(type)
            self.createdAt = createdAt
            self.archivedAt = archivedAt
            self.completions = completions
        }

        var frequency: Frequency {
            get { Self.decode(frequencyData, fallback: .daily) }
            set { frequencyData = Self.encode(newValue) }
        }

        var type: HabitType {
            get { Self.decode(typeData, fallback: .binary) }
            set { typeData = Self.encode(newValue) }
        }

        /// Pure value-type projection for the score and frequency
        /// services (which only know about value types).
        var snapshot: Habit {
            Habit(
                id: id,
                name: name,
                frequency: frequency,
                type: type,
                createdAt: createdAt,
                archivedAt: archivedAt
            )
        }

        private static func encode<T: Encodable>(_ value: T) -> Data {
            // Encoding our own Codable types is unreachable — fail loud
            // if a future change breaks it.
            try! JSONEncoder().encode(value)
        }

        private static func decode<T: Decodable>(_ data: Data, fallback: T) -> T {
            // Decode is forgiving: a corrupt on-disk store falls back to
            // the type's neutral default rather than crashing the app.
            (try? JSONDecoder().decode(T.self, from: data)) ?? fallback
        }
    }
}
