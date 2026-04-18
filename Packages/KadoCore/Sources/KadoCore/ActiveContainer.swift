import Foundation
import SwiftData

/// Process-scoped reference to the currently active SwiftData
/// `ModelContainer`. Exists so an `AppIntent` running in the main
/// app process can reuse the same container the root view's
/// `.modelContainer(_:)` modifier already holds — opening a second
/// CloudKit-attached container in the same process traps with
/// `NSCocoaErrorDomain 134422` ("another instance of this persistent
/// store actively syncing with CloudKit").
///
/// The app primes the cache whenever it hands a container to
/// SwiftUI (including after a dev-mode swap). The intent reads the
/// cached instance; if the cache is unexpectedly empty (e.g. an
/// intent fires before the app has fully launched — unlikely since
/// `openAppWhenRun = true`) it falls back to a freshly-built
/// production container and memoizes that.
@MainActor
public final class ActiveContainer {
    public static let shared = ActiveContainer()

    private var container: ModelContainer?

    private init() {}

    /// Called by the app side after constructing a container. Safe
    /// to call repeatedly; the most recent value wins.
    public func set(_ container: ModelContainer) {
        self.container = container
    }

    /// Current container. Lazily builds a production container on
    /// first access if the app hasn't primed the cache yet.
    public func get() throws -> ModelContainer {
        if let container { return container }
        let built = try SharedStore.productionContainer()
        self.container = built
        return built
    }
}
