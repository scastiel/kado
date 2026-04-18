import Testing
@testable import Kado
import KadoCore

/// Smoke tests — the single-test-case proof that the Swift Testing
/// target is wired and can `@testable import Kado`. Real coverage
/// lands alongside each business-logic task (habit score, streak,
/// frequency, parsers…). See `docs/plans/` for per-task breakdowns.
@Test("test target is wired")
func smokeTargetIsWired() {
    #expect(true)
}
