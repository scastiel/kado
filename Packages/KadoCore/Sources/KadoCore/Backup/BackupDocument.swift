import Foundation

/// Root of the JSON backup format exchanged by export / import.
///
/// The wire shape is decoupled from the SwiftData schema on purpose:
/// a schema bump that renames or reshapes `HabitRecord` must not
/// silently change what a previously exported file means. Bump
/// `formatVersion` and migrate explicitly.
public struct BackupDocument: Hashable, Codable, Sendable {
    /// Current format version written by this app. Importers compare
    /// against `BackupDocument.currentFormatVersion` and refuse files
    /// with a higher value than they understand.
    public static let currentFormatVersion = 1

    public var formatVersion: Int
    public var exportedAt: Date
    public var appVersion: String
    public var habits: [HabitBackup]

    public init(
        formatVersion: Int = BackupDocument.currentFormatVersion,
        exportedAt: Date,
        appVersion: String,
        habits: [HabitBackup]
    ) {
        self.formatVersion = formatVersion
        self.exportedAt = exportedAt
        self.appVersion = appVersion
        self.habits = habits
    }
}
