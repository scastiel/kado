import Testing
@testable import Kado
import KadoCore

@Suite("HabitIcon catalog")
struct HabitIconTests {
    @Test("Curated list has no duplicate symbol names")
    func noDuplicates() {
        #expect(Set(HabitIcon.curated).count == HabitIcon.curated.count)
    }

    @Test("Curated list has at least 20 entries")
    func minimumSize() {
        #expect(HabitIcon.curated.count >= 20)
    }
}
