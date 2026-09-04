import Foundation

/// Serializes rows of fields as RFC 4180 CSV text.
///
/// Rows are terminated with `\n` rather than the RFC's `\r\n`: the file
/// is produced and consumed on Apple platforms, Numbers and Excel both
/// accept bare line feeds, and LF keeps golden-file tests and `git
/// diff` readable. `CSVReader` accepts either ending on the way back
/// in.
///
/// `nonisolated` because these are pure functions with no MainActor
/// state, and the project defaults every type to MainActor isolation.
nonisolated public enum CSVWriter {
    /// Field separator. Fixed, never localized — a `;` delimiter for
    /// French Excel was considered and rejected during research, since
    /// one machine-readable format matters more than one spreadsheet's
    /// import defaults.
    public static let delimiter: Character = ","

    /// Join `rows` into CSV text, escaping each field as needed. Every
    /// row, including the last, is terminated with a newline. An empty
    /// `rows` array produces an empty string rather than a lone
    /// newline.
    public static func write(_ rows: [[String]]) -> String {
        rows.reduce(into: "") { output, row in
            output += row.map(escape).joined(separator: String(delimiter))
            output += "\n"
        }
    }

    /// Quote a field iff it contains the delimiter, a double quote, or
    /// a line break; embedded quotes are doubled.
    ///
    /// Note the one shape CSV cannot represent unambiguously: a row
    /// holding a single empty field serializes to a bare newline, which
    /// reads back as no row at all. Kadō's backup format always writes
    /// a fixed column count, so the case can't arise there.
    /// The line-break check runs over unicode scalars, not characters:
    /// Swift clusters `\r\n` into a *single* `Character` that equals
    /// neither `"\r"` nor `"\n"`, so a character-wise check silently
    /// fails to quote a field containing a CRLF pair.
    static func escape(_ field: String) -> String {
        let hasLineBreak = field.unicodeScalars.contains { $0 == "\n" || $0 == "\r" }
        let needsQuoting = hasLineBreak || field.contains(delimiter) || field.contains("\"")
        guard needsQuoting else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
