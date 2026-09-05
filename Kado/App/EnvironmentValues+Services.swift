import SwiftUI
import KadoCore

// MARK: - Service injection via SwiftUI Environment
//
// This file is the single registry for every service exposed through
// SwiftUI's `Environment`. The convention, matching `CLAUDE.md`'s
// architecture section:
//
//   1. Define a protocol for the capability, e.g. `HabitScoreCalculating`.
//   2. Provide a default production implementation.
//   3. Declare an `EnvironmentKey` whose `defaultValue` is that
//      implementation.
//   4. Add a computed property below to `EnvironmentValues`.
//   5. Use it in views with `@Environment(\.habitScoreCalculator)`.
//   6. Inject mocks in tests by overriding the key with `.environment(...)`.
//
private struct HabitScoreCalculatorKey: EnvironmentKey {
    static let defaultValue: any HabitScoreCalculating = DefaultHabitScoreCalculator()
}

private struct FrequencyEvaluatorKey: EnvironmentKey {
    static let defaultValue: any FrequencyEvaluating = DefaultFrequencyEvaluator()
}

private struct StreakCalculatorKey: EnvironmentKey {
    static let defaultValue: any StreakCalculating = DefaultStreakCalculator()
}

extension EnvironmentValues {
    var habitScoreCalculator: any HabitScoreCalculating {
        get { self[HabitScoreCalculatorKey.self] }
        set { self[HabitScoreCalculatorKey.self] = newValue }
    }

    var frequencyEvaluator: any FrequencyEvaluating {
        get { self[FrequencyEvaluatorKey.self] }
        set { self[FrequencyEvaluatorKey.self] = newValue }
    }

    var streakCalculator: any StreakCalculating {
        get { self[StreakCalculatorKey.self] }
        set { self[StreakCalculatorKey.self] = newValue }
    }

    /// Current CloudKit account status, re-observed on `.CKAccountChanged`.
    /// Uses `@Entry` rather than a hand-rolled `EnvironmentKey` because
    /// the backing observer is `@MainActor`-isolated and the legacy
    /// static-default pattern doesn't cross actors cleanly. Default is
    /// a mock so previews that forget to inject don't crash.
    @Entry var cloudAccountStatus: any CloudAccountStatusObserving = MockCloudAccountStatusObserver()

    /// Reminder notification scheduler. Default is a mock so previews
    /// and unit tests never hit `UNUserNotificationCenter`; the main
    /// app injects `DefaultNotificationScheduler(center: LiveUserNotificationCenter())`
    /// at scene build.
    @Entry var notificationScheduler: any NotificationScheduling = MockNotificationScheduler()

    /// Serializes the live SwiftData store into a `BackupDocument` for
    /// the Settings → Export flow. Uses `@Entry` because the default
    /// is `@MainActor`-isolated.
    @Entry var backupExporter: any BackupExporting = DefaultBackupExporter()

    /// Parses a `BackupDocument` and merges it into the live store for
    /// the Settings → Import flow.
    @Entry var backupImporter: any BackupImporting = DefaultBackupImporter()

    /// Day-granular "now" driven by the scene lifecycle. `KadoApp` bumps
    /// this on every `scenePhase → .active` transition where the logical
    /// day has changed, and again when the day rolls over while the app
    /// is foregrounded, so views that read it re-evaluate their body on
    /// the new day without needing a relaunch. Views should read this
    /// instead of `.now` for any day-boundary decision (what's due today,
    /// where the overview's trailing edge lands).
    ///
    /// This is the **logical** day's midnight, not wall-clock now — it
    /// already has the user's "Day starts at" hour applied. Pair it with
    /// `\.dayBoundary` when you need to compare or write dates.
    @Entry var today: Date = .now

    /// Resolves which logical day an instant belongs to, honouring the
    /// user's "Day starts at" preference. Read this instead of
    /// `\.calendar` for any *day* question — `calendar.startOfDay`,
    /// `isDate(_:inSameDayAs:)` and `isDateInToday` all assume a
    /// midnight boundary. `\.calendar` is still the right tool for
    /// formatters and for bucketing an already-stored completion date.
    @Entry var dayBoundary: DayBoundary = DayBoundary()

    @Entry var reviewPromptService: any ReviewPrompting = DefaultReviewPromptService()

    /// Gates the tip nudge at the bottom of Today — how long the app
    /// has been in use, whether the user dismissed it, whether they
    /// already tipped. The default reads the real `UserDefaults`;
    /// previews and tests inject a stub to pin the answer.
    @Entry var tipNudge: any TipNudging = DefaultTipNudgeService()

    /// Loads the tip products and runs purchases for the Tip Jar. Default
    /// is a mock so previews and unit tests never touch StoreKit; the
    /// main app injects `DefaultTipJarStore(tipNudge:)` at scene build.
    @Entry var tipJarStore: any TipJarStoring = MockTipJarStore()
}
