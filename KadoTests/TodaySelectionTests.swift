import Foundation
import Testing
@testable import Kado
import KadoCore

/// Which habit the regular-width Today shows beside its list
/// (issue #140). The detail column is never empty and never shows a
/// habit the list has dropped, whatever happened to the one picked.
@Suite("TodayRow.selection")
struct TodaySelectionTests {
    private func row(_ name: String) -> TodayRow {
        TodayRow(
            habit: Habit(name: name, frequency: .daily, type: .binary, createdAt: .distantPast),
            completions: []
        )
    }

    @Test("Nothing picked yet shows the first scheduled habit")
    func nothingPickedShowsFirstDue() {
        let due = [row("Read"), row("Run")]
        let other = [row("Gym")]
        #expect(TodayRow.selection(picked: nil, due: due, other: other) == due[0].id)
    }

    @Test("Nothing scheduled today shows the first unscheduled habit")
    func nothingDueShowsFirstOther() {
        let other = [row("Gym"), row("Swim")]
        #expect(TodayRow.selection(picked: nil, due: [], other: other) == other[0].id)
    }

    @Test("A picked habit still listed stays shown, in either section")
    func pickedHabitIsKept() {
        let due = [row("Read"), row("Run")]
        let other = [row("Gym")]
        #expect(TodayRow.selection(picked: due[1].id, due: due, other: other) == due[1].id)
        #expect(TodayRow.selection(picked: other[0].id, due: due, other: other) == other[0].id)
    }

    @Test("A picked habit that left the list falls back to the first row")
    func pickedHabitGoneFallsBack() {
        let due = [row("Read"), row("Run")]
        let archived = row("Archived")
        #expect(TodayRow.selection(picked: archived.id, due: due, other: []) == due[0].id)
    }

    @Test("An empty list selects nothing")
    func emptyListSelectsNothing() {
        #expect(TodayRow.selection(picked: UUID(), due: [], other: []) == nil)
    }
}
