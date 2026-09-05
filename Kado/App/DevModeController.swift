import Foundation
import SwiftData
import KadoCore

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

    /// Wipe any previous sandbox on disk. Call this on every off→on
    /// transition. The fresh container is built lazily on next
    /// `container(forDevMode: true)` and seeded because the file is
    /// now absent.
    func activateDevMode() {
        cachedDevContainer = nil
        deleteDevStoreFiles()
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
        seedIfEmpty(container)
        cachedDevContainer = container
        return container
    }

    private func seedIfEmpty(_ container: ModelContainer) {
        let context = container.mainContext
        let count = (try? context.fetchCount(FetchDescriptor<HabitRecord>())) ?? 0
        if count == 0 {
            DevModeSeed.seed(into: context)
        }
    }

    private func buildDevContainer() -> ModelContainer {
        ensureParentDirectoryExists(for: devStoreURL)
        do {
            return try makeDevContainer()
        } catch {
            // Dev sandbox is disposable — if SwiftData can't open the
            // file (e.g. stale schema from an older schema version that
            // pre-dates the current migration plan), wipe and rebuild
            // empty. A production container does NOT get this
            // treatment; user data is never silently discarded.
            deleteDevStoreFiles()
            do {
                return try makeDevContainer()
            } catch {
                fatalError("Failed to construct dev ModelContainer after wipe: \(error)")
            }
        }
    }

    private func makeDevContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: KadoSchemaV4.self)
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
    }

    private func deleteDevStoreFiles() {
        let fm = FileManager.default
        let directory = devStoreURL.deletingLastPathComponent()
        let base = devStoreURL.deletingPathExtension().lastPathComponent
        let ext = devStoreURL.pathExtension
        // SwiftData writes `<name>.<ext>`, `<name>.<ext>-shm`, `<name>.<ext>-wal`.
        for suffix in ["", "-shm", "-wal"] {
            let url = directory.appendingPathComponent("\(base).\(ext)\(suffix)")
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

    nonisolated static var defaultDevStoreURL: URL {
        #if DEBUG
        if UITestSupport.isRunningUITests { return UITestSupport.devStoreURL() }
        #endif
        return SharedStore.devStoreURL()
    }

    nonisolated static func defaultProductionContainer() -> ModelContainer {
        #if DEBUG
        // A UI test gets a local-only stand-in, so a run can never write
        // demo habits into a real iCloud account. See `UITestSupport`.
        if let override = UITestSupport.productionContainerOverride() { return override }
        #endif
        do {
            return try SharedStore.productionContainer()
        } catch {
            fatalError("Failed to construct production ModelContainer: \(error)")
        }
    }

    #if DEBUG
    /// The production container, built now if it hasn't been yet.
    ///
    /// The UI-test seeding hook needs to fill the production store while
    /// the *dev* store is the one mounted, and it must not open a
    /// container of its own to do it — going through the same cache the
    /// app mounts from is what keeps it to one instance per store.
    func productionContainerForUITests() -> ModelContainer { productionContainer() }
    #endif
}
