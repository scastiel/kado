import Foundation

/// Failures raised while parsing CSV text.
///
/// Deliberately separate from `BackupError`: these primitives know
/// nothing about backups, and the coder layer maps them onto its own
/// error surface.
nonisolated public enum CSVParseError: Error, Equatable, Sendable {
    /// A quoted field was opened and never closed. The associated value
    /// is the 1-based line on which the quote *started*, which is what
    /// a user needs in order to find it — not the line where the file
    /// happened to run out.
    case unterminatedQuote(line: Int)
}

/// Parses RFC 4180 CSV text into rows of fields.
///
/// This is a character-by-character state machine rather than a
/// `split(separator:)` pass, because a quoted field may legitimately
/// contain the delimiter *and* line breaks. Kadō completion notes are
/// free text, so multi-line fields are a real case here, not a
/// theoretical one.
///
/// Accepts `\n`, `\r\n`, and lone `\r` line endings. Entirely blank
/// lines are skipped.
nonisolated public enum CSVReader {
    public static func parse(_ text: String) throws -> [[String]] {
        var rows: [[String]] = []
        var fields: [String] = []
        var field = ""
        var inQuotes = false
        var rowIsEmpty = true
        var line = 1
        var quoteStartLine = 1

        func endField() {
            fields.append(field)
            field = ""
        }

        func endRow() {
            guard !rowIsEmpty else {
                fields = []
                field = ""
                return
            }
            endField()
            rows.append(fields)
            fields = []
            rowIsEmpty = true
        }

        var index = text.startIndex
        while index < text.endIndex {
            let character = text[index]

            if inQuotes {
                if character == "\"" {
                    let next = text.index(after: index)
                    if next < text.endIndex, text[next] == "\"" {
                        // Doubled quote: one literal quote, skip the pair.
                        field.append("\"")
                        index = next
                    } else {
                        inQuotes = false
                    }
                } else {
                    if Self.isLineBreak(character) { line += 1 }
                    field.append(character)
                }
            } else {
                switch character {
                case "\"":
                    inQuotes = true
                    rowIsEmpty = false
                    quoteStartLine = line
                case CSVWriter.delimiter:
                    rowIsEmpty = false
                    endField()
                case "\r\n", "\r", "\n":
                    // `\r\n` is matched as its own case because Swift
                    // clusters it into a single `Character` equal to
                    // neither `"\r"` nor `"\n"` — no lookahead needed,
                    // but omitting the case drops the row break.
                    line += 1
                    endRow()
                default:
                    rowIsEmpty = false
                    field.append(character)
                }
            }

            index = text.index(after: index)
        }

        if inQuotes {
            throw CSVParseError.unterminatedQuote(line: quoteStartLine)
        }

        // A final row not terminated by a newline still counts.
        endRow()

        return rows
    }

    /// True for `\n`, `\r`, and the clustered `\r\n` character. Checked
    /// over unicode scalars so the CRLF grapheme counts as one break
    /// rather than none.
    private static func isLineBreak(_ character: Character) -> Bool {
        character.unicodeScalars.contains { $0 == "\n" || $0 == "\r" }
    }
}
