import Foundation
import SwiftData

/// Version 3 of Kadō's persistent schema. Adds per-habit reminder
/// fields (`remindersEnabled`, `reminderHour`, `reminderMinute`),
/// migrated from V2 via a lightweight stage. V2 stays frozen — never
/// modify a shipped schema in place.
public enum KadoSchemaV3: VersionedSchema {
    public static let versionIdentifier = Schema.Version(3, 0, 0)

    public static var models: [any PersistentModel.Type] {
        [HabitRecord.self, CompletionRecord.self]
    }
}

public extension KadoSchemaV3 {
    /// Persistent representation of a habit. Mirrors V2 plus the three
    /// reminder fields, each default-valued so CloudKit /
    /// lightweight-migration can fill existing rows.
    ///
    /// Reminder time is stored as two primitive `Int`s (hour 0–23,
    /// minute 0–59) rather than a `Date` to sidestep CloudKit's
    /// timezone-stamping and to match the "fires at 9:00 wherever the
    /// device is" semantics. Primitives don't hit the SwiftData
    /// custom-enum storage bug.
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
        public var remindersEnabled: Bool = false
        public var reminderHour: Int = 9
        public var reminderMinute: Int = 0

        @Relationship(deleteRule: .cascade, inverse: \CompletionRecord.habit)
        public var completions: [CompletionRecord]? = []

        public init(
            id: UUID = UUID(),
            name: String = "",
            frequency: Frequency = .daily,
            type: HabitType = .binary,
            createdAt: Date = .now,
            archivedAt: Date? = nil,
            color: HabitColor = HabitColor.blue,
            icon: String = HabitIcon.default,
            remindersEnabled: Bool = false,
            reminderHour: Int = 9,
            reminderMinute: Int = 0,
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
            self.remindersEnabled = remindersEnabled
            self.reminderHour = reminderHour
            self.reminderMinute = reminderMinute
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
                icon: icon,
                remindersEnabled: remindersEnabled,
                reminderHour: reminderHour,
                reminderMinute: reminderMinute
            )
        }

        private static func encode<T: Encodable>(_ value: T) -> Data {
            try! JSONEncoder().encode(value)
        }

        private static func decode<T: Decodable>(_ data: Data, fallback: T) -> T {
            (try? JSONDecoder().decode(T.self, from: data)) ?? fallback
        }
    }

    /// Persistent completion event. Identical shape to V2 — copied so
    /// V3 is a complete, self-contained schema.
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

public typealias HabitRecord = KadoSchemaV3.HabitRecord
public typealias CompletionRecord = KadoSchemaV3.CompletionRecord
