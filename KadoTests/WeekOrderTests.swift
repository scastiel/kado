import Foundation
import Testing
import KadoCore

/// The week-layout arithmetic every surface that draws a week shares.
/// Asserted as invariants over all seven possible first days rather
/// than as examples: the Monday-only version of this code was correct
/// for every case anyone thought to check, because there was only one.
@Suite("Week order")
struct WeekOrderTests {

    @Test("A week is seven distinct days opening on the one asked for")
    func weekIsSevenDistinctDays() {
        for firstWeekday in 1...7 {
            let week = Weekday.week(startingOn: firstWeekday)

            #expect(week.count == 7)
            #expect(Set(week).count == 7)
            #expect(week.first?.rawValue == firstWeekday)
        }
    }

    /// The shape the app shipped with, kept as a regression: a
    /// Monday-first user must see exactly the order they had before
    /// the preference existed.
    @Test("Monday-first is the order the app used to hard-code")
    func mondayFirstMatchesTheFormerHardCoding() {
        #expect(
            Weekday.week(startingOn: 2)
                == [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]
        )
    }

    @Test("Sunday-first and Saturday-first roll around correctly")
    func otherRegionsRollAround() {
        #expect(
            Weekday.week(startingOn: 1)
                == [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]
        )
        #expect(
            Weekday.week(startingOn: 7)
                == [.saturday, .sunday, .monday, .tuesday, .wednesday, .thursday, .friday]
        )
    }

    /// The invariant the calendar grid depends on: a day's column is
    /// the index of its own header.
    @Test("A day's column is where its header sits")
    func columnIndexesIntoTheHeaderRow() {
        for firstWeekday in 1...7 {
            let week = Weekday.week(startingOn: firstWeekday)
            for day in Weekday.allCases {
                let column = day.column(inWeekStartingOn: firstWeekday)

                #expect((0..<7).contains(column))
                #expect(week[column] == day)
            }
        }
    }

    /// `firstWeekday` arrives from `UserDefaults` by way of
    /// `Calendar`, so nonsense must fold into a real day rather than
    /// shifting the grid or trapping.
    @Test("Out-of-range first weekdays fold into the 1...7 they mean")
    func outOfRangeFoldsIn() {
        #expect(Weekday.week(startingOn: 8) == Weekday.week(startingOn: 1))
        #expect(Weekday.week(startingOn: 0) == Weekday.week(startingOn: 7))
        #expect(Weekday.week(startingOn: -6) == Weekday.week(startingOn: 1))
        #expect(Weekday.monday.column(inWeekStartingOn: 9) == Weekday.monday.column(inWeekStartingOn: 2))
    }

    /// What the month grid actually asks for: the blanks before the
    /// 1st have to leave it under its own weekday header, in every
    /// month and for every possible week start.
    @Test("Leading blanks land the 1st under its own header")
    func leadingBlanksAlignTheFirstOfTheMonth() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))

        for firstWeekday in 1...7 {
            for month in 1...12 {
                let monthStart = try #require(
                    calendar.date(from: DateComponents(year: 2026, month: month, day: 1))
                )
                let weekday = try #require(
                    Weekday(rawValue: calendar.component(.weekday, from: monthStart))
                )
                let blanks = weekday.column(inWeekStartingOn: firstWeekday)

                #expect(Weekday.week(startingOn: firstWeekday)[blanks] == weekday)
            }
        }
    }
}
