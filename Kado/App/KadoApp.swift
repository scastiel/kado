import SwiftData
import SwiftUI
import KadoCore

@main
struct KadoApp: App {
    @AppStorage(DevModeDefaults.key, store: DevModeDefaults.sharedDefaults) private var isDevMode = false

    @State private var devModeController = DevModeController()
    @State private var cloudAccountStatus = DefaultCloudAccountStatusObserver()

    init() {
        DevModeDefaults.migrateFromStandardIfNeeded()
    }

    var body: some Scene {
        let container = devModeController.container(forDevMode: isDevMode)
        // Publish the active container to the process-scoped cache
        // so `CompleteHabitIntent` (running in-app via
        // `openAppWhenRun`) reuses the same instance instead of
        // opening a second CloudKit-attached one.
        ActiveContainer.shared.set(container)

        return WindowGroup {
            ContentView()
                .task { await cloudAccountStatus.refresh() }
                .task {
                    // Seed the widget's App Group JSON snapshot at
                    // launch so widgets have fresh data even if the
                    // user hasn't mutated anything since install.
                    WidgetSnapshotBuilder.rebuildAndWrite(using: container.mainContext)
                }
        }
        .modelContainer(container)
        .environment(\.cloudAccountStatus, cloudAccountStatus)
        .onChange(of: isDevMode) { oldValue, newValue in
            if newValue && !oldValue {
                devModeController.activateDevMode()
            } else if !newValue && oldValue {
                devModeController.deactivateDevMode()
            }
            ActiveContainer.shared.set(devModeController.container(forDevMode: newValue))
        }
    }
}
