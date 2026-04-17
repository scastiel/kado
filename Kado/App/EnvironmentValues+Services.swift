import SwiftUI

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

extension EnvironmentValues {
    var habitScoreCalculator: any HabitScoreCalculating {
        get { self[HabitScoreCalculatorKey.self] }
        set { self[HabitScoreCalculatorKey.self] = newValue }
    }
}
