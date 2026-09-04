import Foundation

/// Errors surfaced by the backup import pipeline to the UI.
public enum BackupError: Error, Equatable, Sendable {
    /// The bytes don't decode as a `BackupDocument`.
    case invalidJSON
    /// The file declares a `formatVersion` newer than this app knows how
    /// to read. Associated value carries the offending version for the
    /// error message.
    case unsupportedVersion(Int)
    /// The bytes aren't parseable as Kadō's CSV backup — unreadable as
    /// CSV at all, a missing or unrecognized header, or a field whose
    /// contents don't decode.
    case invalidCSV
    /// A CSV row didn't carry the expected number of columns. The
    /// associated value is the 1-based line number, so the message can
    /// point the user at the row they broke.
    case malformedRow(line: Int)
}
