import Foundation
import SwiftData

/// Turns the live SwiftData store into a `BackupDocument` ready to
/// serialize as JSON. Protocol-defined so views can inject a mock in
/// previews.
@MainActor
public protocol BackupExporting: Sendable {
    /// Fetch every habit (including archived) with its completions,
    /// and wrap them in a `BackupDocument`.
    func export(from context: ModelContext) throws -> BackupDocument

    /// Convenience: encode the document to JSON bytes with the backup's
    /// canonical encoding (ISO8601 dates, sorted keys, pretty-printed).
    func encode(_ document: BackupDocument) throws -> Data
}

public extension BackupExporting {
    /// Default composite: build the document from the store and encode
    /// it in one step.
    func exportData(from context: ModelContext) throws -> Data {
        try encode(try export(from: context))
    }
}

/// Production exporter. Reads every `HabitRecord`, sorted by
/// `createdAt` for a stable on-disk order.
@MainActor
public struct DefaultBackupExporter: BackupExporting {
    private let now: @Sendable () -> Date
    private let appVersion: String

    public init(
        now: @escaping @Sendable () -> Date = Date.init,
        appVersion: String = DefaultBackupExporter.bundleVersion()
    ) {
        self.now = now
        self.appVersion = appVersion
    }

    public func export(from context: ModelContext) throws -> BackupDocument {
        let descriptor = FetchDescriptor<HabitRecord>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        let records = try context.fetch(descriptor)
        let habits = records.map(Self.backup(from:))
        return BackupDocument(
            exportedAt: now(),
            appVersion: appVersion,
            habits: habits
        )
    }

    public func encode(_ document: BackupDocument) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(document)
    }

    /// Reads `CFBundleShortVersionString` from the main bundle with a
    /// safe fallback — previews and tests run with no version stamped.
    /// `nonisolated` so it's usable as a default-argument expression
    /// from any actor context.
    public nonisolated static func bundleVersion() -> String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "unknown"
    }

    private static func backup(from record: HabitRecord) -> HabitBackup {
        let habit = record.snapshot
        let completions = (record.completions ?? [])
            .sorted { $0.date < $1.date }
            .map { record in
                CompletionBackup(
                    id: record.id,
                    date: record.date,
                    value: record.value,
                    note: record.note
                )
            }
        return HabitBackup(
            id: habit.id,
            name: habit.name,
            frequency: habit.frequency,
            type: habit.type,
            createdAt: habit.createdAt,
            archivedAt: habit.archivedAt,
            color: habit.color,
            icon: habit.icon,
            remindersEnabled: habit.remindersEnabled,
            reminderHour: habit.reminderHour,
            reminderMinute: habit.reminderMinute,
            completions: completions
        )
    }
}
