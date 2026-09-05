import Foundation

/// Test-/preview-only ``TipNudging`` with a fixed answer.
///
/// The real service's answer depends on how long the app has been
/// installed, which no preview can wait for and no test should depend
/// on — so this one is simply told what to say, and records the calls
/// made to it.
///
/// Lives in `Preview Content/` so it ships only with Debug builds.
///
/// `@unchecked Sendable` with no lock, per CLAUDE.md: previews and
/// tests drive it from one thread, and `NSLock` is unavailable from
/// async contexts under Swift 6 anyway.
final class StubTipNudgeService: TipNudging, @unchecked Sendable {
    /// What ``shouldShow()`` returns. Mutable so a test can flip it and
    /// re-ask, the way a real dismissal would.
    var visible: Bool

    private(set) var hideCallCount = 0
    private(set) var recordTipCallCount = 0

    init(visible: Bool = true) {
        self.visible = visible
    }

    func shouldShow() -> Bool { visible }

    func hide() {
        hideCallCount += 1
        visible = false
    }

    func recordTip() {
        recordTipCallCount += 1
        visible = false
    }
}
