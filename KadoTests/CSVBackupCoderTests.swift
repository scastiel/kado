import Testing
import Foundation
@testable import Kado
import KadoCore

@Suite("CSVBackupCoder")
struct CSVBackupCoderTests {
    // MARK: - Fixtures

    private let habitID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
    private let otherHabitID = UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!
    private let completionID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
    private let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
    private let completedAt = Date(timeIntervalSince1970: 1_700_086_400)

    private let coder = CSVBackupCoder(now: { Date(timeIntervalSince1970: 0) })

    private func habit(
        id: UUID? = nil,
        name: String = "Meditate",
        frequency: Frequency = .daily,
        type: HabitType = .binary,
        archivedAt: Date? = nil,
        completions: [CompletionBackup] = []
    ) -> HabitBackup {
        HabitBackup(
            id: id ?? habitID,
            name: name,
            frequency: frequency,
            type: type,
            createdAt: createdAt,
            archivedAt: archivedAt,
            color: .blue,
            icon: "leaf",
            remindersEnabled: true,
            reminderHour: 7,
            reminderMinute: 30,
            completions: completions
        )
    }

    private func document(_ habits: [HabitBackup]) -> BackupDocument {
        BackupDocument(
            exportedAt: Date(timeIntervalSince1970: 1_700_100_000),
            appVersion: "1.6.0",
            habits: habits
        )
    }

    /// Round-trips a document and returns the habits that came back.
    /// The envelope (`exportedAt` / `appVersion`) is deliberately not
    /// carried by CSV, so only habits are comparable.
    private func roundTrip(_ habits: [HabitBackup]) throws -> [HabitBackup] {
        try coder.decode(coder.encode(document(habits))).habits
    }

    // MARK: - Union type encoding

    @Test("Every Frequency case round-trips through its CSV encoding")
    func frequencyRoundTrip() throws {
        let frequencies: [Frequency] = [
            .daily,
            .daysPerWeek(5),
            .specificDays([.monday, .wednesday, .friday]),
            .specificDays([.sunday, .saturday]),
            .everyNDays(3)
        ]
        for frequency in frequencies {
            let restored = try roundTrip([habit(frequency: frequency)])
            #expect(restored.first?.frequency == frequency, "failed for \(frequency)")
        }
    }

    @Test("Every HabitType case round-trips through its CSV encoding")
    func habitTypeRoundTrip() throws {
        let types: [HabitType] = [
            .binary,
            .negative,
            .counter(target: 8),
            .timer(targetSeconds: 600)
        ]
        for type in types {
            let restored = try roundTrip([habit(type: type)])
            #expect(restored.first?.type == type, "failed for \(type)")
        }
    }

    // MARK: - Shape and optionality

    @Test("Habit with zero completions survives the round-trip")
    func habitWithoutCompletions() throws {
        let restored = try roundTrip([habit()])
        #expect(restored.count == 1)
        #expect(restored.first?.id == habitID)
        #expect(restored.first?.completions.isEmpty == true)
    }

    @Test("Nil archivedAt and nil note decode back as nil")
    func nilFieldsStayNil() throws {
        let completion = CompletionBackup(id: completionID, date: completedAt, value: 1, note: nil)
        let restored = try roundTrip([habit(archivedAt: nil, completions: [completion])])
        #expect(restored.first?.archivedAt == nil)
        #expect(restored.first?.completions.first?.note == nil)
    }

    @Test("Set archivedAt round-trips")
    func archivedHabit() throws {
        let restored = try roundTrip([habit(archivedAt: completedAt)])
        #expect(restored.first?.archivedAt == completedAt)
    }

    @Test("Note containing a comma, quote, and newline round-trips")
    func nastyNote() throws {
        let note = "went well, \"really\"\nsecond line"
        let completion = CompletionBackup(id: completionID, date: completedAt, value: 2.5, note: note)
        let restored = try roundTrip([habit(completions: [completion])])
        #expect(restored.first?.completions.first?.note == note)
        #expect(restored.first?.completions.first?.value == 2.5)
    }

