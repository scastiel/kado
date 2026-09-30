import KadoCore

/// Brings the Home Screen icon in line with the user's pick, gated on
/// the Supporter pack.
///
/// Called on a pick, on every return to the foreground and whenever
/// ownership changes. A refunded pack puts the default icon back; a
/// restore brings the pick back, because the pick itself is never
/// rewritten (``SupporterGated``). Asks the system only when the icon
/// actually differs: every call shows the user an alert, and a
/// foreground that changes nothing must not.
///
/// One instance for the whole app, shared by the picker and `KadoApp`,
/// because the calls overlap: the alert a pick raises makes the scene
/// inactive, dismissing it makes it active again, and that foreground
/// reconciles while the pick's own switch may still be in flight. So
/// switches run one at a time, and a caller that arrives mid-switch
/// waits for it and checks again — by then the icon usually matches,
/// and the second alert (or a second call that throws and rolls a
/// successful pick back) never happens.
@MainActor
final class AppIconApplier {
    let switcher: any AppIconSwitching
    private var inFlight: Task<Void, any Error>?

    init(switcher: any AppIconSwitching) {
        self.switcher = switcher
    }

    /// The icon the Home Screen should show for this pick.
    static func target(preferred: AppIcon, isSupporter: Bool) -> AppIcon {
        AppIcon.effective(preferred: preferred, isSupporter: isSupporter)
    }

    /// Returns whether the system was asked to change the icon.
    @discardableResult
    func apply(preferred: AppIcon, isSupporter: Bool) async throws -> Bool {
        guard switcher.supportsAlternateIcons else { return false }
        // A loop, not an `if`: whoever else was waiting may have started
        // the next switch by the time this caller resumes. The waiter
        // clears a finished switch itself — awaiting a completed task
        // doesn't yield, so leaving it to the caller that started it
        // would spin here on the main actor before that caller resumes.
        while let current = inFlight {
            _ = try? await current.value
            if inFlight == current { inFlight = nil }
        }
        // No suspension from here to `inFlight = task`, so no other
        // caller can slip in between the check and the claim.
        let wanted = Self.target(preferred: preferred, isSupporter: isSupporter).alternateIconName
        guard switcher.alternateIconName != wanted else { return false }
        let switcher = switcher
        let task = Task { try await switcher.setAlternateIconName(wanted) }
        inFlight = task
        defer { if inFlight == task { inFlight = nil } }
        try await task.value
        return true
    }
}
