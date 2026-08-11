import SwiftData
import SwiftUI
import KadoCore

@main
struct KadoApp: App {
    @AppStorage(DevModeDefaults.key, store: DevModeDefaults.sharedDefaults) private var isDevMode = false
    @AppStorage(DayStartDefaults.key, store: DayStartDefaults.sharedDefaults)
    private var dayStartHour = DayStartDefaults.defaultHour
    @Environment(\.scenePhase) private var scenePhase

    @State private var devModeController = DevModeController()
    @State private var cloudAccountStatus = DefaultCloudAccountStatusObserver()
    @State private var notificationScheduler: any NotificationScheduling
    @State private var notificationManager: NotificationManager
    @State private var tipJarStore = DefaultTipJarStore()

    /// Raw wall-clock marker, bumped whenever the logical day may have
    /// changed. `\.today` is *derived* from it rather than stored, so
    /// changing the "Day starts at" hour re-resolves the current day
    /// immediately without needing its own invalidation path.
    @State private var clockMark: Date = .now

    /// Rebuilt on every `body` evaluation, so it always reflects the
    /// live `dayStartHour`.
    private var dayBoundary: DayBoundary {
        DayBoundary(calendar: .current, startHour: DayStartDefaults.clamp(dayStartHour))
    }

    init() {
        DevModeDefaults.migrateFromStandardIfNeeded()
        KadoFont.register()
        let scheduler = DefaultNotificationScheduler(center: LiveUserNotificationCenter())
        _notificationScheduler = State(initialValue: scheduler)
        _notificationManager = State(initialValue: NotificationManager(scheduler: scheduler))
    }

    var body: some Scene {
        let boundary = dayBoundary
        let container = devModeController.container(forDevMode: isDevMode)
        // Publish the active container to the process-scoped cache
        // so `CompleteHabitIntent` (running in-app via
        // `openAppWhenRun`) reuses the same instance instead of
        // opening a second CloudKit-attached one.
        ActiveContainer.shared.set(container)
        ActiveScheduler.shared.set(notificationScheduler)

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
                    // Seed pending notifications at launch so a user
                    // who installed yesterday and never opened the
                    // app still gets today's reminder.
                    RemindersSync.rescheduleAll(using: container.mainContext)
                }
                .task(id: RolloverTick(day: boundary.startOfDay(for: clockMark), hour: boundary.startHour)) {
                    await advanceAtRollover(boundary, in: container)
                }
        }
        .modelContainer(container)
        .environment(\.cloudAccountStatus, cloudAccountStatus)
        .environment(\.notificationScheduler, notificationScheduler)
        .environment(\.tipJarStore, tipJarStore)
        .environment(\.today, boundary.startOfDay(for: clockMark))
        .environment(\.dayBoundary, boundary)
        .onChange(of: scenePhase) { _, newPhase in
            // Reconciles the pending set every time the app comes
            // to the foreground — handles clock-drift, day-rollover,
            // and cases where a background reminder fired while
            // the app was suspended.
            if newPhase == .active {
                RemindersSync.rescheduleAll(using: container.mainContext)
                if !boundary.isDate(clockMark, inSameDayAs: .now) {
                    clockMark = .now
                }
            }
        }
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

    /// Identity for the rollover task: restarting it whenever either
    /// the current logical day or the chosen hour changes is what
    /// reschedules the next tick.
    private struct RolloverTick: Equatable {
        let day: Date
        let hour: Int
    }

    /// Advances the app's notion of "today" the moment the day rolls
    /// over, without waiting for a backgrounding round-trip.
    ///
    /// Needed rather than nice-to-have: Today's pre-rollover caption
    /// promises "rolls over at 04:00", so leaving it on screen at 04:01
    /// would make the app contradict itself. Bumping `clockMark`
    /// re-derives `\.today`, which changes this task's id and schedules
    /// the following day's tick.
    @MainActor
    private func advanceAtRollover(_ boundary: DayBoundary, in container: ModelContainer) async {
        let delay = boundary.nextRollover(after: .now).timeIntervalSinceNow
        if delay > 0 {
            // Throws on cancellation — which is exactly what happens
            // when the hour setting changes and the task restarts.
            guard (try? await Task.sleep(for: .seconds(delay))) != nil else { return }
        }
        clockMark = .now
        // The widget snapshot and the reminder window are both anchored
        // to a day that has just changed; leaving them until the next
        // mutation would let the widget disagree with the app.
        WidgetSnapshotBuilder.rebuildAndWrite(using: container.mainContext)
        RemindersSync.rescheduleAll(using: container.mainContext)
    }
}
