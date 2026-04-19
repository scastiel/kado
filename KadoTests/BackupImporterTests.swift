import Testing
import Foundation
import SwiftData
@testable import Kado
import KadoCore

@Suite("BackupImporter")
@MainActor
struct BackupImporterTests {
    private let container: ModelContainer

    init() throws {
        container = try ModelContainer(
            for: HabitRecord.self, CompletionRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func importer() -> DefaultBackupImporter { DefaultBackupImporter() }

    private func sampleHabit(
        id: UUID = UUID(),
        name: String = "H",
        completions: [CompletionBackup] = []
    ) -> HabitBackup {
        HabitBackup(
            id: id,
            name: name,
            frequency: .daily,
            type: .binary,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            color: .blue,
            icon: "circle",
            remindersEnabled: false,
            reminderHour: 9,
            reminderMinute: 0,
            completions: completions
        )
    }

    private func document(_ habits: [HabitBackup], version: Int = 1) -> BackupDocument {
        BackupDocument(
            formatVersion: version,
            exportedAt: Date(timeIntervalSince1970: 1_700_000_000),
            appVersion: "test",
            habits: habits
        )
    }

    private func encoded(_ document: BackupDocument) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(document)
    }

    // MARK: - parse

    @Test("parse decodes a valid document")
    func parseValid() throws {
        let data = try encoded(document([sampleHabit()]))
        let parsed = try importer().parse(data: data)
        #expect(parsed.habits.count == 1)
        #expect(parsed.formatVersion == 1)
    }

    @Test("parse rejects garbage JSON with invalidJSON")
    func parseInvalid() {
        let data = "{ not json }".data(using: .utf8)!
        #expect(throws: BackupError.invalidJSON) {
            _ = try importer().parse(data: data)
        }
    }

