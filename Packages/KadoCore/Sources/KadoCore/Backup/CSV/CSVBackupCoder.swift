import Foundation

/// Serializes a `BackupDocument` as consolidated CSV, and reads one
/// back.
///
/// The shape is one row per completion, with the owning habit's
/// metadata denormalized onto every row. A habit with no completions
/// still emits a single row with the four completion columns empty, so
/// it survives the round-trip.
///
/// **What "lossless" covers here**: habits and completions. The
/// envelope fields `exportedAt` and `appVersion` are provenance rather
/// than user data and are not carried — a decoded document stamps
/// `exportedAt` from the injected clock and leaves `appVersion` empty.
///
/// Timestamps use the same ISO8601 seconds precision as the JSON
/// encoder's `.iso8601` strategy, so sub-second components are dropped
/// by both formats identically. Completion *days* — all the score and
/// streak logic depends on — are unaffected.
nonisolated public struct CSVBackupCoder: Sendable {
    /// The column contract. Order is part of the format: `decode`
    /// requires an exact match, which doubles as the "is this even a
    /// Kadō CSV" check.
    public static let columns = [
        "format_version",
        "habit_id",
        "habit_name",
        "frequency",
        "type",
        "created_at",
        "archived_at",
        "color",
        "icon",
        "reminders_enabled",
        "reminder_hour",
        "reminder_minute",
        "completion_id",
        "completion_date",
        "value",
        "note"
    ]

    private let now: @Sendable () -> Date

    public init(now: @escaping @Sendable () -> Date = Date.init) {
        self.now = now
    }

    // MARK: - Encoding

    public func encode(_ document: BackupDocument) -> Data {
        var rows: [[String]] = [Self.columns]

        for habit in document.habits {
            let metadata = [
                String(document.formatVersion),
                habit.id.uuidString,
                habit.name,
                Self.encode(frequency: habit.frequency),
                Self.encode(type: habit.type),
                Self.encode(date: habit.createdAt),
                habit.archivedAt.map(Self.encode(date:)) ?? "",
                habit.color.rawValue,
                habit.icon,
                String(habit.remindersEnabled),
                String(habit.reminderHour),
                String(habit.reminderMinute)
            ]

            if habit.completions.isEmpty {
                rows.append(metadata + ["", "", "", ""])
            } else {
                for completion in habit.completions {
                    rows.append(metadata + [
                        completion.id.uuidString,
                        Self.encode(date: completion.date),
                        String(completion.value),
                        completion.note ?? ""
                    ])
                }
            }
        }

        return Data(CSVWriter.write(rows).utf8)
    }

    // MARK: - Decoding

    public func decode(_ data: Data) throws -> BackupDocument {
        guard let text = String(data: data, encoding: .utf8) else {
            throw BackupError.invalidCSV
        }

        let rows: [[String]]
        do {
            rows = try CSVReader.parse(text)
        } catch {
            // CSVParseError is an implementation detail of the RFC 4180
            // layer; the UI only knows BackupError.
            throw BackupError.invalidCSV
        }

        guard let header = rows.first, header == Self.columns else {
            throw BackupError.invalidCSV
        }

        var order: [UUID] = []
        var habits: [UUID: HabitBackup] = [:]
        var formatVersion = BackupDocument.currentFormatVersion

        for (offset, row) in rows.dropFirst().enumerated() {
            // Header occupies line 1, so the first data row is line 2.
            // Assumes no blank lines, which the reader skips silently.
            let line = offset + 2

            guard row.count == Self.columns.count else {
                throw BackupError.malformedRow(line: line)
            }

            guard let version = Int(row[0]) else { throw BackupError.invalidCSV }
            guard version <= BackupDocument.currentFormatVersion else {
                throw BackupError.unsupportedVersion(version)
            }
            formatVersion = version

            guard let habitID = UUID(uuidString: row[1]) else {
                throw BackupError.invalidCSV
            }

            // First row for a habit id wins. Later rows contribute only
            // their completion, so a hand-edited file with inconsistent
            // metadata resolves deterministically instead of by
            // whichever row happened to land last.
            if habits[habitID] == nil {
                habits[habitID] = HabitBackup(
                    id: habitID,
                    name: row[2],
                    frequency: try Self.decodeFrequency(row[3]),
                    type: try Self.decodeType(row[4]),
                    createdAt: try Self.decodeDate(row[5]),
                    archivedAt: try Self.decodeOptionalDate(row[6]),
                    color: try Self.decodeColor(row[7]),
                    icon: row[8],
                    remindersEnabled: try Self.decodeBool(row[9]),
                    reminderHour: try Self.decodeInt(row[10]),
                    reminderMinute: try Self.decodeInt(row[11]),
                    completions: []
                )
                order.append(habitID)
            }

            // An empty completion id marks a metadata-only row, which is
            // how a habit with no completions survives.
            guard !row[12].isEmpty else { continue }
            guard let completionID = UUID(uuidString: row[12]) else {
                throw BackupError.invalidCSV
            }
            guard let value = Double(row[14]) else { throw BackupError.invalidCSV }

            habits[habitID]?.completions.append(
                CompletionBackup(
                    id: completionID,
                    date: try Self.decodeDate(row[13]),
                    value: value,
                    note: row[15].isEmpty ? nil : row[15]
                )
            )
        }

        return BackupDocument(
            formatVersion: formatVersion,
            exportedAt: now(),
            appVersion: "",
            habits: order.compactMap { habits[$0] }
        )
    }

    // MARK: - Field encoding

    static func encode(date: Date) -> String {
        date.formatted(.iso8601)
    }

    static func encode(frequency: Frequency) -> String {
        switch frequency {
        case .daily:
            return "daily"
        case .daysPerWeek(let count):
            return "days_per_week:\(count)"
        case .specificDays(let days):
            let raw = days.map(\.rawValue).sorted().map(String.init).joined(separator: "|")
            return "specific_days:\(raw)"
        case .everyNDays(let interval):
            return "every_n_days:\(interval)"
        }
    }

    static func encode(type: HabitType) -> String {
        switch type {
        case .binary:
            return "binary"
        case .negative:
            return "negative"
        case .counter(let target):
            return "counter:\(target)"
        case .timer(let targetSeconds):
            return "timer:\(targetSeconds)"
        }
    }

    // MARK: - Field decoding

    /// Split a `kind:payload` field. `omittingEmptySubsequences: false`
    /// so `specific_days:` with no days still yields a payload rather
    /// than collapsing to a bare kind.
    private static func parts(_ field: String) -> (kind: String, payload: String?) {
        let pieces = field.split(
            separator: ":",
            maxSplits: 1,
            omittingEmptySubsequences: false
        ).map(String.init)
        return (pieces[0], pieces.count > 1 ? pieces[1] : nil)
    }

    static func decodeFrequency(_ field: String) throws -> Frequency {
        let (kind, payload) = parts(field)
        switch kind {
        case "daily":
            return .daily
        case "days_per_week":
            guard let payload, let count = Int(payload) else { throw BackupError.invalidCSV }
            return .daysPerWeek(count)
        case "specific_days":
            guard let payload else { throw BackupError.invalidCSV }
            let days = try payload
                .split(separator: "|")
                .map { raw -> Weekday in
                    guard let value = Int(raw), let day = Weekday(rawValue: value) else {
                        throw BackupError.invalidCSV
                    }
                    return day
                }
            return .specificDays(Set(days))
        case "every_n_days":
            guard let payload, let interval = Int(payload) else { throw BackupError.invalidCSV }
            return .everyNDays(interval)
        default:
            throw BackupError.invalidCSV
        }
    }

    static func decodeType(_ field: String) throws -> HabitType {
        let (kind, payload) = parts(field)
        switch kind {
        case "binary":
            return .binary
        case "negative":
            return .negative
        case "counter":
            guard let payload, let target = Double(payload) else { throw BackupError.invalidCSV }
            return .counter(target: target)
        case "timer":
            guard let payload, let seconds = Double(payload) else { throw BackupError.invalidCSV }
            return .timer(targetSeconds: seconds)
        default:
            throw BackupError.invalidCSV
        }
    }

    static func decodeDate(_ field: String) throws -> Date {
        guard let date = try? Date(field, strategy: .iso8601) else {
            throw BackupError.invalidCSV
        }
        return date
    }

    static func decodeOptionalDate(_ field: String) throws -> Date? {
        field.isEmpty ? nil : try decodeDate(field)
    }

    static func decodeColor(_ field: String) throws -> HabitColor {
        guard let color = HabitColor(rawValue: field) else { throw BackupError.invalidCSV }
        return color
    }

    static func decodeBool(_ field: String) throws -> Bool {
        guard let value = Bool(field) else { throw BackupError.invalidCSV }
        return value
    }

    static func decodeInt(_ field: String) throws -> Int {
        guard let value = Int(field) else { throw BackupError.invalidCSV }
        return value
    }
}
