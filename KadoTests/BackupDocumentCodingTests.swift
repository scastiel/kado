import Testing
import Foundation
@testable import Kado
import KadoCore

@Suite("BackupDocument Codable")
struct BackupDocumentCodingTests {
    // MARK: - Fixtures

    private let habitID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
    private let completionID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
    private let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
    private let completedAt = Date(timeIntervalSince1970: 1_700_086_400)
    private let exportedAt = Date(timeIntervalSince1970: 1_700_100_000)

    private func sampleDocument() -> BackupDocument {
        let completion = CompletionBackup(
            id: completionID,
            date: completedAt,
            value: 1.0,
            note: "felt good"
        )
        let habit = HabitBackup(
            id: habitID,
            name: "Meditate",
            frequency: .specificDays([.monday, .wednesday, .friday]),
            type: .timer(targetSeconds: 600),
            createdAt: createdAt,
            archivedAt: nil,
            color: .blue,
            icon: "leaf",
            remindersEnabled: true,
            reminderHour: 7,
            reminderMinute: 30,
            completions: [completion]
        )
        return BackupDocument(
            exportedAt: exportedAt,
            appVersion: "0.2.0",
            habits: [habit]
        )
    }

    private func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    private func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    // MARK: - Tests

    @Test("Round-trip preserves every BackupDocument field")
    func roundTrip() throws {
        let document = sampleDocument()
        let data = try encoder().encode(document)
        let decoded = try decoder().decode(BackupDocument.self, from: data)
        #expect(decoded == document)
    }

    @Test("formatVersion defaults to currentFormatVersion")
    func defaultFormatVersion() {
        let document = BackupDocument(
            exportedAt: exportedAt,
            appVersion: "test",
            habits: []
        )
        #expect(document.formatVersion == BackupDocument.currentFormatVersion)
        #expect(document.formatVersion == 1)
    }

    @Test("Canonical JSON encodes known top-level fields under sortedKeys")
    func canonicalTopLevel() throws {
        let document = BackupDocument(
            exportedAt: exportedAt,
            appVersion: "0.2.0",
            habits: []
        )
        let data = try encoder().encode(document)
        let json = String(data: data, encoding: .utf8) ?? ""
        #expect(json == #"{"appVersion":"0.2.0","exportedAt":"2023-11-16T02:00:00Z","formatVersion":1,"habits":[]}"#)
    }

