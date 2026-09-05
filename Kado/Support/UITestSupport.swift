#if DEBUG
import Foundation
import SwiftData
import KadoCore

/// Test-only hooks, compiled out of release builds.
///
/// UI tests need to control what the app starts from: which store is
/// mounted, and whether it has anything in it. Everything is driven by
/// launch arguments, so the app itself has no idea it is under test.
///
/// **The dev-mode flag cannot be set with `-kado.devMode 1`**, tempting
/// as that is — it does land in `UserDefaults`' argument domain and the
/// app does start in dev mode, but the argument domain also *outranks*
/// every stored value, so the write `@AppStorage` makes when the user
/// flips the toggle is read straight back as the launch value. The
/// toggle springs on again, and the container swap these tests exist to
/// exercise never happens. So the starting state is written into the
/// App Group suite here instead, from inside the app, where the toggle
/// can still move it afterwards.
///
/// What also needs hooks is the data underneath. The production store
/// is CloudKit-mirrored, so a suite that seeded it on a simulator signed
/// into a real iCloud account would push demo habits to the developer's
/// own devices. Under `-uiTestRun` both stores are therefore redirected
/// to throwaway files and the production one drops CloudKit: the suite
/// never opens, seeds or deletes anything the developer owns, and never
/// reaches the network. The crash these tests exist to catch is a
/// SwiftUI/SwiftData container-swap problem with nothing to do with
/// sync, so nothing under test is lost by cutting it out.
nonisolated enum UITestSupport {

    enum Argument {
        /// Present on every launch a UI test makes. It is what redirects
        /// both stores away from the developer's real ones, so it must
        /// be passed even by a test that seeds nothing.
        static let uiTestRun = "-uiTestRun"
        /// Delete both throwaway stores, so runs don't inherit each
        /// other.
        static let resetState = "-uiTestResetState"
        /// Seed the (redirected) production store with the demo dataset.
        ///
        /// Needed for the dev-mode swap tests: they start in dev mode
        /// and toggle *off*, and an empty production store would land
        /// the Today list on its empty state, replacing the list rather
        /// than diffing it — and the diff is where the crash lives.
        static let seedProduction = "-uiTestSeedProduction"
        /// Seed with `ScreenshotSeed` instead of `DevModeSeed`.
        ///
        /// Passed alongside `seedProduction` by the screenshot run and
        /// by nothing else. The two datasets exist for opposite
        /// reasons — see the note at the top of `ScreenshotSeed`.
        static let seedForScreenshots = "-uiTestSeedForScreenshots"
        /// `1` to start in dev mode, `0` to start on the real store.
        /// Followed by its value. See the note at the top of this file
        /// for why this is not just `-kado.devMode`.
        static let devMode = "-uiTestDevMode"
        /// `1` to start past the first-activation confirmation alert.
        static let devModeConfirmed = "-uiTestDevModeConfirmed"
        /// Leave the New Habit sheet's name field unfocused.
        ///
        /// Only the screenshot run passes this. A keyboard is the
        /// right thing for a real user — it is the wrong thing for a
        /// listing image, where it covers the frequency and type
        /// options the shot exists to show.
        static let suppressNameAutoFocus = "-uiTestSuppressNameAutoFocus"
    }

    /// Whether the New Habit sheet should skip focusing its name field.
    static var suppressesNameAutoFocus: Bool {
        isRunningUITests
            && ProcessInfo.processInfo.arguments.contains(Argument.suppressNameAutoFocus)
    }

    /// Whether the app is being driven by the UI suite.
    static var isRunningUITests: Bool {
        ProcessInfo.processInfo.arguments.contains(Argument.uiTestRun)
    }

    /// Call before anything opens a `ModelContainer` or reads the
    /// dev-mode flag.
    static func applyLaunchArguments() {
        guard isRunningUITests else { return }
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains(Argument.resetState) {
            resetState()
        }
        // Written unconditionally, so a run never inherits the flag the
        // last one left in the shared suite.
        DevModeDefaults.sharedDefaults.set(
            flag(Argument.devMode, in: arguments), forKey: DevModeDefaults.key
        )
        DevModeDefaults.sharedDefaults.set(
            flag(Argument.devModeConfirmed, in: arguments),
            forKey: DevModeDefaults.hasConfirmedKey
        )
    }

    private static func flag(_ argument: String, in arguments: [String]) -> Bool {
        guard let index = arguments.firstIndex(of: argument),
              arguments.indices.contains(index + 1)
        else { return false }
        return arguments[index + 1] == "1"
    }

    // MARK: - Redirected stores

    /// Where the suite's stand-in for the production store lives.
    /// Deliberately *not* `SharedStore.productionStoreURL()` — the real
    /// file is never opened or deleted by a test run.
    static func productionStoreURL() -> URL {
        base().appendingPathComponent("KadoUITest.sqlite")
    }

    /// Where the suite's stand-in for the dev sandbox lives, so a run
    /// can't wipe the sandbox the developer was using.
    static func devStoreURL() -> URL {
        base().appendingPathComponent("KadoUITestDev.sqlite")
    }

    private static func base() -> URL {
        let root = SharedStore.appGroupContainerURL()
            .map { $0.appendingPathComponent("Library/Application Support", isDirectory: true) }
            ?? URL.applicationSupportDirectory
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    /// The container `DevModeController` should mount in place of the
    /// production one, or nil on a normal launch.
    ///
    /// Local-only: see the note at the top of this file. Same schema and
    /// same migration plan as the real thing, so everything the app does
    /// with it is unchanged.
    static func productionContainerOverride() -> ModelContainer? {
        guard isRunningUITests else { return nil }
        let schema = Schema(versionedSchema: KadoSchemaV4.self)
        let configuration = ModelConfiguration(
            schema: schema,
            url: productionStoreURL(),
            cloudKitDatabase: .none
        )
        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: KadoMigrationPlan.self,
                configurations: configuration
            )
        } catch {
            fatalError("Failed to construct the UI-test production ModelContainer: \(error)")
        }
    }

    /// Fills the (redirected) production store with the demo dataset if
    /// this run asked for it and it is still empty.
    ///
    /// Goes through the container the app already built rather than
    /// opening one of its own — two containers over one store is the
    /// shape that traps with `NSCocoaErrorDomain 134422`.
    @MainActor
    static func seedProductionIfRequested(using container: ModelContainer) {
        guard isRunningUITests,
              ProcessInfo.processInfo.arguments.contains(Argument.seedProduction)
        else { return }
        let context = container.mainContext
        let count = (try? context.fetchCount(FetchDescriptor<HabitRecord>())) ?? 0
        guard count == 0 else { return }
        if ProcessInfo.processInfo.arguments.contains(Argument.seedForScreenshots) {
            ScreenshotSeed.seed(into: context)
        } else {
            DevModeSeed.seed(into: context)
        }
    }

    private static func resetState() {
        for url in [productionStoreURL(), devStoreURL()] {
            // SwiftData writes `<name>.sqlite` plus `-shm` / `-wal` siblings.
            for suffix in ["", "-shm", "-wal"] {
                try? FileManager.default.removeItem(
                    at: URL(fileURLWithPath: url.path + suffix)
                )
            }
        }
    }
}
#else
/// Release stand-in, carrying only the members production code reads.
///
/// `NewHabitFormView` asks whether to focus its name field on every
/// launch, test run or not, and a `#if DEBUG` around the call site
/// would put a compile-time conditional inside a view body. One here
/// keeps the view unconditional and the answer constant in release.
nonisolated enum UITestSupport {
    static var suppressesNameAutoFocus: Bool { false }
}
#endif
