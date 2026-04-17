import Foundation
import Observation
import SwiftData

/// Owns the two `ModelContainer`s the app can run against: the
/// production CloudKit-backed store and an on-disk dev sandbox.
///
/// The root view reads `container(forDevMode:)` and hands the result
/// to `.modelContainer(...)`. Activating dev mode wipes the sandbox
/// file and reseeds it; deactivating simply drops the dev container
/// reference — the sandbox file stays on disk but is ignored.
///
/// The production factory and sandbox URL are injectable so tests
/// can exercise the lifecycle without touching CloudKit or the real
/// Application Support directory.
@MainActor
@Observable
final class DevModeController {
    private let devStoreURL: URL
    private let productionContainerFactory: () -> ModelContainer

    private var cachedProductionContainer: ModelContainer?
    private var cachedDevContainer: ModelContainer?

    init(
        devStoreURL: URL = DevModeController.defaultDevStoreURL,
        productionContainerFactory: @escaping () -> ModelContainer = DevModeController.defaultProductionContainer
    ) {
        self.devStoreURL = devStoreURL
        self.productionContainerFactory = productionContainerFactory
    }

    func container(forDevMode enabled: Bool) -> ModelContainer {
        enabled ? devContainer() : productionContainer()
    }

    /// Wipe any previous sandbox, build a fresh dev container, seed
    /// it. Call this on every off→on transition.
    func activateDevMode() {
        cachedDevContainer = nil
        deleteDevStoreFiles()
        let fresh = buildDevContainer()
        DevModeSeed.seed(into: fresh.mainContext)
        cachedDevContainer = fresh
    }

    /// Drop the dev container reference. The sandbox file is left on
    /// disk (it will be wiped on the next `activateDevMode()`).
    func deactivateDevMode() {
        cachedDevContainer = nil
    }

    private func productionContainer() -> ModelContainer {
        if let cachedProductionContainer { return cachedProductionContainer }
        let container = productionContainerFactory()
        cachedProductionContainer = container
        return container
    }

    private func devContainer() -> ModelContainer {
        if let cachedDevContainer { return cachedDevContainer }
        let container = buildDevContainer()
        cachedDevContainer = container
        return container
    }

    private func buildDevContainer() -> ModelContainer {
        ensureParentDirectoryExists(for: devStoreURL)
        do {
            let schema = Schema(versionedSchema: KadoSchemaV1.self)
            let configuration = ModelConfiguration(
                schema: schema,
                url: devStoreURL,
                cloudKitDatabase: .none
            )
            return try ModelContainer(
                for: schema,
                migrationPlan: KadoMigrationPlan.self,
                configurations: configuration
            )
        } catch {
            fatalError("Failed to construct dev ModelContainer: \(error)")
        }
    }

    private func deleteDevStoreFiles() {
        let fm = FileManager.default
        let base = devStoreURL.deletingPathExtension().lastPathComponent
        let directory = devStoreURL.deletingLastPathComponent()
        // SwiftData writes `<name>.sqlite`, `<name>.sqlite-shm`, `<name>.sqlite-wal`.
        for suffix in ["sqlite", "sqlite-shm", "sqlite-wal"] {
            let url = directory.appendingPathComponent("\(base).\(suffix)")
            try? fm.removeItem(at: url)
        }
    }

    private func ensureParentDirectoryExists(for url: URL) {
        let directory = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
    }

    nonisolated static let defaultDevStoreURL: URL = {
        URL.applicationSupportDirectory.appendingPathComponent("KadoDev.sqlite")
    }()

    nonisolated static func defaultProductionContainer() -> ModelContainer {
        do {
            let schema = Schema(versionedSchema: KadoSchemaV1.self)
            return try ModelContainer(
                for: schema,
                migrationPlan: KadoMigrationPlan.self,
                configurations: ModelConfiguration(
                    schema: schema,
                    cloudKitDatabase: .private(CloudContainerID.kado)
                )
            )
        } catch {
            fatalError("Failed to construct production ModelContainer: \(error)")
        }
    }
}