    @Test("Decodes a hand-written fixture with every field set")
    func decodesHandWrittenFixture() throws {
        let json = #"""
        {
          "formatVersion": 1,
          "exportedAt": "2023-11-16T02:00:00Z",
          "appVersion": "0.2.0",
          "habits": [
            {
              "id": "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA",
              "name": "Meditate",
              "frequency": { "kind": "specificDays", "days": [2, 4, 6] },
              "type": { "kind": "timer", "targetSeconds": 600 },
              "createdAt": "2023-11-14T22:13:20Z",
              "archivedAt": null,
              "color": "blue",
              "icon": "leaf",
              "remindersEnabled": true,
              "reminderHour": 7,
              "reminderMinute": 30,
              "completions": [
                {
                  "id": "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB",
                  "date": "2023-11-15T22:13:20Z",
                  "value": 1.0,
                  "note": "felt good"
                }
              ]
            }
          ]
        }
        """#
        let data = json.data(using: .utf8)!
        let decoded = try decoder().decode(BackupDocument.self, from: data)
        #expect(decoded == sampleDocument())
    }

    @Test("Archived habit round-trips with a non-nil archivedAt")
    func archivedRoundTrip() throws {
        let archivedAt = Date(timeIntervalSince1970: 1_700_200_000)
        let habit = HabitBackup(
            id: habitID,
            name: "Old habit",
            frequency: .daily,
            type: .binary,
            createdAt: createdAt,
            archivedAt: archivedAt,
            color: .green,
            icon: "circle",
            remindersEnabled: false,
            reminderHour: 9,
            reminderMinute: 0,
            completions: []
        )
        let document = BackupDocument(
            exportedAt: exportedAt,
            appVersion: "0.2.0",
            habits: [habit]
        )
        let data = try encoder().encode(document)
        let decoded = try decoder().decode(BackupDocument.self, from: data)
        #expect(decoded.habits.first?.archivedAt == archivedAt)
        #expect(decoded == document)
    }

    @Test("Every Frequency variant round-trips through BackupDocument")
    func frequencyVariants() throws {
        let cases: [Frequency] = [
            .daily,
            .daysPerWeek(3),
            .specificDays([.monday, .friday]),
            .everyNDays(5),
        ]
        for frequency in cases {
            let habit = HabitBackup(
                id: UUID(),
                name: "h",
                frequency: frequency,
                type: .binary,
                createdAt: createdAt,
                color: .blue,
                icon: "circle",
                remindersEnabled: false,
                reminderHour: 9,
                reminderMinute: 0,
                completions: []
            )
            let document = BackupDocument(
                exportedAt: exportedAt,
                appVersion: "test",
                habits: [habit]
            )
            let data = try encoder().encode(document)
            let decoded = try decoder().decode(BackupDocument.self, from: data)
            #expect(decoded.habits.first?.frequency == frequency, "frequency round-trip failed for \(frequency)")
        }
    }

    @Test("Every HabitType variant round-trips through BackupDocument")
    func habitTypeVariants() throws {
        let cases: [HabitType] = [
            .binary,
            .counter(target: 8),
            .timer(targetSeconds: 1200),
            .negative,
        ]
        for type in cases {
            let habit = HabitBackup(
                id: UUID(),
                name: "h",
                frequency: .daily,
                type: type,
                createdAt: createdAt,
                color: .blue,
                icon: "circle",
                remindersEnabled: false,
                reminderHour: 9,
                reminderMinute: 0,
                completions: []
            )
            let document = BackupDocument(
                exportedAt: exportedAt,
                appVersion: "test",
                habits: [habit]
            )
            let data = try encoder().encode(document)
            let decoded = try decoder().decode(BackupDocument.self, from: data)
            #expect(decoded.habits.first?.type == type, "type round-trip failed for \(type)")
        }
    }

    @Test("HabitBackup.init(habit:completions:) filters foreign completions and sorts by date")
    func habitInitFiltersAndSorts() {
        let habitA = Habit(
            id: habitID,
            name: "A",
            frequency: .daily,
            type: .binary,
            createdAt: createdAt
        )
        let foreignID = UUID()
        let c1 = Completion(id: UUID(), habitID: habitID, date: completedAt)
        let c2 = Completion(id: UUID(), habitID: habitID, date: completedAt.addingTimeInterval(-3600))
        let cForeign = Completion(id: UUID(), habitID: foreignID, date: completedAt)

        let backup = HabitBackup(habit: habitA, completions: [c1, cForeign, c2])
        #expect(backup.completions.count == 2)
        #expect(backup.completions.map(\.id) == [c2.id, c1.id], "completions must sort ascending by date")
    }

    @Test("HabitBackup.habitSnapshot round-trips every field back to Habit")
    func habitSnapshotRoundTrip() {
        let habit = Habit(
            id: habitID,
            name: "Meditate",
            frequency: .daily,
            type: .timer(targetSeconds: 300),
            createdAt: createdAt,
            archivedAt: nil,
            color: .purple,
            icon: "leaf",
            remindersEnabled: true,
            reminderHour: 8,
            reminderMinute: 15
        )
        let backup = HabitBackup(habit: habit, completions: [])
        let roundTripped = backup.habitSnapshot
        #expect(roundTripped.id == habit.id)
        #expect(roundTripped.name == habit.name)
        #expect(roundTripped.frequency == habit.frequency)
        #expect(roundTripped.type == habit.type)
        #expect(roundTripped.createdAt == habit.createdAt)
        #expect(roundTripped.archivedAt == habit.archivedAt)
        #expect(roundTripped.color == habit.color)
        #expect(roundTripped.icon == habit.icon)
        #expect(roundTripped.remindersEnabled == habit.remindersEnabled)
        #expect(roundTripped.reminderHour == habit.reminderHour)
        #expect(roundTripped.reminderMinute == habit.reminderMinute)
    }

    @Test("CompletionBackup.completionSnapshot(habitID:) stamps the parent identity")
    func completionSnapshotStampsHabitID() {
        let backup = CompletionBackup(
            id: completionID,
            date: completedAt,
            value: 3.5,
            note: "x"
        )
        let completion = backup.completionSnapshot(habitID: habitID)
        #expect(completion.id == completionID)
        #expect(completion.habitID == habitID)
        #expect(completion.date == completedAt)
        #expect(completion.value == 3.5)
        #expect(completion.note == "x")
    }
}
