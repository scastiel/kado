import Testing
import Foundation
@testable import Kado

@Suite("ReviewPromptService")
struct ReviewPromptServiceTests {
    private func makeDefaults() -> UserDefaults {
        let name = "review-test-\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: name)!
        suite.removePersistentDomain(forName: name)
        return suite
    }

    private func makeService(
        defaults: UserDefaults? = nil,
        installDate: Date = Date.now.addingTimeInterval(-15 * 86400),
        sessionCount: Int = 10,
        appVersion: String = "1.0.0"
    ) -> (DefaultReviewPromptService, UserDefaults) {
        let d = defaults ?? makeDefaults()
        d.set(installDate, forKey: "kado.reviewPrompt.installDate")
        d.set(sessionCount, forKey: "kado.reviewPrompt.sessionCount")
        let service = DefaultReviewPromptService(
            defaults: d,
            calendar: Calendar(identifier: .gregorian),
            appVersion: appVersion
        )
        return (service, d)
    }

    // MARK: - Gate: install age

    @Test("Milestone ignored before minimum install age")
    func milestoneBlockedBeforeMinAge() {
        let (service, defaults) = makeService(
            installDate: Date.now.addingTimeInterval(-5 * 86400)
        )
        service.recordMilestone(.allHabitsComplete)
        #expect(!defaults.bool(forKey: "kado.reviewPrompt.pendingPrompt"))
    }

    @Test("Milestone accepted after minimum install age")
    func milestoneAcceptedAfterMinAge() {
        let (service, defaults) = makeService(
            installDate: Date.now.addingTimeInterval(-15 * 86400)
        )
        service.recordMilestone(.allHabitsComplete)
        #expect(defaults.bool(forKey: "kado.reviewPrompt.pendingPrompt"))
    }

    // MARK: - Gate: session count

    @Test("Milestone ignored before minimum sessions")
    func milestoneBlockedBeforeMinSessions() {
        let (service, defaults) = makeService(sessionCount: 3)
        service.recordMilestone(.allHabitsComplete)
        #expect(!defaults.bool(forKey: "kado.reviewPrompt.pendingPrompt"))
    }

    @Test("Milestone accepted at minimum sessions")
    func milestoneAcceptedAtMinSessions() {
        let (service, defaults) = makeService(sessionCount: 7)
        service.recordMilestone(.allHabitsComplete)
        #expect(defaults.bool(forKey: "kado.reviewPrompt.pendingPrompt"))
    }

    // MARK: - Gate: once per version

    @Test("Milestone ignored if already prompted for this version")
    func milestoneBlockedIfAlreadyPrompted() {
        let d = makeDefaults()
        d.set("1.0.0", forKey: "kado.reviewPrompt.lastPromptedVersion")
        let (service, defaults) = makeService(defaults: d, appVersion: "1.0.0")
        service.recordMilestone(.allHabitsComplete)
        #expect(!defaults.bool(forKey: "kado.reviewPrompt.pendingPrompt"))
    }

    @Test("Milestone accepted for a new version")
    func milestoneAcceptedForNewVersion() {
        let d = makeDefaults()
        d.set("1.0.0", forKey: "kado.reviewPrompt.lastPromptedVersion")
        let (service, defaults) = makeService(defaults: d, appVersion: "1.1.0")
        service.recordMilestone(.allHabitsComplete)
        #expect(defaults.bool(forKey: "kado.reviewPrompt.pendingPrompt"))
    }

    // MARK: - Milestone filtering

    @Test("Only 7-day and 30-day streaks trigger milestone")
    func streakFiltering() {
        let (service, defaults) = makeService()

        service.recordMilestone(.streak(days: 5))
        #expect(!defaults.bool(forKey: "kado.reviewPrompt.pendingPrompt"))

        service.recordMilestone(.streak(days: 7))
        #expect(defaults.bool(forKey: "kado.reviewPrompt.pendingPrompt"))
    }

    @Test("30-day streak triggers milestone")
    func thirtyDayStreak() {
        let (service, defaults) = makeService()
        service.recordMilestone(.streak(days: 30))
        #expect(defaults.bool(forKey: "kado.reviewPrompt.pendingPrompt"))
    }

    // MARK: - recordSession

    @Test("recordSession returns false when no pending prompt")
    func recordSessionNoPending() {
        let (service, _) = makeService()
        let result = service.recordSession()
        #expect(!result)
    }

    @Test("recordSession returns true and clears pending flag")
    func recordSessionWithPending() {
        let (service, defaults) = makeService()
        service.recordMilestone(.allHabitsComplete)
        #expect(defaults.bool(forKey: "kado.reviewPrompt.pendingPrompt"))

        let result = service.recordSession()
        #expect(result)
        #expect(!defaults.bool(forKey: "kado.reviewPrompt.pendingPrompt"))
        #expect(defaults.string(forKey: "kado.reviewPrompt.lastPromptedVersion") == "1.0.0")
    }

    @Test("recordSession increments session count")
    func recordSessionIncrements() {
        let (service, defaults) = makeService(sessionCount: 10)
        _ = service.recordSession()
        #expect(defaults.integer(forKey: "kado.reviewPrompt.sessionCount") == 11)
    }

    // MARK: - Install date seeding

    @Test("Service seeds install date on first init")
    func seedsInstallDate() {
        let d = makeDefaults()
        _ = DefaultReviewPromptService(defaults: d, appVersion: "1.0.0")
        #expect(d.object(forKey: "kado.reviewPrompt.installDate") != nil)
    }

    @Test("Service does not overwrite existing install date")
    func preservesExistingInstallDate() {
        let d = makeDefaults()
        let originalDate = Date.now.addingTimeInterval(-30 * 86400)
        d.set(originalDate, forKey: "kado.reviewPrompt.installDate")
        _ = DefaultReviewPromptService(defaults: d, appVersion: "1.0.0")
        let stored = d.object(forKey: "kado.reviewPrompt.installDate") as? Date
        #expect(stored == originalDate)
    }
}