    @Test("Habit name containing the delimiter round-trips")
    func nameWithDelimiter() throws {
        let restored = try roundTrip([habit(name: "Read, then write")])
        #expect(restored.first?.name == "Read, then write")
    }

    @Test("Multiple habits and completions keep their order")
    func multipleHabits() throws {
        let first = CompletionBackup(id: completionID, date: completedAt, value: 1, note: nil)
        let second = CompletionBackup(id: UUID(), date: completedAt.addingTimeInterval(86_400), value: 1, note: nil)
        let restored = try roundTrip([
            habit(completions: [first, second]),
            habit(id: otherHabitID, name: "Run")
        ])
        #expect(restored.map(\.id) == [habitID, otherHabitID])
        #expect(restored.first?.completions.count == 2)
        #expect(restored.first?.completions.map(\.id) == [first.id, second.id])
    }

    // MARK: - Malformed input

    @Test("Conflicting habit metadata across rows resolves to the first row")
    func firstRowWins() throws {
        let csv = String(decoding: coder.encode(document([
            habit(completions: [
                CompletionBackup(id: completionID, date: completedAt, value: 1, note: nil),
                CompletionBackup(id: UUID(), date: completedAt, value: 1, note: nil)
            ])
        ])), as: UTF8.self)

        // Rewrite the habit name on the *second* data row only. Safe to
        // split on newlines here: no field in this fixture is quoted.
        // #require, not #expect: a non-fatal check here would let the
        // next line index out of bounds and trap the whole test runner.
        var lines = csv.split(separator: "\n").map(String.init)
        try #require(lines.count == 3, "fixture should be a header plus two rows")
        lines[2] = lines[2].replacingOccurrences(of: "Meditate", with: "Renamed")
        let edited = lines.joined(separator: "\n") + "\n"

        let restored = try coder.decode(Data(edited.utf8)).habits
        #expect(restored.count == 1)
        #expect(restored.first?.name == "Meditate")
    }

