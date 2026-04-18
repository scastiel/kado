import Testing
import SwiftUI
@testable import Kado
import KadoCore

@Suite("EnvironmentValues service registration")
struct EnvironmentValuesServicesTests {
    @Test("Default habitScoreCalculator is a DefaultHabitScoreCalculator")
    func defaultCalculatorRegistered() {
        let env = EnvironmentValues()
        #expect(env.habitScoreCalculator is DefaultHabitScoreCalculator)
    }
}
