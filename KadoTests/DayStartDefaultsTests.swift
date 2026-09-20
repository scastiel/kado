import Foundation
import Testing
import KadoCore

@Suite("DayStartDefaults")
struct DayStartDefaultsTests {
    private func makeSuite() -> (UserDefaults, String) {
        let name = "day-start-tests-\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: name)!
        return (suite, name)
    }

    private func tearDown(_ name: String) {
        UserDefaults().removePersistentDomain(forName: name)
    }

    @Test("An unset key reads as midnight")
    func defaultsToMidnight() {
        let (suite, name) = makeSuite()
        defer { tearDown(name) }

        #expect(DayStartDefaults.hour(in: suite) == 0)
    }

    @Test("A stored hour round-trips")
    func roundTrips() {
        let (suite, name) = makeSuite()
        defer { tearDown(name) }

        DayStartDefaults.setHour(4, in: suite)

        #expect(DayStartDefaults.hour(in: suite) == 4)
    }

    @Test("Every allowed hour round-trips unchanged")
    func allAllowedHoursRoundTrip() {
        let (suite, name) = makeSuite()
        defer { tearDown(name) }

        for hour in DayStartDefaults.allowedHours {
            DayStartDefaults.setHour(hour, in: suite)
            #expect(DayStartDefaults.hour(in: suite) == hour)
        }
    }

    @Test("Values outside the allowed range clamp on write")
    func clampsOnWrite() {
        let (suite, name) = makeSuite()
        defer { tearDown(name) }

        DayStartDefaults.setHour(DayStartDefaults.allowedHours.upperBound + 1, in: suite)
        #expect(DayStartDefaults.hour(in: suite) == DayStartDefaults.allowedHours.upperBound)

        DayStartDefaults.setHour(-2, in: suite)
        #expect(DayStartDefaults.hour(in: suite) == DayStartDefaults.allowedHours.lowerBound)
    }

    /// The App Group suite is writable by any process, and a value it
    /// holds may predate whatever range the running build offers. A
    /// nonsense hour must clamp to something the picker can show, not
    /// leave the app resolving days against a value it can't display.
    @Test("A value written outside the range clamps on read")
    func clampsOnRead() {
        let (suite, name) = makeSuite()
        defer { tearDown(name) }

        suite.set(DayStartDefaults.allowedHours.upperBound + 1, forKey: DayStartDefaults.key)

        #expect(DayStartDefaults.hour(in: suite) == DayStartDefaults.allowedHours.upperBound)
    }

    @Test("The allowed range starts at midnight so the default is always offerable")
    func rangeIncludesDefault() {
        #expect(DayStartDefaults.allowedHours.contains(DayStartDefaults.defaultHour))
    }

    /// The first release capped the picker at 6 AM on the assumption
    /// that the rollover sits inside a night-time sleep. That shut out
    /// the overnight worker whose day starts mid-afternoon (#93). Every
    /// hour is offerable now, and this pins it so the range doesn't
    /// quietly narrow again.
    @Test("Every hour of the day is offerable")
    func everyHourIsOfferable() {
        #expect(DayStartDefaults.allowedHours == 0...23)
    }
}
