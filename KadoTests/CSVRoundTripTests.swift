import Testing
import Foundation
import SwiftData
@testable import Kado
import KadoCore

/// The CSV counterpart to `BackupRoundTripTests`: an export followed by
/// an import into a fresh store must restore every habit and every
/// completion, field for field.
///
/// `HabitBackup` is `Hashable` over all of its fields *and* its nested
/// completions, so comparing the decoded `habits` array against the
/// original is a complete field-for-field check — any future field that
/// ships without CSV coverage fails here.
@Suite("CSV round-trip")
@MainActor
struct CSVRoundTripTests {
    private let coder = CSVBackupCoder(now: { Date(timeIntervalSince1970: 0) })

    private func freshContainer() throws -> ModelContainer {
        try ModelContainer(
            for: HabitRecord.self, CompletionRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    /// One habit of each `HabitType`, an archived habit, and a habit
    /// with no completions at all — the row shape that only exists in
    /// the CSV format.
    private func seed(into container: ModelContainer) throws {
        let context = container.mainContext

        let timer = HabitRecord(
            name: "Meditate, daily",
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
            frequency: .everyNDays(3),
            type: .negative,
            createdAt: Date(timeIntervalSince1970: 1_700_300_000),
            color: HabitColor.red,
            icon: "xmark.circle"
        )
        let archived = HabitRecord(
            name: "Old habit",
            frequency: .daily,
            type: .binary,
            createdAt: Date(timeIntervalSince1970: 1_690_000_000),
            archivedAt: Date(timeIntervalSince1970: 1_695_000_000),
            color: HabitColor.purple,
            icon: "archivebox"
        )
        // No completions — exercises the metadata-only row.
        let untouched = HabitRecord(
            name: "Never done",
            frequency: .daily,
            type: .binary,
            createdAt: Date(timeIntervalSince1970: 1_700_400_000),
            color: HabitColor.orange,
            icon: "star"
        )

        for record in [timer, counter, binary, negative, archived, untouched] {
            context.insert(record)
        }

        for index in 0..<3 {
            let date = Date(timeIntervalSince1970: 1_700_000_000 + Double(index) * 86_400)
            // Notes that exercise every CSV escape at once.
            let note: String? = index == 0 ? "went well, \"really\"\nsecond line" : nil
            context.insert(CompletionRecord(date: date, value: 600 - Double(index) * 10, note: note, habit: timer))
            context.insert(CompletionRecord(date: date, value: Double(index + 1), note: nil, habit: counter))
            context.insert(CompletionRecord(date: date, value: 1, note: "plain note", habit: binary))
            context.insert(CompletionRecord(date: date, value: 1, note: nil, habit: negative))
        }
        context.insert(CompletionRecord(
            date: Date(timeIntervalSince1970: 1_692_000_000),
            value: 1,
            note: "last time",
            habit: archived
        ))

        try context.save()
    }

    // MARK: - Tests

    @Test("BackupDocument to CSV and back preserves every field")
    func documentRoundTrip() throws {
        let source = try freshContainer()
        try seed(into: source)

        let original = try DefaultBackupExporter(appVersion: "test").export(from: source.mainContext)
        let decoded = try coder.decode(coder.encode(original))

        #expect(decoded.habits == original.habits)
        #expect(decoded.formatVersion == original.formatVersion)
    }

    @Test("Store to CSV to an empty store restores every habit and completion")
    func storeRoundTrip() throws {
        let source = try freshContainer()
        try seed(into: source)

        let exported = try DefaultBackupExporter(appVersion: "test").export(from: source.mainContext)
        let csv = coder.encode(exported)

        let destination = try freshContainer()
        let document = try coder.decode(csv)
        let summary = try DefaultBackupImporter().apply(document, to: destination.mainContext)

        #expect(summary.totalHabits == 6)
        #expect(summary.newHabits == 6)
        #expect(summary.totalCompletions == 13)

        // Re-export the destination and compare against the source's
        // document: equal habit arrays means every field survived the
        // store to CSV to store trip.
        let reExported = try DefaultBackupExporter(appVersion: "test").export(from: destination.mainContext)
        #expect(reExported.habits == exported.habits)
    }

    @Test("Empty store produces a header-only CSV that re-imports cleanly")
    func emptyRoundTrip() throws {
        let source = try freshContainer()
        let exported = try DefaultBackupExporter(appVersion: "test").export(from: source.mainContext)
        let csv = coder.encode(exported)

        #expect(String(decoding: csv, as: UTF8.self) == CSVBackupCoder.columns.joined(separator: ",") + "\n")

        let destination = try freshContainer()
        let summary = try DefaultBackupImporter().apply(try coder.decode(csv), to: destination.mainContext)
        #expect(summary.totalHabits == 0)
        #expect(try destination.mainContext.fetch(FetchDescriptor<HabitRecord>()).isEmpty)
    }

    @Test("The habit with no completions survives as a metadata-only row")
    func habitWithoutCompletionsSurvives() throws {
        let source = try freshContainer()
        try seed(into: source)

        let exported = try DefaultBackupExporter(appVersion: "test").export(from: source.mainContext)
        let decoded = try coder.decode(coder.encode(exported))

        let untouched = try #require(decoded.habits.first { $0.name == "Never done" })
        #expect(untouched.completions.isEmpty)
    }

    @Test("CSV and JSON exports of the same store carry identical habit data")
    func csvMatchesJSON() throws {
        let source = try freshContainer()
        try seed(into: source)

        let exporter = DefaultBackupExporter(appVersion: "test")
        let document = try exporter.export(from: source.mainContext)

        let viaCSV = try coder.decode(coder.encode(document))
        let viaJSON = try DefaultBackupImporter().parse(data: try exporter.encode(document))

        #expect(viaCSV.habits == viaJSON.habits)
    }
}
