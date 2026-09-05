import Testing
import Foundation
@testable import Kado

/// The nudge's whole job is deciding when *not* to ask, so that is what
/// these pin down: the waiting period, and the two terminal answers.
@Suite("TipNudgeService")
struct TipNudgeServiceTests {
    private func makeDefaults() -> UserDefaults {
        let name = "tip-nudge-test-\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: name)!
        suite.removePersistentDomain(forName: name)
        return suite
    }

    /// UTC gregorian, so a day is a day and the assertions don't move
    /// with the machine's zone.
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }

    private func makeService(
        defaults: UserDefaults,
        firstLaunch: Date? = nil,
        now: Date = .now
    ) -> DefaultTipNudgeService {
        if let firstLaunch {
            defaults.set(firstLaunch, forKey: TipNudgeDefaults.firstLaunchDate)
        }
        return DefaultTipNudgeService(
            defaults: defaults,
            calendar: calendar,
            minimumDaysSinceFirstLaunch: 7,
            now: { now }
        )
    }

    private func days(_ count: Int, before date: Date) -> Date {
        calendar.date(byAdding: .day, value: -count, to: date)!
    }

    // MARK: - The waiting period

    @Test("Hidden on the first launch, which is what seeds the date")
    func hiddenOnFirstLaunch() {
        let defaults = makeDefaults()
        let service = makeService(defaults: defaults)
        #expect(!service.shouldShow())
    }

    @Test("The first launch date is seeded once and never moved")
    func firstLaunchDateSeededOnce() {
        let defaults = makeDefaults()
        let installed = days(30, before: .now)
        _ = makeService(defaults: defaults, firstLaunch: installed)
        // A second construction — a later launch — must not reset the
        // clock, or the nudge would be permanently a week away.
        _ = makeService(defaults: defaults)
        let stored = defaults.object(forKey: TipNudgeDefaults.firstLaunchDate) as? Date
        #expect(stored == installed)
    }

    @Test("Still hidden the day before the waiting period is up")
    func hiddenBeforeMinimumDays() {
        let now = Date.now
        let service = makeService(
            defaults: makeDefaults(), firstLaunch: days(6, before: now), now: now
        )
        #expect(!service.shouldShow())
    }

    @Test("Shows on the day the waiting period is up")
    func showsAtMinimumDays() {
        let now = Date.now
        let service = makeService(
            defaults: makeDefaults(), firstLaunch: days(7, before: now), now: now
        )
        #expect(service.shouldShow())
    }

    @Test("Still shows well past the waiting period")
    func showsLongAfterMinimumDays() {
        let now = Date.now
        let service = makeService(
            defaults: makeDefaults(), firstLaunch: days(200, before: now), now: now
        )
        #expect(service.shouldShow())
    }

    // MARK: - Terminal answers

    @Test("Dismissing hides it for good")
    func hideIsTerminal() {
        let defaults = makeDefaults()
        let now = Date.now
        let service = makeService(
            defaults: defaults, firstLaunch: days(30, before: now), now: now
        )
        #expect(service.shouldShow())

        service.hide()
        #expect(!service.shouldShow())

        // And it stays hidden across a relaunch — the flag is the
        // persisted state, not the instance's memory of it.
        let relaunched = makeService(defaults: defaults, now: now)
        #expect(!relaunched.shouldShow())
    }

    @Test("A tip hides it for good")
    func tipIsTerminal() {
        let defaults = makeDefaults()
        let now = Date.now
        let service = makeService(
            defaults: defaults, firstLaunch: days(30, before: now), now: now
        )
        #expect(service.shouldShow())

        service.recordTip()
        #expect(!service.shouldShow())

        let relaunched = makeService(defaults: defaults, now: now)
        #expect(!relaunched.shouldShow())
    }

    @Test("A tip taken before the waiting period is up still retires the nudge")
    func tipBeforeMinimumDaysStillTerminal() {
        let defaults = makeDefaults()
        let now = Date.now
        // Tipped from Settings on day two, long before Today would ever
        // have asked.
        let early = makeService(
            defaults: defaults, firstLaunch: days(2, before: now), now: now
        )
        early.recordTip()

        let later = makeService(defaults: defaults, now: now.addingTimeInterval(30 * 86_400))
        #expect(!later.shouldShow())
    }

    // MARK: - Day arithmetic

    @Test("Counts days, not 24-hour blocks, across a DST transition")
    func dstTransitionCountsCalendarDays() {
        // Havana, 2026-03-08: the clock jumps 00:00 → 01:00, so this
        // window is 24 hours short of seven 86,400-second days. Seven
        // calendar days have still passed, and the nudge is due.
        var havana = Calendar(identifier: .gregorian)
        havana.timeZone = TimeZone(identifier: "America/Havana") ?? .current

        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 5
        components.hour = 10
        components.timeZone = TimeZone(identifier: "America/Havana")
        let firstLaunch = havana.date(from: components)!
        let now = havana.date(byAdding: .day, value: 7, to: firstLaunch)!

        let defaults = makeDefaults()
        defaults.set(firstLaunch, forKey: TipNudgeDefaults.firstLaunchDate)
        let service = DefaultTipNudgeService(
            defaults: defaults,
            calendar: havana,
            minimumDaysSinceFirstLaunch: 7,
            now: { now }
        )
        #expect(service.shouldShow())
    }
}
