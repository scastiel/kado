import SwiftData
import SwiftUI
import KadoCore

@main
struct KadoApp: App {
    @AppStorage(DevModeDefaults.key, store: DevModeDefaults.sharedDefaults) private var isDevMode = false

    @State private var devModeController = DevModeController()
    @State private var cloudAccountStatus = DefaultCloudAccountStatusObserver()
    @State private var notificationScheduler: any NotificationScheduling = DefaultNotificationScheduler(center: LiveUserNotificationCenter())
    @State private var notificationManager: NotificationManager

    init() {
        DevModeDefaults.migrateFromStandardIfNeeded()
        let scheduler = DefaultNotificationScheduler(center: LiveUserNotificationCenter())
        _notificationScheduler = State(initialValue: scheduler)
        _notificationManager = State(initialValue: NotificationManager(scheduler: scheduler))
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
                .task {
                    await notificationManager.configure()
                }
        }
        .modelContainer(container)
        .environment(\.cloudAccountStatus, cloudAccountStatus)
        .environment(\.notificationScheduler, notificationScheduler)
        .onChange(of: isDevMode) { oldValue, newValue in
            if newValue && !oldValue {
                devModeController.activateDevMode()
            } else if !newValue && oldValue {
                devModeController.deactivateDevMode()
            }
            let swapped = devModeController.container(forDevMode: newValue)
            ActiveContainer.shared.set(swapped)
            // Widgets read a JSON snapshot, not the live SwiftData
            // store. Without this the widget keeps showing the
            // previous dataset (dev vs production) until the next
            // habit mutation triggers `WidgetReloader.reloadAll`.
            WidgetReloader.reloadAll(using: swapped.mainContext)
        }
    }
}
