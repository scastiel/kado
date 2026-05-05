import Foundation
import SwiftData

/// Version 4 of Kadō's persistent schema. Adds a `sortOrder` field to
/// `HabitRecord` so users can drag-to-reorder habits in the Today view.
/// Migrated from V3 via a lightweight stage (new field has a default of 0).
public enum KadoSchemaV4: VersionedSchema {
    public static let versionIdentifier = Schema.Version(4, 0, 0)

    public static var models: [any PersistentModel.Type] {
        [HabitRecord.self, CompletionRecord.self]
    }
}

public extension KadoSchemaV4 {
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
        public var sortOrder: Int = 0

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
            sortOrder: Int = 0,
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
            self.sortOrder = sortOrder
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
                reminderMinute: reminderMinute,
                sortOrder: sortOrder
            )
        }

        private static func encode<T: Encodable>(_ value: T) -> Data {
            try! JSONEncoder().encode(value)
        }

        private static func decode<T: Decodable>(_ data: Data, fallback: T) -> T {
            (try? JSONDecoder().decode(T.self, from: data)) ?? fallback
        }
    }

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

public typealias HabitRecord = KadoSchemaV4.HabitRecord
public typealias CompletionRecord = KadoSchemaV4.CompletionRecord
