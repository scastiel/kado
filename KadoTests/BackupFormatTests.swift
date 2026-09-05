import Testing
import Foundation
import UniformTypeIdentifiers
@testable import Kado
import KadoCore

@Suite("BackupFormat")
struct BackupFormatTests {
    @Test("File extensions match the raw values")
    func fileExtensions() {
        #expect(BackupFormat.json.fileExtension == "json")
        #expect(BackupFormat.csv.fileExtension == "csv")
    }

    @Test("Content types map to the system UTTypes")
    func contentTypes() {
        #expect(BackupFormat.json.contentType == .json)
        #expect(BackupFormat.csv.contentType == .commaSeparatedText)
    }

    @Test("Detection from a path extension is case-insensitive")
    func detectionIsCaseInsensitive() {
        #expect(BackupFormat.detect(pathExtension: "csv") == .csv)
        #expect(BackupFormat.detect(pathExtension: "CSV") == .csv)
        #expect(BackupFormat.detect(pathExtension: "Json") == .json)
    }

    @Test("Unrecognized extension does not resolve")
    func detectionFallsThrough() {
        #expect(BackupFormat.detect(pathExtension: "txt") == nil)
        #expect(BackupFormat.detect(pathExtension: "") == nil)
    }

    @Test("Sniffing finds JSON by its opening brace, skipping whitespace")
    func sniffJSON() throws {
        #expect(BackupFormat.sniff(Data(#"{"formatVersion":1}"#.utf8)) == .json)
        #expect(BackupFormat.sniff(Data("\n  {\"a\":1}".utf8)) == .json)
    }

    /// A JSON backup saved by a tool that writes a byte order mark still
    /// starts with `{` once the BOM is skipped.
    @Test("Sniffing sees past a UTF-8 BOM")
    func sniffSkipsByteOrderMark() {
        var data = Data([0xEF, 0xBB, 0xBF])
        data.append(Data(#"{"formatVersion":1}"#.utf8))
        #expect(BackupFormat.sniff(data) == .json)
    }

    @Test("Sniffing treats anything else, including empty input, as CSV")
    func sniffCSV() {
        #expect(BackupFormat.sniff(Data("format_version,habit_id\n".utf8)) == .csv)
        #expect(BackupFormat.sniff(Data()) == .csv)
    }
}