    @Test("format_version higher than current throws unsupportedVersion")
    func unsupportedVersion() throws {
        let csv = String(decoding: coder.encode(document([habit()])), as: UTF8.self)
        let bumped = csv.replacingOccurrences(of: "\n1,", with: "\n99,")
        #expect(throws: BackupError.unsupportedVersion(99)) {
            try coder.decode(Data(bumped.utf8))
        }
    }

    @Test("Row with the wrong column count throws malformedRow")
    func malformedRow() throws {
        let csv = String(decoding: coder.encode(document([habit()])), as: UTF8.self)
        #expect(throws: BackupError.malformedRow(line: 3)) {
            try coder.decode(Data((csv + "1,2,3\n").utf8))
        }
    }

    @Test("Unparseable frequency payload throws invalidCSV")
    func badFrequency() throws {
        let csv = String(decoding: coder.encode(document([habit(frequency: .everyNDays(3))])), as: UTF8.self)
        let broken = csv.replacingOccurrences(of: "every_n_days:3", with: "every_n_days:banana")
        #expect(throws: BackupError.invalidCSV) {
            try coder.decode(Data(broken.utf8))
        }
    }

    @Test("Unparseable UUID throws invalidCSV")
    func badUUID() throws {
        let csv = String(decoding: coder.encode(document([habit()])), as: UTF8.self)
        let broken = csv.replacingOccurrences(of: habitID.uuidString, with: "not-a-uuid")
        #expect(throws: BackupError.invalidCSV) {
            try coder.decode(Data(broken.utf8))
        }
    }

    @Test("Missing header throws invalidCSV")
    func missingHeader() {
        #expect(throws: BackupError.invalidCSV) {
            try coder.decode(Data("nope,not,a,header\n".utf8))
        }
    }

    @Test("Empty input throws invalidCSV")
    func emptyInput() {
        #expect(throws: BackupError.invalidCSV) {
            try coder.decode(Data())
        }
    }

    @Test("Unterminated quote surfaces as invalidCSV, not a CSVParseError")
    func unterminatedQuoteMapsToBackupError() {
        #expect(throws: BackupError.invalidCSV) {
            try coder.decode(Data("\"unclosed".utf8))
        }
    }

    // MARK: - Spreadsheet round-trip

    /// Excel's "Save As → CSV UTF-8" prepends a byte order mark. Without
    /// tolerance for it the strict header match fails and the user is
    /// told their header row is damaged, which it isn't.
    @Test("Leading UTF-8 BOM is tolerated")
    func byteOrderMarkTolerated() throws {
        var bomPrefixed = Data([0xEF, 0xBB, 0xBF])
        bomPrefixed.append(coder.encode(document([habit()])))

        let restored = try coder.decode(bomPrefixed).habits
        #expect(restored.first?.id == habitID)
    }

    /// Spreadsheets normalize a boolean column to TRUE / FALSE on save.
    @Test("Boolean columns accept spreadsheet TRUE and FALSE")
    func spreadsheetBooleans() throws {
        let csv = String(decoding: coder.encode(document([habit()])), as: UTF8.self)
        let shouted = csv.replacingOccurrences(of: ",true,", with: ",TRUE,")
        try #require(shouted != csv, "fixture should contain a lowercase boolean to rewrite")

        let restored = try coder.decode(Data(shouted.utf8)).habits
        #expect(restored.first?.remindersEnabled == true)
    }

    /// Copy-pasting a row in Numbers is the advertised workflow, and two
    /// rows carrying the same completion_id must not become two
    /// CompletionRecords sharing a UUID — CloudKit forbids
    /// `@Attribute(.unique)`, so nothing downstream would catch it.
    @Test("Duplicate completion rows collapse to a single completion")
    func duplicateCompletionRows() throws {
        let completion = CompletionBackup(id: completionID, date: completedAt, value: 1, note: nil)
        let csv = String(decoding: coder.encode(document([habit(completions: [completion])])), as: UTF8.self)

        var lines = csv.split(separator: "\n").map(String.init)
        try #require(lines.count == 2, "fixture should be a header plus one row")
        lines.append(lines[1])

        let restored = try coder.decode(Data((lines.joined(separator: "\n") + "\n").utf8)).habits
        #expect(restored.count == 1)
        #expect(restored.first?.completions.count == 1)
        #expect(restored.first?.completions.first?.id == completionID)
    }

    // MARK: - Canonical shape

    @Test("Header lists the sixteen columns in order")
    func header() {
        let csv = String(decoding: coder.encode(document([])), as: UTF8.self)
        #expect(csv == """
        format_version,habit_id,habit_name,frequency,type,created_at,archived_at,color,icon,reminders_enabled,reminder_hour,reminder_minute,completion_id,completion_date,value,note

        """)
    }

    /// Golden file. The expected string below was produced by running
    /// the encoder and pasting its output — never by hand-computing the
    /// ISO8601 timestamps, which is how PR #16 burned two test cycles.
    @Test("Canonical CSV shape")
    func canonicalShape() {
        let completion = CompletionBackup(id: completionID, date: completedAt, value: 1, note: "felt good")
        let csv = String(decoding: coder.encode(document([
            habit(
                frequency: .specificDays([.monday, .wednesday, .friday]),
                type: .timer(targetSeconds: 600),
                completions: [completion]
            )
        ])), as: UTF8.self)

        #expect(csv == """
        format_version,habit_id,habit_name,frequency,type,created_at,archived_at,color,icon,reminders_enabled,reminder_hour,reminder_minute,completion_id,completion_date,value,note
        1,AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA,Meditate,specific_days:2|4|6,timer:600.0,2023-11-14T22:13:20Z,,blue,leaf,true,7,30,BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB,2023-11-15T22:13:20Z,1.0,felt good

        """)
    }
}
