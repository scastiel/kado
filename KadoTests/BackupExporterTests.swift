import Testing
import Foundation
import SwiftData
@testable import Kado
import KadoCore

@Suite("BackupExporter")
@MainActor
struct BackupExporterTests {
    private let container: ModelContainer
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    init() throws {
        container = try ModelContainer(
            for: HabitRecord.self, CompletionRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func exporter() -> DefaultBackupExporter {
        DefaultBackupExporter(now: { self.now }, appVersion: "test")
    }

    @Test("Export from an empty store yields a document with no habits")
    func emptyStore() throws {
        let document = try exporter().export(from: container.mainContext)
        #expect(document.habits.isEmpty)
        #expect(document.formatVersion == BackupDocument.currentFormatVersion)
        #expect(document.exportedAt == now)
        #expect(document.appVersion == "test")
    }

    @Test("Export includes archived habits")
    func includesArchived() throws {
        let active = HabitRecord(name: "Active", frequency: .daily, type: .binary)
        let archived = HabitRecord(
            name: "Archived",
            frequency: .daily,
            type: .binary,
            createdAt: Date(timeIntervalSince1970: 1_600_000_000),
            archivedAt: Date(timeIntervalSince1970: 1_650_000_000)
        )
        container.mainContext.insert(active)
        container.mainContext.insert(archived)

        let document = try exporter().export(from: container.mainContext)
        #expect(document.habits.count == 2)
        #expect(document.habits.contains(where: { $0.name == "Archived" && $0.archivedAt != nil }))
    }

    @Test("Export orders habits ascending by createdAt")
    func ordersByCreatedAt() throws {
        let newer = HabitRecord(
            name: "Newer",
            frequency: .daily,
            type: .binary,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let older = HabitRecord(
            name: "Older",
            frequency: .daily,
            type: .binary,
            createdAt: Date(timeIntervalSince1970: 1_600_000_000)
        )
        container.mainContext.insert(newer)
        container.mainContext.insert(older)

        let document = try exporter().export(from: container.mainContext)
        #expect(document.habits.map(\.name) == ["Older", "Newer"])
    }

    @Test("Export nests completions under their habit and sorts them by date")
    func nestedCompletionsSorted() throws {
        let habit = HabitRecord(name: "H", frequency: .daily, type: .binary)
        container.mainContext.insert(habit)
        let c1 = CompletionRecord(date: Date(timeIntervalSince1970: 1_700_000_000), habit: habit)
        let c2 = CompletionRecord(date: Date(timeIntervalSince1970: 1_699_900_000), habit: habit)
        let c3 = CompletionRecord(date: Date(timeIntervalSince1970: 1_700_100_000), habit: habit)
        container.mainContext.insert(c1)
        container.mainContext.insert(c2)
        container.mainContext.insert(c3)

        let document = try exporter().export(from: container.mainContext)
        let completions = try #require(document.habits.first?.completions)
        #expect(completions.count == 3)
        #expect(completions.map(\.date) == completions.map(\.date).sorted())
        #expect(completions.first?.id == c2.id)
        #expect(completions.last?.id == c3.id)
    }

    @Test("Exported JSON decodes back to the same document")
    func encodedDataRoundTrips() throws {
        let habit = HabitRecord(
            name: "Meditate",
            frequency: .specificDays([.monday, .wednesday]),
            type: .timer(targetSeconds: 600),
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            color: HabitColor.purple,
            icon: "leaf",
            remindersEnabled: true,
            reminderHour: 7,
            reminderMinute: 30
        )
        container.mainContext.insert(habit)
        container.mainContext.insert(
            CompletionRecord(date: Date(timeIntervalSince1970: 1_700_080_000), value: 540, note: "close", habit: habit)
        )

        let exporter = exporter()
        let data = try exporter.exportData(from: container.mainContext)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(BackupDocument.self, from: data)

        let exported = try exporter.export(from: container.mainContext)
        #expect(decoded == exported)
    }

    @Test("Exported JSON uses pretty-printed, sorted-keys formatting")
    func prettyPrintedSortedKeys() throws {
        let habit = HabitRecord(name: "H", frequency: .daily, type: .binary)
        container.mainContext.insert(habit)
        let data = try exporter().exportData(from: container.mainContext)
        let json = String(data: data, encoding: .utf8) ?? ""
        #expect(json.contains("\n"), "pretty-printed JSON should contain newlines")
        let appVersionIndex = json.range(of: "appVersion")?.lowerBound
        let formatVersionIndex = json.range(of: "formatVersion")?.lowerBound
        let habitsIndex = json.range(of: "habits")?.lowerBound
        if let a = appVersionIndex, let f = formatVersionIndex, let h = habitsIndex {
            #expect(a < f && f < h, "top-level keys must appear in sorted order")
        } else {
            Issue.record("expected all three top-level keys to be present")
        }
    }
}
