# Research — App Store Review Prompt

**Date**: 2026-05-04
**Status**: draft
**Related**: `docs/ROADMAP.md` v1.0 exit criteria (downloads, user feedback)

## Problem

Kado is approaching public launch. Organic App Store reviews are
critical for discoverability and trust — especially for an indie app
with no marketing budget. The challenge: encourage reviews without
compromising the privacy-first, no-telemetry philosophy that defines
the project.

The user needs a review prompt that:
- Respects the "no network calls outside CloudKit" rule.
- Uses no third-party SDKs or analytics.
- Doesn't feel manipulative or guilt-inducing.
- Catches users at a genuinely positive moment.

## Current state of the codebase

- **No review-related code exists** — no `StoreKit` import, no
  `requestReview` call, no App Store deep link.
- **Settings view** (`Kado/Views/Settings/`): exists, already has
  sections for export/import, notifications, dev mode. Natural home
  for a "Rate Kado" row.
- **Milestone signals available locally**: streak counts
  (`HabitScoreCalculator`), completion events (toggling in Today
  view), session lifecycle (app foreground via `scenePhase`).
- **UserDefaults** already used for dev mode flag and widget snapshot
  paths — adding 3-4 keys for review state is consistent.

## Proposed approach

A two-pronged strategy mirroring what respected indie apps (Streaks,
Things 3) do:

### 1. System review prompt via `@Environment(\.requestReview)`

Use Apple's native prompt — never a custom dialog. The system controls
display frequency (max 3/year/device) and respects the user's global
"In-App Ratings & Reviews" toggle.

**Trigger conditions** (all must pass):

| Condition | Rationale |
|---|---|
| `daysSinceInstall >= 14` | Returning user, not a tourist |
| `sessionCount >= 7` | Demonstrated engagement |
| `currentVersionNotPrompted` | At most once per app version |
| Positive milestone just occurred | Natural high point |

**Positive milestones** (any one triggers, if gates pass):

- User just completed all habits for today (all-done moment).
- User just hit a 7-day streak on any habit.
- User just hit a 30-day streak on any habit.

**Implementation shape**:

- A `ReviewPromptManager` (or `ReviewPromptService`) — protocol-based,
  environment-injected, matching existing DI patterns.
- Stores state in `UserDefaults`: `appInstallDate`, `sessionCount`,
  `lastReviewPromptVersion`.
- Exposes `func checkAndPromptIfEligible(milestone: Milestone)` called
  from the completion toggle path.
- The actual `requestReview()` call lives in the view layer (it needs
  the SwiftUI environment action).

### 2. Manual "Rate Kado" link in Settings

A permanent row using the `action=write-review` URL scheme:

```
https://apps.apple.com/app/id<APP_ID>?action=write-review
```

- Always available, fully user-initiated.
- No rate limit, no gating.
- Complements the system prompt for users who disabled it globally or
  missed it.

### 3. "Send Feedback" row in Settings

A `mailto:` link (or `MFMailComposeViewController`) to a support
address. Gives unhappy users a private channel — reduces the chance
that frustration lands as a 1-star review. Not review gating (we never
ask "are you happy?" first).

### Key components

- `ReviewPromptService` (protocol + default impl): eligibility logic,
  state tracking.
- `ReviewPromptServiceKey` (EnvironmentKey): DI via SwiftUI
  environment.
- Settings view additions: "Rate Kado" row, "Send Feedback" row.
- Trigger site: wherever the completion toggle / streak milestone is
  confirmed (likely `TodayView` or its ViewModel).

### Data model changes

None. All state lives in `UserDefaults` — no SwiftData migration.

### UI changes

- **Settings**: two new rows in a "Support" or "About" section.
- **No visible UI for the system prompt** — it's Apple's standard
  sheet, shown by the OS.

### Tests to write

```swift
@Test("Prompt not shown before 14 days")
func promptBlockedBeforeMinAge() { ... }

@Test("Prompt not shown before 7 sessions")
func promptBlockedBeforeMinSessions() { ... }

@Test("Prompt fires once per version")
func promptOncePerVersion() { ... }

@Test("Prompt fires on all-habits-complete milestone")
func promptOnAllComplete() { ... }

@Test("Prompt not fired when no milestone occurred")
func noPromptWithoutMilestone() { ... }
```

## Alternatives considered

### Alternative A: Custom pre-prompt dialog ("Do you like Kado?")

- Idea: Show a custom alert first; route "Yes" to the system prompt,
  "No" to feedback form.
- Why not: This is **review gating** — artificially inflates ratings.
  Google Play explicitly bans it. Apple discourages it. Ethically
  incompatible with Kado's values. Also adds a custom modal that
  bypasses Apple's frequency protection.

### Alternative B: Third-party review SDK (Appbot, CriticalMoments)

- Idea: Use a library that optimizes prompt timing via analytics.
- Why not: Violates zero-dependency rule. Adds telemetry. Completely
  against project philosophy.

### Alternative C: In-app "What's New" sheet with review CTA

- Idea: After a major update, show a changelog with a "Leave a review"
  sentence at the bottom.
- Why not now: Not rejected — just lower priority than the system
  prompt. Could be added later as a complement. Slightly more
  intrusive than the passive Settings link.

### Alternative D: No prompting at all

- Idea: Rely entirely on organic reviews from users who find the App
  Store page themselves.
- Why not: Indie apps without prompts get dramatically fewer reviews.
  The system prompt exists specifically for this purpose and is
  designed to be non-intrusive. Choosing not to use it leaves
  significant discoverability on the table.

## Risks and unknowns

- **App ID not yet known**: the `action=write-review` URL needs the
  numeric App ID (available after App Store Connect creates the app
  record — should already exist given the app is in review).
- **Milestone detection timing**: the "all habits complete" signal
  needs care — if the user completes the last habit at 11:59 PM and
  the prompt appears, they might find it jarring. Consider a brief
  delay (next app foreground after the milestone) vs. immediate.
- **Testing the prompt**: in debug/TestFlight the prompt always
  appears; there's no way to verify the 3/year throttle except in
  production.

## Open questions

- [ ] What App Store ID should the deep link use? (Available from App
      Store Connect once the app is approved.)
- [ ] Should the prompt appear immediately after the milestone, or on
      the next app open? (Immediate is simpler; next-open is less
      interruptive but requires persisting a "pending prompt" flag.)
- [ ] What email address for "Send Feedback"? (e.g.
      `kado@castiel.me`, `feedback@castiel.me`, or the existing
      contact.)
- [ ] Should we add the review prompt to v1.0 scope, or defer to a
      fast-follow update? (Low effort, high value — recommending v1.0.)

## References

- [Requesting App Store Reviews — Apple Developer](https://developer.apple.com/documentation/storekit/requesting-app-store-reviews)
- [RequestReviewAction (SwiftUI) — Apple Developer](https://developer.apple.com/documentation/storekit/requestreviewaction)
- [Ratings and Reviews — Apple HIG](https://developer.apple.com/design/human-interface-guidelines/ratings-and-reviews)
- [App Store Review Guidelines §1.1.7, §3.1.1](https://developer.apple.com/app-store/review/guidelines/)
- [SKStoreReviewController guide — SwiftLee](https://www.avanderlee.com/swift/skstorereviewcontroller-app-ratings/)
- [Deceptive Design in App Reviews — Critical Moments](https://criticalmoments.io/blog/deceptive_app_rating_prompt)
