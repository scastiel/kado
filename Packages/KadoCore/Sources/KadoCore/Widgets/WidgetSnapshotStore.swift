import Foundation

/// Reads and writes the `WidgetSnapshotSeries` JSON file inside the
/// App Group container. The main app writes; the widget reads.
public enum WidgetSnapshotStore {
    /// Location of the on-disk snapshot file inside the App Group
    /// container. Nil when the entitlement isn't active.
    public static func url() -> URL? {
        guard let base = SharedStore.appGroupContainerURL() else { return nil }
        let dir = base.appendingPathComponent("Library/Application Support", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("widget-snapshot.json")
    }

    /// Encode + write a series. Silent on failure — widgets will fall
    /// back to their empty state if the file is missing or corrupt.
    public static func write(_ series: WidgetSnapshotSeries) {
        guard let url = url() else { return }
        do {
            try encode(series).write(to: url, options: .atomic)
        } catch {
            // Snapshot write is best-effort; widgets will render
            // whatever the last successful snapshot was, or the
            // empty placeholder.
        }
    }

    /// Read the whole series, `.empty` on any failure.
    public static func readSeries() -> WidgetSnapshotSeries {
        guard let url = url(),
              let data = try? Data(contentsOf: url) else {
            return .empty
        }
        return decode(data) ?? .empty
    }

    /// The snapshot for the current logical day — for readers that want
    /// one day and no timeline (`GetHabitStatsIntent`, `HabitEntity`).
    /// Resolved under the user's "Day starts at" hour, which lives in
    /// the same App Group suite and so reads the same in both processes.
    public static func read() -> WidgetSnapshot {
        readSeries().snapshot(on: .now, boundary: DayStartDefaults.boundary())
    }

    // MARK: - Codec

    /// The file IO above is untestable without the App Group; the two
    /// codec halves are what tests pin, the legacy fallback especially.

    public static func encode(_ series: WidgetSnapshotSeries) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(series)
    }

    /// Decodes a series, or a file written before the series existed —
    /// a bare `WidgetSnapshot` object — as a one-day series. Nil for
    /// anything else; never traps on what another build wrote.
    /// `calendar` only matters for a legacy file with no matrix days,
    /// whose day is taken from `generatedAt`.
    public static func decode(_ data: Data, calendar: Calendar = .current) -> WidgetSnapshotSeries? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.userInfo[WidgetSnapshot.calendarUserInfoKey] = calendar
        if let series = try? decoder.decode(WidgetSnapshotSeries.self, from: data) {
            return series
        }
        guard let legacy = try? decoder.decode(WidgetSnapshot.self, from: data) else {
            return nil
        }
        return WidgetSnapshotSeries(generatedAt: legacy.generatedAt, days: [legacy])
    }
}
