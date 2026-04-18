import Testing
@testable import Kado

@Suite("HabitColor palette")
struct HabitColorTests {
    @Test("Palette exposes eight distinct cases")
    func paletteSize() {
        #expect(HabitColor.allCases.count == 8)
        #expect(Set(HabitColor.allCases).count == 8)
    }

    @Test("Raw values match case names (stable for migration)")
    func rawValuesStable() {
        let expected: [(HabitColor, String)] = [
            (.red, "red"),
            (.orange, "orange"),
            (.yellow, "yellow"),
            (.green, "green"),
            (.mint, "mint"),
            (.teal, "teal"),
            (.blue, "blue"),
            (.purple, "purple"),
        ]
        for (value, raw) in expected {
            #expect(value.rawValue == raw)
        }
    }
}
