import Testing
import Foundation
import SwiftData
@testable import Kado
import KadoCore

/// The v0.2 exit-criteria gate: an export followed by an import into a
/// fresh store must restore 100% of the data, field-for-field.
@Suite("Backup round-trip")
@MainActor
struct BackupRoundTripTests {
    private func freshContainer() throws -> ModelContainer {
        try ModelContainer(
            for: HabitRecord.self, CompletionRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    /// Builds a representative seed — one of each HabitType, plus an
    /// archived habit, plus completions with and without notes,
    /// spanning multiple days with varied values.
    private func seed(into container: ModelContainer) {
        let context = container.mainContext

        let daily = HabitRecord(
            name: "Meditate",
            frequency: .daily,
            type: .timer(targetSeconds: 600),
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            color: HabitColor.blue,
            icon: "leaf",
            remindersEnabled: true,
            reminderHour: 7,
            reminderMinute: 30
        )
        let counter = HabitRecord(
            name: "Water",
            frequency: .daysPerWeek(5),
            type: .counter(target: 8),
            createdAt: Date(timeIntervalSince1970: 1_700_100_000),
            color: HabitColor.teal,
            icon: "drop.fill",
            remindersEnabled: false
        )
        let binary = HabitRecord(
            name: "Floss",
            frequency: .specificDays([.monday, .wednesday, .friday]),
            type: .binary,
            createdAt: Date(timeIntervalSince1970: 1_700_200_000),
            color: HabitColor.green,
            icon: "checkmark.circle"
        )
        let negative = HabitRecord(
            name: "Soda",
            frequency: .daily,
            type: .negative,
            createdAt: Date(timeIntervalSince1970: 1_700_300_000),
            color: HabitColor.red,
            icon: "xmark.circle"
        )
        let archived = HabitRecord(
            name: "Old habit",
            frequency: .everyNDays(3),
            type: .binary,
            createdAt: Date(timeIntervalSince1970: 1_690_000_000),
            archivedAt: Date(timeIntervalSince1970: 1_695_000_000),
            color: HabitColor.purple,
            icon: "archivebox"
        )

        context.insert(daily)
        context.insert(counter)
        context.insert(binary)
        context.insert(negative)
        context.insert(archived)

        // 10 completions per active habit, a few with notes, varied values
        for i in 0..<10 {
            let date = Date(timeIntervalSince1970: 1_700_000_000 + Double(i) * 86_400)
            let note: String? = (i % 3 == 0) ? "note \(i)" : nil
            context.insert(CompletionRecord(date: date, value: 600 - Double(i) * 10, note: note, habit: daily))
            context.insert(CompletionRecord(date: date, value: Double(i + 1), note: nil, habit: counter))
            context.insert(CompletionRecord(date: date, value: 1, note: nil, habit: binary))
            context.insert(CompletionRecord(date: date, value: 1, note: note, habit: negative))
        }
        // 2 completions on the archived habit
        context.insert(CompletionRecord(
            date: Date(timeIntervalSince1970: 1_692_000_000),
            value: 1,
            habit: archived
        ))
        context.insert(CompletionRecord(
            date: Date(timeIntervalSince1970: 1_693_000_000),
            value: 1,
            note: "last time",
            habit: archived
        ))

        try! context.save()
    }

    private struct Fingerprint: Hashable {
        let id: UUID
        let name: String
        let frequency: Frequency
        let type: HabitType
        let createdAt: Date
        let archivedAt: Date?
        let color: HabitColor
        let icon: String
        let remindersEnabled: Bool
        let reminderHour: Int
        let reminderMinute: Int
    }

    private struct CompletionFingerprint: Hashable {
        let id: UUID
        let habitID: UUID
        let date: Date
        let value: Double
        let note: String?
    }

    private func habitFingerprints(_ container: ModelContainer) throws -> Set<Fingerprint> {
        let records = try container.mainContext.fetch(FetchDescriptor<HabitRecord>())
        return Set(records.map { r in
            Fingerprint(
                id: r.id, name: r.name, frequency: r.frequency, type: r.type,
                createdAt: r.createdAt, archivedAt: r.archivedAt,
                color: r.color, icon: r.icon,
                remindersEnabled: r.remindersEnabled,
                reminderHour: r.reminderHour,
                reminderMinute: r.reminderMinute
            )
        })
    }

    private func completionFingerprints(_ container: ModelContainer) throws -> Set<CompletionFingerprint> {
        let records = try container.mainContext.fetch(FetchDescriptor<CompletionRecord>())
        return Set(records.map { r in
            CompletionFingerprint(
                id: r.id,
                habitID: r.habit?.id ?? UUID(),
                date: r.date,
                value: r.value,
                note: r.note
            )
        })
    }

    // MARK: - Tests

    @Test("Empty store exports and re-imports cleanly into a fresh container")
    func emptyRoundTrip() throws {
        let source = try freshContainer()
        let data = try DefaultBackupExporter(appVersion: "test")
            .exportData(from: source.mainContext)

        let destination = try freshContainer()
        let importer = DefaultBackupImporter()
        let document = try importer.parse(data: data)
        let summary = try importer.apply(document, to: destination.mainContext)

        #expect(summary.totalHabits == 0)
        #expect(summary.totalCompletions == 0)
        let habits = try destination.mainContext.fetch(FetchDescriptor<HabitRecord>())
        #expect(habits.isEmpty)
    }

    @Test("Seeded store round-trips every habit field and every completion field")
    func fullRoundTrip() throws {
        let source = try freshContainer()
        seed(into: source)

        let sourceHabits = try habitFingerprints(source)
        let sourceCompletions = try completionFingerprints(source)

        let exporter = DefaultBackupExporter(appVersion: "test")
        let data = try exporter.exportData(from: source.mainContext)

        let destination = try freshContainer()
        let importer = DefaultBackupImporter()
        let document = try importer.parse(data: data)
        _ = try importer.apply(document, to: destination.mainContext)

        let destHabits = try habitFingerprints(destination)
        let destCompletions = try completionFingerprints(destination)

        #expect(destHabits == sourceHabits, "habit fields must match byte-for-byte after round-trip")
        #expect(destCompletions == sourceCompletions, "completion fields must match byte-for-byte after round-trip")
    }

    @Test("Round-trip preserves the archived habit and its completions")
    func archivedHabitSurvives() throws {
        let source = try freshContainer()
        seed(into: source)

        let exporter = DefaultBackupExporter(appVersion: "test")
        let data = try exporter.exportData(from: source.mainContext)

        let destination = try freshContainer()
        let importer = DefaultBackupImporter()
        let document = try importer.parse(data: data)
        _ = try importer.apply(document, to: destination.mainContext)

        let records = try destination.mainContext.fetch(FetchDescriptor<HabitRecord>())
        let archived = try #require(records.first(where: { $0.name == "Old habit" }))
        #expect(archived.archivedAt != nil)
        #expect((archived.completions ?? []).count == 2)
    }

    @Test("Round-trip through JSON as a string is stable")
    func roundTripViaString() throws {
        let source = try freshContainer()
        seed(into: source)

        let exporter = DefaultBackupExporter(appVersion: "test")
        let data = try exporter.exportData(from: source.mainContext)
        // The JSON should be human-readable text, not arbitrary bytes.
        let jsonString = try #require(String(data: data, encoding: .utf8))
        let roundTripped = try #require(jsonString.data(using: .utf8))
        #expect(roundTripped == data)

        // And it should still decode into an equivalent document.
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let document = try decoder.decode(BackupDocument.self, from: roundTripped)
        #expect(document.habits.count == 5)
        #expect(document.habits.flatMap(\.completions).count == 42)
    }
}
