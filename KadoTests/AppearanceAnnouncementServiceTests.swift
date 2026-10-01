import Testing
import Foundation
@testable import Kado

/// The announcement has no waiting period: it is for everyone who
/// updates, from their first launch. What these pin is that it is
/// there until it is put away, and that putting it away is permanent
/// and dated once.
@Suite("AppearanceAnnouncementService")
struct AppearanceAnnouncementServiceTests {
    private func makeDefaults() -> UserDefaults {
        let name = "appearance-announcement-test-\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: name)!
        suite.removePersistentDomain(forName: name)
        return suite
    }

    @Test("Due on the very first launch, with nothing stored")
    func dueOnFirstLaunch() {
        let service = DefaultAppearanceAnnouncementService(defaults: makeDefaults())
        #expect(service.retiredAt() == nil)
    }

    @Test("Retiring it records when, and survives a relaunch")
    func retireIsTerminal() {
        let defaults = makeDefaults()
        let now = TestCalendar.referenceDate
        let service = DefaultAppearanceAnnouncementService(defaults: defaults, now: { now })
        service.retire()
        #expect(service.retiredAt() == now)

        let relaunched = DefaultAppearanceAnnouncementService(defaults: defaults)
        #expect(relaunched.retiredAt() == now)
    }

    @Test("A second retirement keeps the first date")
    func firstRetirementWins() {
        // Dismissed today, Appearance opened next week: the tip nudge's
        // wait is counted from the dismissal, so it must not move.
        let defaults = makeDefaults()
        let first = TestCalendar.day(0)
        DefaultAppearanceAnnouncementService(defaults: defaults, now: { first }).retire()
        DefaultAppearanceAnnouncementService(defaults: defaults, now: { TestCalendar.day(7) }).retire()
        #expect(DefaultAppearanceAnnouncementService(defaults: defaults).retiredAt() == first)
    }
}
