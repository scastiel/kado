import AppIntents
import KadoCore

/// Registers KadoCore's App Intents with the app.
///
/// Kadō's intents and entities all live in the `KadoCore` package, and
/// a target that links them has to say so here or they are not
/// registered at runtime. See `KadoCoreAppIntentsPackage` for what
/// silently breaks without it.
struct KadoAppIntentsPackage: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] {
        [KadoCoreAppIntentsPackage.self]
    }
}
