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
                .task(id: RolloverTick(mark: clockMark, hour: boundary.startHour)) {
                    await advanceAtNextDayEdge(boundary)
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
        .onChange(of: dayStartHour) { _, _ in
            // `\.today` re-derives itself from the new boundary, but the
            // widget renders a snapshot the app wrote under the old one.
            // Without this the home screen keeps yesterday's (or
            // tomorrow's) day until the next habit mutation.
            WidgetReloader.reloadAll(using: container.mainContext)
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

    /// Identity for the day-edge task. Keyed on `clockMark` itself
    /// rather than the derived logical day, because one of the two
    /// edges — wall-clock midnight — deliberately leaves the logical
    /// day unchanged, and a task keyed on the logical day would finish
    /// without ever rescheduling itself.
    private struct RolloverTick: Equatable {
        let mark: Date
        let hour: Int
    }

    /// The next instant at which something the UI renders changes:
    /// either the day rolls over, or the wall clock passes midnight and
    /// Today's "still yesterday" caption becomes due.
    ///
    /// Under the default midnight hour the two coincide, so this is
    /// just the next midnight.
    private func nextDayEdge(_ boundary: DayBoundary, after now: Date) -> Date {
        let calendar = boundary.calendar
        let rollover = boundary.nextRollover(after: now)
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) else {
            return rollover
        }
        return min(rollover, calendar.startOfDay(for: tomorrow))
    }

    /// Advances the app's notion of "today" at the next day edge,
    /// without waiting for a backgrounding round-trip.
    ///
    /// Needed rather than nice-to-have in both directions: Today's
    /// caption promises "rolls over at 04:00", so leaving it up at
    /// 04:01 makes the app contradict itself — and the caption also has
    /// to *appear* at midnight, which is otherwise an instant when
    /// nothing in the view's inputs changes and SwiftUI has no reason
    /// to re-render. Bumping `clockMark` restarts this task, which
    /// schedules the following edge.
    @MainActor
    private func advanceAtNextDayEdge(_ boundary: DayBoundary) async {
        let delay = nextDayEdge(boundary, after: .now).timeIntervalSinceNow
        if delay > 0 {
            // Throws on cancellation — which is exactly what happens
            // when the hour setting changes and the task restarts.
            guard (try? await Task.sleep(for: .seconds(delay))) != nil else { return }
        }
        clockMark = .now
        // Read the container from the process-scoped cache rather than
        // capturing it: a dev-mode swap replaces the container without
        // changing this task's id, so a captured one would go stale and
        // write production data over the dev snapshot.
        guard let container = try? ActiveContainer.shared.get() else { return }
        // Full reload, not just `rebuildAndWrite` — the snapshot is
        // anchored to a day that just changed, and without the timeline
        // reload WidgetKit keeps rendering the old JSON for up to an
        // hour, which is precisely the disagreement this exists to stop.
        WidgetReloader.reloadAll(using: container.mainContext)
    }
}
