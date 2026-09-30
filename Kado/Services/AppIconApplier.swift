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
@MainActor
struct AppIconApplier {
    let switcher: any AppIconSwitching

    /// The icon the Home Screen should show for this pick.
    static func target(preferred: AppIcon, isSupporter: Bool) -> AppIcon {
        AppIcon.effective(preferred: preferred, isSupporter: isSupporter)
    }

    /// Returns whether the system was asked to change the icon.
    @discardableResult
    func apply(preferred: AppIcon, isSupporter: Bool) async throws -> Bool {
        guard switcher.supportsAlternateIcons else { return false }
        let wanted = Self.target(preferred: preferred, isSupporter: isSupporter).alternateIconName
        guard switcher.alternateIconName != wanted else { return false }
        try await switcher.setAlternateIconName(wanted)
        return true
    }
}
