import Foundation
import SwiftData

/// Resolves the production SwiftData SQLite URL and builds the
/// production `ModelContainer`. The store lives in the App Group
/// container so the widget extension can open the same file.
///
/// Falls back to SwiftData's default location when the App Group
/// entitlement isn't active (e.g. a fresh-cloned dev build before
/// the capability lands in Xcode). In that mode there is no
/// cross-process sharing but the app still runs.
///
/// `nonisolated` so the production factory can be used as a
/// default argument to `@MainActor`-isolated initializers without
/// an isolation warning (same rule as
/// `DevModeController.defaultProductionContainer`).
nonisolated enum SharedStore {
    /// App Group identifier. Must match the entitlement string on
    /// both the main app and the widget extension targets.
    static let appGroupID = "group.dev.scastiel.kado"

    /// App Group container root if the entitlement is active.
    static func appGroupContainerURL() -> URL? {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        )
    }

    /// Target location for the production SQLite inside the App
    /// Group container. Nil when the entitlement isn't active.
    static func productionStoreURL() -> URL? {
        guard let base = appGroupContainerURL() else { return nil }
        return base
            .appendingPathComponent("Library/Application Support", isDirectory: true)
            .appendingPathComponent("Kado.sqlite")
    }

    /// Default SwiftData location for installs that predate the
    /// App Group migration. SwiftData writes `default.store` here
    /// plus `-shm` / `-wal` sidecars.
    static func legacyStoreURL() -> URL {
        URL.applicationSupportDirectory.appendingPathComponent("default.store")
    }

    /// On-disk location for the dev-mode sandbox sqlite. Shared
    /// across processes so the widget extension's intent calls
    /// write to the same sandbox the app is using. Falls back to
    /// the app's own Application Support directory when the App
    /// Group entitlement isn't yet active.
    static func devStoreURL() -> URL {
        if let base = appGroupContainerURL() {
            return base
                .appendingPathComponent("Library/Application Support", isDirectory: true)
                .appendingPathComponent("KadoDev.sqlite")
        }
        return URL.applicationSupportDirectory.appendingPathComponent("KadoDev.sqlite")
    }

    /// Copy the sqlite + sidecars from `legacy` to `target` if a
    /// legacy file exists and `target` is still absent. The legacy
    /// file is *copied*, not moved, so a bad migration doesn't
    /// destroy user data.
    static func migrateLegacyStoreIfNeeded(from legacy: URL, to target: URL) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: legacy.path) else { return }
        guard !fm.fileExists(atPath: target.path) else { return }
        try? fm.createDirectory(
            at: target.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        for suffix in ["", "-shm", "-wal"] {
            let src = URL(fileURLWithPath: legacy.path + suffix)
            let dst = URL(fileURLWithPath: target.path + suffix)
            if fm.fileExists(atPath: src.path) {
                try? fm.copyItem(at: src, to: dst)
            }
        }
    }

    /// Build the production `ModelContainer`. Uses the App Group
    /// URL when available (and migrates any legacy store across),
    /// otherwise falls back to SwiftData's default location so the
    /// app still launches without the entitlement.
    ///
    /// Both the main app and the widget extension must be signed
    /// with the iCloud CloudKit capability on the same container
    /// identifier so they can open this store with identical
    /// configuration — opening a CloudKit-attached SQLite with
    /// `cloudKitDatabase: .none` traps at the first fetch because
    /// the on-disk metadata tables don't match.
    static func productionContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: KadoSchemaV2.self)
        let configuration: ModelConfiguration
        if let target = productionStoreURL() {
            migrateLegacyStoreIfNeeded(from: legacyStoreURL(), to: target)
            configuration = ModelConfiguration(
                schema: schema,
                url: target,
                cloudKitDatabase: .private(CloudContainerID.kado)
            )
        } else {
            configuration = ModelConfiguration(
                schema: schema,
                cloudKitDatabase: .private(CloudContainerID.kado)
            )
        }
        return try ModelContainer(
            for: schema,
            migrationPlan: KadoMigrationPlan.self,
            configurations: configuration
        )
    }
}
