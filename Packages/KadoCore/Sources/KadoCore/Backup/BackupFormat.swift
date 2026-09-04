import Foundation
import UniformTypeIdentifiers

/// The serializations a backup can take on disk.
///
/// JSON is the lossless archival format; CSV carries the same habit and
/// completion data in a shape spreadsheets can open. Both round-trip
/// through `BackupDocument`, so the choice only affects encoding.
nonisolated public enum BackupFormat: String, CaseIterable, Hashable, Sendable {
    case json
    case csv

    /// Filename extension, without the dot.
    public var fileExtension: String { rawValue }

    /// Content type for `fileImporter` and the share sheet.
    public var contentType: UTType {
        switch self {
        case .json: .json
        case .csv: .commaSeparatedText
        }
    }

    /// Resolve a format from a file's path extension, case-insensitively.
    ///
    /// Returns `nil` for anything unrecognized so the caller can fall
    /// back to sniffing the contents — some file providers rename on
    /// export, and an extension is a hint rather than a guarantee.
    public static func detect(pathExtension: String) -> BackupFormat? {
        BackupFormat(rawValue: pathExtension.lowercased())
    }

    /// Sniff a format from the leading bytes when the extension didn't
    /// resolve. A JSON backup always starts with `{` once whitespace is
    /// skipped; anything else is treated as CSV.
    public static func sniff(_ data: Data) -> BackupFormat {
        let leading = data.prefix(64)
        for byte in leading {
            // Skip ASCII whitespace: space, tab, LF, CR.
            if byte == 0x20 || byte == 0x09 || byte == 0x0A || byte == 0x0D { continue }
            return byte == UInt8(ascii: "{") ? .json : .csv
        }
        return .csv
    }
}
