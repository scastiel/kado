import Foundation
import Testing
@testable import Kado
import KadoCore

/// Presentation contracts for the "Week starts on" picker.
@Suite("Week-start presentation")
@MainActor
struct WeekStartPresentationTests {
    private func calendar(firstWeekday: Int) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = firstWeekday
        return calendar
    }

    @Test("Every offerable option has a distinct, non-empty label")
    func labelsAreDistinct() {
        let labels = WeekStart.allCases.map {
            WeekStartLabel.text(for: $0, localeCalendar: calendar(firstWeekday: 2))
        }

        #expect(labels.allSatisfy { !$0.isEmpty })
        #expect(Set(labels).count == labels.count)
    }

    @Test("A pinned option is named by its day")
    func pinnedOptionsAreNamedByTheirDay() {
        for option in WeekStart.allCases {
            guard let weekday = option.weekday else { continue }
            #expect(WeekStartLabel.text(for: option) == weekday.localizedFull)
        }
    }

    /// The Automatic row has to describe the *region*, not the current
    /// choice — reading it off the environment calendar (which already
    /// has the user's pick applied) would make it read
    /// "Automatic (Monday)" for someone in a Sunday region who pinned
    /// Monday.
    @Test("Automatic names the region's day")
    func automaticNamesTheRegionDay() {
        let sunday = WeekStartLabel.text(for: .automatic, localeCalendar: calendar(firstWeekday: 1))
        let monday = WeekStartLabel.text(for: .automatic, localeCalendar: calendar(firstWeekday: 2))

        #expect(sunday.contains(Weekday.sunday.localizedFull))
        #expect(monday.contains(Weekday.monday.localizedFull))
        #expect(sunday != monday)
    }
}
