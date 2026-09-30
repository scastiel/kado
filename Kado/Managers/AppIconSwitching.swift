import UIKit

/// The system's alternate-icon API, behind a seam so the picker and the
/// Supporter pack reconciliation can be driven without a Home Screen.
@MainActor
protocol AppIconSwitching {
    /// `false` on the rare device that can't change icons; the picker
    /// hides itself then.
    var supportsAlternateIcons: Bool { get }
    /// The `.appiconset` the Home Screen shows, `nil` for the primary.
    var alternateIconName: String? { get }
    /// Asks the system to swap icons. It shows its own "You have
    /// changed the icon" alert, and throws when the app isn't active or
    /// the name isn't one the bundle declares.
    func setAlternateIconName(_ name: String?) async throws
}

/// `UIApplication.shared`, as is.
struct LiveAppIconSwitcher: AppIconSwitching {
    var supportsAlternateIcons: Bool {
        UIApplication.shared.supportsAlternateIcons
    }

    var alternateIconName: String? {
        UIApplication.shared.alternateIconName
    }

    func setAlternateIconName(_ name: String?) async throws {
        try await UIApplication.shared.setAlternateIconName(name)
    }
}
