import Foundation

/// Test-/preview-only ``AppIconSwitching``. Records the names it was
/// asked for instead of touching the Home Screen, so previews never
/// raise the system's icon-changed alert.
///
/// Lives in `Preview Content/` and backs ``AppIconApplier/preview``, the
/// `@Entry` default for `\.appIconApplier`; the app injects one over
/// `LiveAppIconSwitcher` at scene build.
@MainActor
final class MockAppIconSwitcher: AppIconSwitching {
    var supportsAlternateIcons: Bool
    private(set) var alternateIconName: String?
    /// Thrown by the next `setAlternateIconName(_:)` instead of switching.
    var failure: (any Error)?
    private(set) var requests: [String?] = []

    init(supportsAlternateIcons: Bool = true, alternateIconName: String? = nil) {
        self.supportsAlternateIcons = supportsAlternateIcons
        self.alternateIconName = alternateIconName
    }

    func setAlternateIconName(_ name: String?) async throws {
        requests.append(name)
        // Suspends before the icon changes, as the system does while its
        // alert is up — the window an overlapping caller could slip into.
        await Task.yield()
        if let failure {
            self.failure = nil
            throw failure
        }
        alternateIconName = name
    }
}

extension AppIconApplier {
    /// One stored instance for the `@Entry` default: a class default
    /// built inline would be reallocated on every environment read.
    static let preview = AppIconApplier(switcher: MockAppIconSwitcher())
}
