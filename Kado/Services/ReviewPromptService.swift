import Foundation

enum ReviewMilestone: Sendable {
    case allHabitsComplete
    case streak(days: Int)
}

protocol ReviewPrompting: Sendable {
    func recordSession() -> Bool
    func recordMilestone(_ milestone: ReviewMilestone)
}

struct DefaultReviewPromptService: ReviewPrompting, Sendable {
    private let defaults: UserDefaults
    private let calendar: Calendar
    private let minimumDaysSinceInstall: Int
    private let minimumSessions: Int
    private let appVersion: String
    private let now: @Sendable () -> Date

    init(
        defaults: UserDefaults = .standard,
        calendar: Calendar = .current,
        minimumDaysSinceInstall: Int = 14,
        minimumSessions: Int = 7,
        appVersion: String? = nil,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.defaults = defaults
        self.calendar = calendar
        self.minimumDaysSinceInstall = minimumDaysSinceInstall
        self.minimumSessions = minimumSessions
        self.appVersion = appVersion ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        self.now = now
        seedInstallDateIfNeeded()
    }

    func recordSession() -> Bool {
        let count = defaults.integer(forKey: Keys.sessionCount) + 1
        defaults.set(count, forKey: Keys.sessionCount)

        guard defaults.bool(forKey: Keys.pendingPrompt) else { return false }
        defaults.set(false, forKey: Keys.pendingPrompt)
        defaults.set(appVersion, forKey: Keys.lastPromptedVersion)
        return true
    }

    func recordMilestone(_ milestone: ReviewMilestone) {
        switch milestone {
        case .streak(let days) where days != 7 && days != 30:
            return
        default:
            break
        }
        guard isEligible() else { return }
        defaults.set(true, forKey: Keys.pendingPrompt)
    }

    private func isEligible() -> Bool {
        guard let installDate = defaults.object(forKey: Keys.installDate) as? Date else { return false }
        let daysSince = calendar.dateComponents([.day], from: installDate, to: now()).day ?? 0
        guard daysSince >= minimumDaysSinceInstall else { return false }

        let sessions = defaults.integer(forKey: Keys.sessionCount)
        guard sessions >= minimumSessions else { return false }

        let lastVersion = defaults.string(forKey: Keys.lastPromptedVersion) ?? ""
        guard appVersion != lastVersion else { return false }

        return true
    }

    private func seedInstallDateIfNeeded() {
        if defaults.object(forKey: Keys.installDate) == nil {
            defaults.set(now(), forKey: Keys.installDate)
        }
    }

    private enum Keys {
        static let installDate = "kado.reviewPrompt.installDate"
        static let sessionCount = "kado.reviewPrompt.sessionCount"
        static let lastPromptedVersion = "kado.reviewPrompt.lastPromptedVersion"
        static let pendingPrompt = "kado.reviewPrompt.pendingPrompt"
    }
}
