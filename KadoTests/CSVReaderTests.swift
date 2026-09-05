import Testing
import Foundation
@testable import Kado
import KadoCore

@Suite("CSVReader RFC 4180")
struct CSVReaderTests {
    @Test("Reader accepts LF line endings")
    func lineFeedEndings() throws {
        #expect(try CSVReader.parse("a,b\nc,d\n") == [["a", "b"], ["c", "d"]])
    }

    @Test("Reader accepts CRLF line endings")
    func carriageReturnLineFeedEndings() throws {
        #expect(try CSVReader.parse("a,b\r\nc,d\r\n") == [["a", "b"], ["c", "d"]])
    }

    @Test("Trailing newline does not produce a phantom empty row")
    func noPhantomRow() throws {
        #expect(try CSVReader.parse("a,b\n").count == 1)
    }

    @Test("Missing trailing newline still yields the last row")
    func lastRowWithoutNewline() throws {
        #expect(try CSVReader.parse("a,b\nc,d") == [["a", "b"], ["c", "d"]])
    }

    @Test("Reader handles a quoted field containing the delimiter")
    func quotedDelimiter() throws {
        #expect(try CSVReader.parse("\"a,b\",c\n") == [["a,b", "c"]])
    }

    @Test("Reader handles a quoted field spanning multiple lines")
    func quotedNewline() throws {
        #expect(try CSVReader.parse("\"line one\nline two\",c\n") == [["line one\nline two", "c"]])
    }

    @Test("Reader unescapes doubled quotes")
    func doubledQuotes() throws {
        #expect(try CSVReader.parse("\"say \"\"hi\"\"\"\n") == [["say \"hi\""]])
    }

    @Test("Empty fields are preserved, including at row edges")
    func emptyFields() throws {
        #expect(try CSVReader.parse(",b,\n") == [["", "b", ""]])
    }

    @Test("Empty input yields no rows")
    func emptyInput() throws {
        #expect(try CSVReader.parse("").isEmpty)
    }

    @Test("A row of only a newline is not a row")
    func blankLineSkipped() throws {
        #expect(try CSVReader.parse("a,b\n\nc,d\n") == [["a", "b"], ["c", "d"]])
    }

    @Test("Unterminated quote throws")
    func unterminatedQuote() {
        #expect(throws: CSVParseError.unterminatedQuote(line: 1)) {
            try CSVReader.parse("\"never closed\n")
        }
    }
}
