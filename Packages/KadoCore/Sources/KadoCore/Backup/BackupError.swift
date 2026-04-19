import Foundation

/// Errors surfaced by the backup import pipeline to the UI.
public enum BackupError: Error, Equatable, Sendable {
    /// The bytes don't decode as a `BackupDocument`.
    case invalidJSON
    /// The file declares a `formatVersion` newer than this app knows how
    /// to read. Associated value carries the offending version for the
    /// error message.
    case unsupportedVersion(Int)
}
