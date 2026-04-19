import Foundation
import SwiftData

/// Parses a `BackupDocument` from bytes and merges it into the live
/// SwiftData store by UUID. Never deletes: habits already in the store
/// whose id isn't in the backup stay untouched.
@MainActor
public protocol BackupImporting: Sendable {
    /// Decode a backup document from JSON bytes. Throws
    /// `BackupError.invalidJSON` on structural failure, or
    /// `BackupError.unsupportedVersion` when the file's `formatVersion`
    /// exceeds what this app knows how to read.
    func parse(data: Data) throws -> BackupDocument

    /// Count how many habits and completions in `document` would be new
    /// vs. updated if applied against the current store — without
    /// mutating anything. Backs the confirmation sheet.
    func summary(for document: BackupDocument, in context: ModelContext) throws -> ImportSummary

    /// Apply the document to the store via UUID-keyed upsert. Returns
    /// the actual counts after the merge. Incoming fields overwrite on
    /// conflict.
    @discardableResult
    func apply(_ document: BackupDocument, to context: ModelContext) throws -> ImportSummary
}

/// Production importer.
@MainActor
public struct DefaultBackupImporter: BackupImporting {
    public init() {}

    public func parse(data: Data) throws -> BackupDocument {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let document: BackupDocument
        do {
            document = try decoder.decode(BackupDocument.self, from: data)
        } catch {
            throw BackupError.invalidJSON
        }
        guard document.formatVersion <= BackupDocument.currentFormatVersion else {
            throw BackupError.unsupportedVersion(document.formatVersion)
        }
        return document
    }

    public func summary(for document: BackupDocument, in context: ModelContext) throws -> ImportSummary {
        let existing = try existingHabits(in: context)
        var summary = ImportSummary()
        for habitBackup in document.habits {
            summary.totalHabits += 1
            summary.totalCompletions += habitBackup.completions.count

            if let existingHabit = existing[habitBackup.id] {
                summary.updatedHabits += 1
                let existingCompletions = Self.completionsByID(existingHabit)
                for completionBackup in habitBackup.completions {
                    if existingCompletions[completionBackup.id] != nil {
                        summary.updatedCompletions += 1
                    } else {
                        summary.newCompletions += 1
                    }
                }
            } else {
                summary.newHabits += 1
                summary.newCompletions += habitBackup.completions.count
            }
        }
        return summary
    }

    @discardableResult
    public func apply(_ document: BackupDocument, to context: ModelContext) throws -> ImportSummary {
        var existing = try existingHabits(in: context)
        var summary = ImportSummary()

        for habitBackup in document.habits {
            summary.totalHabits += 1
            summary.totalCompletions += habitBackup.completions.count

            let record: HabitRecord
            if let existingRecord = existing[habitBackup.id] {
                Self.overwrite(existingRecord, with: habitBackup)
                record = existingRecord
                summary.updatedHabits += 1
            } else {
                let newRecord = HabitRecord(
                    id: habitBackup.id,
                    name: habitBackup.name,
                    frequency: habitBackup.frequency,
                    type: habitBackup.type,
                    createdAt: habitBackup.createdAt,
                    archivedAt: habitBackup.archivedAt,
                    color: habitBackup.color,
                    icon: habitBackup.icon,
                    remindersEnabled: habitBackup.remindersEnabled,
                    reminderHour: habitBackup.reminderHour,
                    reminderMinute: habitBackup.reminderMinute
                )
                context.insert(newRecord)
                existing[habitBackup.id] = newRecord
                record = newRecord
                summary.newHabits += 1
            }

            let existingCompletions = Self.completionsByID(record)
            for completionBackup in habitBackup.completions {
                if let existingCompletion = existingCompletions[completionBackup.id] {
                    existingCompletion.date = completionBackup.date
                    existingCompletion.value = completionBackup.value
                    existingCompletion.note = completionBackup.note
                    summary.updatedCompletions += 1
                } else {
                    let completion = CompletionRecord(
                        id: completionBackup.id,
                        date: completionBackup.date,
                        value: completionBackup.value,
                        note: completionBackup.note,
                        habit: record
                    )
                    context.insert(completion)
                    summary.newCompletions += 1
                }
            }
        }

        try context.save()
        return summary
    }

    // MARK: - Helpers

    private func existingHabits(in context: ModelContext) throws -> [UUID: HabitRecord] {
        let records = try context.fetch(FetchDescriptor<HabitRecord>())
        return Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
    }

    private static func completionsByID(_ record: HabitRecord) -> [UUID: CompletionRecord] {
        Dictionary(uniqueKeysWithValues: (record.completions ?? []).map { ($0.id, $0) })
    }

    private static func overwrite(_ record: HabitRecord, with backup: HabitBackup) {
        record.name = backup.name
        record.frequency = backup.frequency
        record.type = backup.type
        record.createdAt = backup.createdAt
        record.archivedAt = backup.archivedAt
        record.color = backup.color
        record.icon = backup.icon
        record.remindersEnabled = backup.remindersEnabled
        record.reminderHour = backup.reminderHour
        record.reminderMinute = backup.reminderMinute
    }
}