    @Test("parse rejects a newer formatVersion with unsupportedVersion")
    func parseUnsupported() throws {
        let data = try encoded(document([], version: 99))
        #expect {
            _ = try importer().parse(data: data)
        } throws: { error in
            guard case BackupError.unsupportedVersion(let v) = error else { return false }
            return v == 99
        }
    }

    // MARK: - summary (dry run)

    @Test("summary against an empty store reports every habit as new")
    func summaryFreshStore() throws {
        let doc = document([sampleHabit(name: "A"), sampleHabit(name: "B")])
        let summary = try importer().summary(for: doc, in: container.mainContext)
        #expect(summary.totalHabits == 2)
        #expect(summary.newHabits == 2)
        #expect(summary.updatedHabits == 0)
    }

    @Test("summary matches apply on a fresh store")
    func summaryMatchesApply() throws {
        let doc = document([
            sampleHabit(completions: [
                CompletionBackup(id: UUID(), date: Date(timeIntervalSince1970: 1_700_000_000))
            ])
        ])
        let dry = try importer().summary(for: doc, in: container.mainContext)
        let applied = try importer().apply(doc, to: container.mainContext)
        #expect(dry == applied)
    }

    @Test("summary reports 'updated' for habits already in the store")
    func summaryReportsUpdates() throws {
        let habitID = UUID()
        let existing = HabitRecord(
            id: habitID,
            name: "Old",
            frequency: .daily,
            type: .binary
        )
        container.mainContext.insert(existing)

        let doc = document([sampleHabit(id: habitID, name: "New")])
        let summary = try importer().summary(for: doc, in: container.mainContext)
        #expect(summary.newHabits == 0)
        #expect(summary.updatedHabits == 1)
    }

    // MARK: - apply

    @Test("apply on a fresh store inserts every habit and completion")
    func applyFreshStore() throws {
        let completion = CompletionBackup(
            id: UUID(),
            date: Date(timeIntervalSince1970: 1_700_086_400),
            value: 1,
            note: "x"
        )
        let doc = document([sampleHabit(name: "Read", completions: [completion])])

        let summary = try importer().apply(doc, to: container.mainContext)
        #expect(summary.newHabits == 1)
        #expect(summary.newCompletions == 1)

        let habits = try container.mainContext.fetch(FetchDescriptor<HabitRecord>())
        #expect(habits.count == 1)
        #expect(habits.first?.completions?.count == 1)
        #expect(habits.first?.completions?.first?.note == "x")
    }

    @Test("Second apply of the same document is a no-op for store counts")
    func applyIdempotent() throws {
        let completion = CompletionBackup(
            id: UUID(),
            date: Date(timeIntervalSince1970: 1_700_086_400)
        )
        let doc = document([sampleHabit(name: "H", completions: [completion])])

        _ = try importer().apply(doc, to: container.mainContext)
        let second = try importer().apply(doc, to: container.mainContext)

        #expect(second.updatedHabits == 1)
        #expect(second.updatedCompletions == 1)
        #expect(second.newHabits == 0)
        #expect(second.newCompletions == 0)

        let habits = try container.mainContext.fetch(FetchDescriptor<HabitRecord>())
        let completions = try container.mainContext.fetch(FetchDescriptor<CompletionRecord>())
        #expect(habits.count == 1)
        #expect(completions.count == 1)
    }

    @Test("apply leaves habits that aren't in the backup alone")
    func applyDoesNotDelete() throws {
        let kept = HabitRecord(name: "Kept", frequency: .daily, type: .binary)
        container.mainContext.insert(kept)

        let doc = document([sampleHabit(name: "Imported")])
        _ = try importer().apply(doc, to: container.mainContext)

        let habits = try container.mainContext.fetch(FetchDescriptor<HabitRecord>())
        #expect(habits.count == 2)
        #expect(habits.contains(where: { $0.name == "Kept" }))
        #expect(habits.contains(where: { $0.name == "Imported" }))
    }

    @Test("apply overwrites every field of an existing habit on conflict")
    func applyOverwritesFields() throws {
        let id = UUID()
        let existing = HabitRecord(
            id: id,
            name: "Old",
            frequency: .daily,
            type: .binary,
            color: HabitColor.blue,
            icon: "circle",
            remindersEnabled: false,
            reminderHour: 9,
            reminderMinute: 0
        )
        container.mainContext.insert(existing)

        let incoming = HabitBackup(
            id: id,
            name: "New",
            frequency: .everyNDays(3),
            type: .counter(target: 5),
            createdAt: Date(timeIntervalSince1970: 1_500_000_000),
            archivedAt: Date(timeIntervalSince1970: 1_700_000_000),
            color: .purple,
            icon: "leaf",
            remindersEnabled: true,
            reminderHour: 6,
            reminderMinute: 45,
            completions: []
        )
        _ = try importer().apply(document([incoming]), to: container.mainContext)

        let fetched = try container.mainContext.fetch(FetchDescriptor<HabitRecord>())
        let record = try #require(fetched.first)
        #expect(record.name == "New")
        #expect(record.frequency == .everyNDays(3))
        #expect(record.type == .counter(target: 5))
        #expect(record.archivedAt == Date(timeIntervalSince1970: 1_700_000_000))
        #expect(record.color == .purple)
        #expect(record.icon == "leaf")
        #expect(record.remindersEnabled == true)
        #expect(record.reminderHour == 6)
        #expect(record.reminderMinute == 45)
    }

    @Test("apply preserves a completion's parent habit relationship")
    func applyPreservesParent() throws {
        let habitID = UUID()
        let completion = CompletionBackup(id: UUID(), date: Date(timeIntervalSince1970: 1_700_086_400))
        let doc = document([sampleHabit(id: habitID, completions: [completion])])
        _ = try importer().apply(doc, to: container.mainContext)

        let fetched = try container.mainContext.fetch(FetchDescriptor<CompletionRecord>())
        let first = try #require(fetched.first)
        #expect(first.habit?.id == habitID)
    }

    @Test("apply preserves archived habits on import")
    func applyPreservesArchived() throws {
        let archivedAt = Date(timeIntervalSince1970: 1_700_200_000)
        var habit = sampleHabit(name: "Archived")
        habit.archivedAt = archivedAt

        _ = try importer().apply(document([habit]), to: container.mainContext)

        let fetched = try container.mainContext.fetch(FetchDescriptor<HabitRecord>())
        #expect(fetched.first?.archivedAt == archivedAt)
    }
}
