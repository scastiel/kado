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
}
