import Testing
import Foundation
@testable import Kado
import KadoCore

@Suite("CSVWriter RFC 4180")
struct CSVWriterTests {
    @Test("Plain field is written unquoted")
    func plainFieldUnquoted() {
        #expect(CSVWriter.write([["alpha", "beta"]]) == "alpha,beta\n")
    }

    @Test("Empty field is written as an empty unquoted field")
    func emptyFieldUnquoted() {
        #expect(CSVWriter.write([["alpha", "", "beta"]]) == "alpha,,beta\n")
    }

    @Test("Field containing a comma is quoted")
    func commaIsQuoted() {
        #expect(CSVWriter.write([["a,b", "c"]]) == "\"a,b\",c\n")
    }

    @Test("Field containing a quote doubles it and quotes the field")
    func quoteIsDoubled() {
        #expect(CSVWriter.write([["say \"hi\""]]) == "\"say \"\"hi\"\"\"\n")
    }

    @Test("Field containing a newline is quoted")
    func newlineIsQuoted() {
        #expect(CSVWriter.write([["line one\nline two"]]) == "\"line one\nline two\"\n")
    }

    @Test("Field containing a carriage return is quoted")
    func carriageReturnIsQuoted() {
        #expect(CSVWriter.write([["a\rb"]]) == "\"a\rb\"\n")
    }

    /// Regression: Swift clusters `\r\n` into a single `Character` that
    /// equals neither `"\r"` nor `"\n"`, so a character-wise check
    /// leaves a CRLF-containing field unquoted and corrupts the row.
    @Test("Field containing a CRLF pair is quoted")
    func carriageReturnLineFeedIsQuoted() {
        #expect(CSVWriter.write([["a\r\nb"]]) == "\"a\r\nb\"\n")
    }

    @Test("Rows are separated by a newline and the output ends with one")
    func rowSeparation() {
        let csv = CSVWriter.write([["a", "b"], ["c", "d"]])
        #expect(csv == "a,b\nc,d\n")
    }

    @Test("No rows produces empty output")
    func noRows() {
        #expect(CSVWriter.write([]).isEmpty)
    }

    // MARK: - Round-trip through the reader

    @Test("Fields needing every escape survive a writer/reader round-trip")
    func nastyFieldsRoundTrip() throws {
        let rows = [
            ["header", "note"],
            ["plain", ""],
            ["with,comma", "with \"quote\""],
            ["with\nnewline", "with\r\ncrlf"],
            ["", "trailing space "]
        ]
        let parsed = try CSVReader.parse(CSVWriter.write(rows))
        #expect(parsed == rows)
    }
}
