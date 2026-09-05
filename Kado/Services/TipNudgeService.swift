import Foundation

/// Keys the tip nudge owns in `UserDefaults`, named here rather than
/// inside the service so the UI-test hooks can seed and clear them
/// without reaching into a private enum. Mirrors `DevModeDefaults`.
nonisolated enum TipNudgeDefaults {
    /// First time the app read the nudge's state — its stand-in for an
    /// install date. Seeded on first read, never overwritten.
    static let firstLaunchDate = "kado.tipNudge.firstLaunchDate"
    /// The user dismissed the nudge. Terminal.
    static let hidden = "kado.tipNudge.hidden"
    /// A tip went through on this device. Terminal.
    static let tipped = "kado.tipNudge.tipped"

    static let allKeys = [firstLaunchDate, hidden, tipped]
}

/// Decides whether Today shows its one-line tip nudge.
///
/// Three rules, each of which can only ever turn the nudge *off*:
///
/// - it stays hidden for the first days of use, so the app never asks
///   for anything before it has been of any use;
/// - dismissing it is permanent — the user answered once, and asking
///   again would make that answer worthless;
/// - a tip hides it for good too, so nobody is asked for something
///   they already did.
///
/// State lives in `UserDefaults` rather than SwiftData deliberately.
/// It is device-local by nature (tips are consumables that unlock
/// nothing, so there is no entitlement to restore), and putting a
/// dismissal flag in the CloudKit-mirrored store would cost a schema
/// version for one boolean.
protocol TipNudging: Sendable {
    /// Whether Today should render the nudge right now.
    func shouldShow() -> Bool
    /// The user dismissed it. Never show it again.
    func hide()
    /// A tip went through. Never show it again.
    func recordTip()
}

/// Production ``TipNudging``, backed by `UserDefaults`.
///
/// The first-launch date is seeded the first time this is constructed,
/// which on a fresh install is the first launch. A user updating from a
/// build without the nudge is therefore treated as new: they see it a
/// week after updating rather than immediately. That is the
/// conservative direction to be wrong in, and it avoids coupling to the
/// review prompt's own install date, which gates a different decision
/// and would drag this one along on any future change.
///
/// Isolation follows `DefaultReviewPromptService`: left on the
/// project's default `MainActor`, which is what lets a `Sendable`
/// struct hold a `UserDefaults`. Marking the type `nonisolated`
/// instead turns that stored property into a Swift 6 error
/// ("non-Sendable type 'UserDefaults'"), and it would buy nothing:
/// this is never used as a default-argument expression, which is the
/// one place the project needs `nonisolated` services (see
/// `DefaultTipJarStore.init`).
struct DefaultTipNudgeService: TipNudging, Sendable {
    private let defaults: UserDefaults
    private let calendar: Calendar
    private let minimumDaysSinceFirstLaunch: Int
    private let now: @Sendable () -> Date

    init(
        defaults: UserDefaults = .standard,
        calendar: Calendar = .current,
        minimumDaysSinceFirstLaunch: Int = 7,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.defaults = defaults
        self.calendar = calendar
        self.minimumDaysSinceFirstLaunch = minimumDaysSinceFirstLaunch
        self.now = now
        seedFirstLaunchDateIfNeeded()
    }

    func shouldShow() -> Bool {
        guard !defaults.bool(forKey: TipNudgeDefaults.hidden) else { return false }
        guard !defaults.bool(forKey: TipNudgeDefaults.tipped) else { return false }
        guard let firstLaunch = defaults.object(forKey: TipNudgeDefaults.firstLaunchDate) as? Date
        else { return false }

        // Day arithmetic through `Calendar`, never elapsed seconds — a
        // "day" is 23 or 25 hours twice a year.
        let days = calendar.dateComponents([.day], from: firstLaunch, to: now()).day ?? 0
        return days >= minimumDaysSinceFirstLaunch
    }

    func hide() {
        defaults.set(true, forKey: TipNudgeDefaults.hidden)
    }

    func recordTip() {
        defaults.set(true, forKey: TipNudgeDefaults.tipped)
    }

    private func seedFirstLaunchDateIfNeeded() {
        if defaults.object(forKey: TipNudgeDefaults.firstLaunchDate) == nil {
            defaults.set(now(), forKey: TipNudgeDefaults.firstLaunchDate)
        }
    }
}
