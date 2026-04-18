import Foundation

/// Reads and writes `WidgetSnapshot` to a JSON file inside the
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

    /// Encode + write a snapshot. Silent on failure — widgets will
    /// fall back to their empty state if the file is missing or
    /// corrupt.
    public static func write(_ snapshot: WidgetSnapshot) {
        guard let url = url() else { return }
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(snapshot)
            try data.write(to: url, options: .atomic)
        } catch {
            // Snapshot write is best-effort; widgets will render
            // whatever the last successful snapshot was, or the
            // empty placeholder.
        }
    }

    /// Read the snapshot, returning `.empty` on any failure.
    public static func read() -> WidgetSnapshot {
        guard let url = url(),
              let data = try? Data(contentsOf: url) else {
            return .empty
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(WidgetSnapshot.self, from: data)) ?? .empty
    }
}
