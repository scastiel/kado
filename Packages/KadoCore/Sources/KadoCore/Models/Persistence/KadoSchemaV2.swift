import Foundation
import SwiftData

/// Version 2 of Kadō's persistent schema. Adds per-habit `color` and
/// `icon`, migrated from V1 via a lightweight stage. V1 stays frozen
/// — never modify a shipped schema in place.
public enum KadoSchemaV2: VersionedSchema {
    public static let versionIdentifier = Schema.Version(2, 0, 0)

    public static var models: [any PersistentModel.Type] {
        [HabitRecord.self, CompletionRecord.self]
    }
}

public extension KadoSchemaV2 {
    /// Persistent representation of a habit. Mirrors V1 plus `color`
    /// and `icon`, both defaulted so CloudKit / lightweight-migration
    /// can fill existing rows.
    ///
    /// `Frequency` and `HabitType` are stored as JSON-encoded `Data`
    /// because SwiftData's `@Model` macro mishandles composite Codable
    /// enums on this toolchain. `HabitColor` hits the same ceiling
    /// despite being a plain String-raw-value enum — SwiftData reads
    /// it back as `Any?` and fails to cast. Workaround: store the raw
    /// String and expose `color: HabitColor` via a computed accessor.
    @Model
    public final class HabitRecord {
        public var id: UUID = UUID()
        public var name: String = ""
        private var frequencyData: Data = Data()
        private var typeData: Data = Data()
        public var createdAt: Date = Date()
        public var archivedAt: Date?
        private var colorRaw: String = "blue"
        public var icon: String = "circle"

        @Relationship(deleteRule: .cascade, inverse: \CompletionRecord.habit)
        public var completions: [CompletionRecord]? = []

        public init(
            id: UUID = UUID(),
            name: String = "",
            frequency: Frequency = .daily,
            type: HabitType = .binary,
            createdAt: Date = .now,
            archivedAt: Date? = nil,
            color: HabitColor = .blue,
            icon: String = HabitIcon.default,
            completions: [CompletionRecord]? = []
        ) {
            self.id = id
            self.name = name
            self.frequencyData = Self.encode(frequency)
            self.typeData = Self.encode(type)
            self.createdAt = createdAt
            self.archivedAt = archivedAt
            self.colorRaw = color.rawValue
            self.icon = icon
            self.completions = completions
        }

        public var frequency: Frequency {
            get { Self.decode(frequencyData, fallback: .daily) }
            set { frequencyData = Self.encode(newValue) }
        }

        public var type: HabitType {
            get { Self.decode(typeData, fallback: .binary) }
            set { typeData = Self.encode(newValue) }
        }

        public var color: HabitColor {
            get { HabitColor(rawValue: colorRaw) ?? .blue }
            set { colorRaw = newValue.rawValue }
        }

        public var snapshot: Habit {
            Habit(
                id: id,
                name: name,
                frequency: frequency,
                type: type,
                createdAt: createdAt,
                archivedAt: archivedAt,
                color: color,
                icon: icon
            )
        }

        private static func encode<T: Encodable>(_ value: T) -> Data {
            try! JSONEncoder().encode(value)
        }

        private static func decode<T: Decodable>(_ data: Data, fallback: T) -> T {
            (try? JSONDecoder().decode(T.self, from: data)) ?? fallback
        }
    }

    /// Persistent completion event. Identical shape to V1 — copied so
    /// V2 is a complete, self-contained schema.
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

public typealias HabitRecord = KadoSchemaV2.HabitRecord
public typealias CompletionRecord = KadoSchemaV2.CompletionRecord
