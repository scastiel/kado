import AppIntents
import KadoCore

/// Registers KadoCore's App Intents with the widget extension.
///
/// This is the one that matters most: the extension is where a placed
/// widget's stored configuration is decoded back into entities, and
/// without the registration that decode fails silently and every
/// configurable widget renders as though nothing had been picked. See
/// `KadoCoreAppIntentsPackage`.
struct KadoWidgetsAppIntentsPackage: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] {
        [KadoCoreAppIntentsPackage.self]
    }
}
