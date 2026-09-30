import Foundation

/// Test-/preview-only ``AppIconSwitching``. Records the names it was
/// asked for instead of touching the Home Screen, so previews never
/// raise the system's icon-changed alert.
///
/// Lives in `Preview Content/` and serves as the `@Entry` default for
/// `\.appIconSwitcher`; `LiveAppIconSwitcher` is injected at scene
/// build.
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
        if let failure {
            self.failure = nil
            throw failure
        }
        alternateIconName = name
    }
}
