# Compound — App Store Review Prompt

**Date**: 2026-05-04
**Status**: complete
**Research**: [research.md](./research.md)
**Plan**: [plan.md](./plan.md)
**Branch / PR**: [PR #50](https://github.com/scastiel/kado/pull/50)

## Summary

Added an ethical, privacy-first App Store review prompt using Apple's
native `requestReview` environment action, plus manual "Rate Kado" and
"Send Feedback" links in Settings. The implementation followed the plan
closely with no significant deviations. The feature is lightweight
(82-line service, 24-line modifier) and fully testable without UI.

## Decisions made

- **System prompt only, never a custom dialog**: avoids review gating
  and respects Apple's built-in frequency protection (3/year/device).
- **Next-foreground timing**: milestone sets a pending flag, prompt
  fires on next `scenePhase → .active`. Less interruptive than
  immediate — the user finishes their flow undisturbed.
- **Injectable `appVersion` on service**: `Bundle.main` isn't available
  in test targets, so the version string is injected. Production uses
  the default (reads from `Info.plist`).
- **Service lives in the app target, not KadoCore**: it's app-specific
  (depends on `UserDefaults` keys, version gating) and not needed by
  extensions.
- **View modifier pattern for `requestReview()`**: the StoreKit
  environment action must be called from a View context. A
  `ReviewPromptModifier` on `ContentView` keeps the logic out of
  `KadoApp.swift` and reads cleanly.
- **App Store ID hardcoded from README**: found `6762570244` in the
  existing README badge — no placeholder needed.

## Surprises and how we handled them

### App Store ID was already available

- **What happened**: the plan assumed the App Store ID was unknown and
  would need a placeholder. The README already had the live App Store
  badge with ID `6762570244`.
- **What we did**: used it directly, caught an incorrect placeholder
  (`6744253621`) before it shipped.
- **Lesson**: check existing project assets before assuming data is
  missing.

### Links don't work in Simulator

- **What happened**: both the App Store review URL and the `mailto:`
  link silently fail in the Simulator because the App Store and Mail
  apps aren't available.
- **What we did**: confirmed this is expected — `Link` /
  `UIApplication.shared.open` silently no-ops when no handler exists.
- **Lesson**: for Settings rows that open external URLs, visual
  verification in the Simulator confirms layout but not functionality.
  Real-device testing is needed.

## What worked well

- **TDD for the service**: writing 13 tests first made the eligibility
  logic trivial to implement and gave immediate confidence in gate
  conditions.
- **Isolated `UserDefaults` per test**: `UserDefaults(suiteName:)` with
  a UUID suffix gives perfect test isolation without cleanup.
- **View modifier pattern**: `ReviewPromptModifier` cleanly separates
  the StoreKit concern from `ContentView`'s layout. Easy to remove or
  swap later.
- **Milestone detection in TodayView**: piggybacks on existing
  `streakCalculator` and `HabitRowState.resolve` — no new computation
  needed.

## For the next person

- `DefaultReviewPromptService` stores all state under
  `kado.reviewPrompt.*` keys in `UserDefaults.standard`. These are
  device-local and never synced via CloudKit — intentional.
- The service seeds `installDate` on first init. If you reset
  `UserDefaults` (e.g. dev mode), the install date resets too — the
  14-day gate restarts.
- `recordMilestone` only accepts `.streak(days: 7)` and
  `.streak(days: 30)` — other values are silently ignored. If you
  want to add more milestone thresholds, update the `switch` in
  `recordMilestone`.
- The `requestReview()` call in `ReviewPromptModifier` fires at most
  once per foreground cycle (pending flag is cleared on consumption).
  Apple's own 3/year throttle is a second layer of protection.

## Generalizable lessons

- **[local]** `Bundle.main` properties aren't accessible in test
  targets — inject them as init parameters when testing logic that
  depends on app version.
- **[local]** Simulator can't open `mailto:` or App Store URLs.
  Always note this limitation when reporting "done" on Settings links.

## Metrics

- Tasks completed: 6 of 6
- Tests added: 13
- Commits: 8
- Files touched: 11 (744 lines added)
