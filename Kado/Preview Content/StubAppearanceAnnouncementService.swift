import Foundation

/// Test-/preview-only ``AppearanceAnnouncing`` that keeps its answer in
/// memory, so a preview never reads — or retires — the real one.
///
/// `@unchecked Sendable` with no lock, per CLAUDE.md: previews and
/// tests drive it from one thread.
final class StubAppearanceAnnouncementService: AppearanceAnnouncing, @unchecked Sendable {
    private var retired: Date?

    init(retiredAt: Date? = nil) {
        self.retired = retiredAt
    }

    func retiredAt() -> Date? { retired }

    func retire() {
        if retired == nil { retired = .now }
    }
}
