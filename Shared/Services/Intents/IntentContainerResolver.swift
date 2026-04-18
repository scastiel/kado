import Foundation
import SwiftData

/// Resolves the `ModelContainer` an `AppIntent` should read/write
/// against. Lives outside `DevModeController` because intents run
/// in whichever process happens to host them (main app foreground
/// or widget extension) and can't reach the MainActor-isolated
/// controller from a nonisolated context.
///
/// Reads the dev-mode flag from the shared UserDefaults suite so
/// the intent swaps stores in lockstep with the app.
nonisolated enum IntentContainerResolver {
    /// Build the container for the current process. The caller
    /// decides whether to cache the result; most widgets / intents
    /// construct it once per timeline reload and drop it, so this
    /// stays stateless.
    static func sharedContainer() throws -> ModelContainer {
        let isDev = DevModeDefaults.sharedDefaults.bool(forKey: DevModeDefaults.key)
        return isDev ? try devContainer() : try SharedStore.productionContainer()
    }

    private static func devContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: KadoSchemaV2.self)
        return try ModelContainer(
            for: schema,
            migrationPlan: KadoMigrationPlan.self,
            configurations: ModelConfiguration(
                schema: schema,
                url: SharedStore.devStoreURL(),
                cloudKitDatabase: .none
            )
        )
    }
}
