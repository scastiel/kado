# Plan — App Store Review Prompt

**Date**: 2026-05-04
**Status**: ready to build
**Research**: [research.md](./research.md)

## Summary

Add an ethical, privacy-first review prompt using Apple's native
`requestReview` environment action. The prompt fires on the next app
foreground after a positive milestone (all habits complete, 7- or
30-day streak), gated by install age and session count. A manual "Rate
Kado" link and a "Send Feedback" mailto row are added to Settings.
Ships with v1.0.

## Decisions locked in

- Use `@Environment(\.requestReview)` only — no custom dialog.
- Trigger on **next app foreground** after a milestone (not immediate).
- Gate: install ≥ 14 days, sessions ≥ 7, once per app version.
- Milestones: all-today-habits complete, 7-day streak, 30-day streak.
- All state in `UserDefaults` (app install date, session count, last
  prompted version, pending-prompt flag).
- Feedback email: `sebastien@castiel.me`.
- App Store link uses `action=write-review` URL scheme (needs App ID).
- Scope: v1.0.

## Task list

### Task 1: ReviewPromptService protocol + default implementation

**Goal**: Create the eligibility logic and state tracking, fully
testable without UI.

**Changes**:
- `Packages/KadoCore/Sources/KadoCore/Services/ReviewPromptService.swift`
  — protocol `ReviewPrompting` + struct `DefaultReviewPromptService`
- State stored in an injected `UserDefaults` instance (testable)

**API shape**:
```swift
public protocol ReviewPrompting {
    /// Call on every app foreground to bump session count and check
    /// if a pending prompt should fire.
    func recordSession() -> Bool  // true = should prompt now
    /// Call after a milestone event; sets the pending flag if eligible.
    func recordMilestone(_ milestone: ReviewMilestone)
}
```

**Tests / verification**:
- Prompt blocked before 14 days
- Prompt blocked before 7 sessions
- Prompt fires once per version
- `recordMilestone` sets pending flag only when gates pass
- `recordSession` returns true only when pending flag is set
- After prompt fires, pending flag is cleared

**Commit message (suggested)**: `feat(review): add ReviewPromptService with eligibility logic`

---

### Task 2: Unit tests for ReviewPromptService

**Goal**: TDD — write tests before or alongside Task 1.

**Changes**:
- `KadoTests/ReviewPromptServiceTests.swift`

**Tests / verification**:
- All cases from Task 1's list
- Uses a dedicated `UserDefaults(suiteName:)` per test for isolation

**Commit message (suggested)**: `test(review): add ReviewPromptService unit tests`

---

### Task 3: Wire service into Environment + KadoApp lifecycle

**Goal**: Inject the service via the existing DI pattern; call
`recordSession()` on every `scenePhase → .active` transition.

**Changes**:
- `Kado/App/EnvironmentValues+Services.swift` — add
  `reviewPromptService` entry
- `Kado/App/KadoApp.swift` — on `.active`: call `recordSession()`,
  if true → call `requestReview()`

**Tests / verification**:
- `build_sim` succeeds
- Manual: launch app 7+ times with install date faked to 15 days ago;
  set pending flag; confirm system prompt appears

**Commit message (suggested)**: `feat(review): wire ReviewPromptService into app lifecycle`

---

### Task 4: Trigger milestones from completion paths

**Goal**: After a completion toggle results in "all habits done today"
or a streak milestone, call `recordMilestone(...)`.

**Changes**:
- `Kado/Views/Today/TodayView.swift` — after `toggle()` /
  `incrementCounter()` / timer log, check all-complete state and call
  `recordMilestone(.allComplete)`
- Streak milestone detection: check current streak after completion;
  if it just crossed 7 or 30, call `.streakMilestone(days:)`

**Tests / verification**:
- Unit test: mock service confirms `recordMilestone` called when
  all habits are complete
- Unit test: streak crossing 7 triggers milestone, crossing 8 does not

**Commit message (suggested)**: `feat(review): trigger milestones on completion`

---

### Task 5: Settings — "Rate Kado" and "Send Feedback" rows

**Goal**: Add a support section to Settings with two user-initiated
links.

**Changes**:
- `Kado/Views/Settings/SupportSection.swift` (new file)
- `Kado/Views/Settings/SettingsView.swift` — insert `SupportSection()`
  before `DevModeSection()`

**UI**:
- Row 1: "Rate Kado on the App Store" — SF Symbol `star.bubble`,
  opens `https://apps.apple.com/app/id<APP_ID>?action=write-review`
- Row 2: "Send Feedback" — SF Symbol `envelope`,
  opens `mailto:sebastien@castiel.me?subject=Kado%20Feedback`

**Tests / verification**:
- SwiftUI preview in light + dark
- `build_sim` succeeds
- Tap test (manual or UI test) confirms links open

**Commit message (suggested)**: `feat(settings): add Rate Kado and Send Feedback rows`

---

### Task 6: Localization (EN + FR)

**Goal**: Add catalog entries for all new user-facing strings.

**Changes**:
- `Kado/Resources/Localizable.xcstrings` — keys for "Rate Kado on
  the App Store", "Send Feedback", accessibility labels
- FR translations following existing conventions (`tu`, `habitude`)

**Tests / verification**:
- `LocalizationCoverageTests` passes (no missing FR keys)
- Preview in FR locale

**Commit message (suggested)**: `i18n(review): add EN + FR strings for support section`

---

## Risks and mitigation

| Risk | Mitigation |
|---|---|
| App Store ID unknown at coding time | Use a placeholder constant; fill once approved. The link is only in Settings — no blocker for review prompt logic. |
| "All habits complete" check is expensive with many habits | Use `@Query` count comparison — O(1) after SwiftData indexing. |
| `requestReview()` is a no-op in TestFlight for actual submission | Expected; manual QA uses debug builds where it always shows. |

## Open questions

- [ ] App Store numeric ID (fill once `kado` is approved and visible
      in App Store Connect).

## Out of scope

- "What's New" sheet with review CTA (deferred — complement, not core).
- A/B testing prompt timing (violates no-analytics rule; permanently
  out).
- In-app feedback form beyond mailto (could add later if volume
  warrants).
- Share-your-streak feature (separate feature, drives organic
  discovery but not a review prompt).
