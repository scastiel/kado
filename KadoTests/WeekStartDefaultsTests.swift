import Foundation
import Testing
import KadoCore

@Suite("WeekStartDefaults")
struct WeekStartDefaultsTests {
    private func makeSuite() -> (UserDefaults, String) {
        let name = "week-start-tests-\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: name)!
        return (suite, name)
    }

    private func tearDown(_ name: String) {
        UserDefaults().removePersistentDomain(forName: name)
    }

    @Test("An unset key reads as automatic")
    func defaultsToAutomatic() {
        let (suite, name) = makeSuite()
        defer { tearDown(name) }

        #expect(WeekStartDefaults.weekStart(in: suite) == .automatic)
    }

    @Test("Every option round-trips")
    func everyOptionRoundTrips() {
        let (suite, name) = makeSuite()
        defer { tearDown(name) }

        for option in WeekStart.allCases {
            WeekStartDefaults.setWeekStart(option, in: suite)
            #expect(WeekStartDefaults.weekStart(in: suite) == option)
        }
    }

    /// A future build could add cases; downgrading must not leave the
    /// app resolving weeks against a raw value it can't render.
    @Test("A raw value outside the cases falls back to automatic")
    func unknownRawValueFallsBack() {
        let (suite, name) = makeSuite()
        defer { tearDown(name) }

        suite.set(42, forKey: WeekStartDefaults.key)

        #expect(WeekStartDefaults.weekStart(in: suite) == .automatic)
    }

    @Test("Automatic takes the region's first weekday, whatever it is")
    func automaticFollowsTheRegion() {
        for firstWeekday in 1...7 {
            #expect(WeekStart.automatic.firstWeekday(in: TestCalendar.utc(firstWeekday: firstWeekday)) == firstWeekday)
        }
    }

    @Test("A pinned day overrides the region")
    func pinnedDayOverridesTheRegion() {
        let sundayRegion = TestCalendar.utc(firstWeekday: 1)

        #expect(WeekStart.monday.firstWeekday(in: sundayRegion) == 2)
        #expect(WeekStart.saturday.firstWeekday(in: sundayRegion) == 7)
    }

    /// The whole preference travels as a calendar, so applying it must
    /// change `firstWeekday` and nothing else.
    @Test("Applying an option leaves the rest of the calendar alone")
    func applyingLeavesTheCalendarOtherwiseIntact() {
        var base = Calendar(identifier: .gregorian)
        base.firstWeekday = 1
        base.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        base.locale = Locale(identifier: "ja_JP")

        let applied = WeekStart.monday.calendar(base: base)

        #expect(applied.firstWeekday == 2)
        #expect(applied.timeZone == base.timeZone)
        #expect(applied.locale == base.locale)
        #expect(applied.identifier == base.identifier)
    }

    @Test("The stored option is what the calendar helper applies")
    func storedOptionDrivesTheCalendar() {
        let (suite, name) = makeSuite()
        defer { tearDown(name) }
        let sundayRegion = TestCalendar.utc(firstWeekday: 1)

        #expect(WeekStartDefaults.calendar(base: sundayRegion, in: suite).firstWeekday == 1)

        WeekStartDefaults.setWeekStart(.thursday, in: suite)

        #expect(WeekStartDefaults.calendar(base: sundayRegion, in: suite).firstWeekday == 5)
    }
}
