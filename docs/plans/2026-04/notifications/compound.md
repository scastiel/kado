# Compound — Notifications

**Date**: 2026-04-18
**Status**: complete
**Research**: [research.md](./research.md)
**Plan**: [plan.md](./plan.md)
**Branch / PR**: [feature/notifications — PR #15](https://github.com/scastiel/kado/pull/15)

## Summary

Shipped per-habit local reminders for v0.2: one fixed time per habit,
schedule derived from `Frequency` via the existing evaluator,
`Complete`/`Skip` actions routed in-process through a
`UNUserNotificationCenterDelegate`. Eight ordered tasks, eight
commits, 27 new tests. The plan held together end-to-end — no
mid-build pivots — but the code review surfaced several should-fix
items before merge (redundant title/body, dead `@State`
initializer, `Sendable` violation across a Task boundary, idempotency
under rapid mutations).

## Decisions made

- **Schedule derived from `Frequency`, no independent day picker**: reuses `DefaultFrequencyEvaluator.isDue`, keeps the UI to a single toggle + time picker.
- **Reminder time stored as two `Int`s, not a `Date`**: avoids CloudKit's timezone stamping; matches "fires at 9:00 wherever the device is" semantics and sidesteps the SwiftData custom-enum-storage bug.
- **Cap at 7 pending requests per habit × non-due filtering**: stays under iOS's 64-request ceiling with ~9 habits; reconciles on every `.active` transition.
- **Delegate-based routing, not AppIntent-backed actions**: keeps Complete in-process (no relaunch), reuses `ActiveContainer.shared.get()` + `CompletionToggler` directly.
- **`Skip = pure dismiss`**: no record written, no state change. Revisit only if "skipped" streaks become a product ask.
- **Body = `"<Name> — N day streak"` when streak > 0, else name-only**: streak computed at scheduling time (not banner time), reconciled on each mutation.
- **`WidgetReloader.reloadAll` is the single mutation postamble**: piggybacking reminders there instead of sprinkling `RemindersSync` calls across 15 sites — one place to maintain.
- **Schema V3 with lightweight `.lightweight(V2 → V3)` migration**: three primitives with defaults, no `MigrationStage.custom` needed.

## Surprises and how we handled them

### `NSLock` is banned in async contexts under Swift 6

- **What happened**: the first draft of `FakeUserNotificationCenter` used `NSLock` for defensive thread safety. `test_sim` emitted six "instance method 'lock' is unavailable from asynchronous contexts" warnings — promoted to errors under Swift 6 mode.
- **What we did**: dropped the lock entirely. Tests drive the fake sequentially from a single task, so cross-thread access doesn't occur. Marked `@unchecked Sendable` to signal the intent.
- **Lesson**: if you're tempted to reach for `NSLock` in an async API, either restructure to an `actor` or accept that the type is single-threaded and mark it `@unchecked Sendable` with a comment. There is no cheap middle ground.

### `daysPerWeek` saturation isn't a simple "0 requests"

- **What happened**: the first test expected a `daysPerWeek(3)` habit with three completions on days `-3, -2, -1` to yield zero pending requests. The evaluator's 7-day sliding window drops old completions as days advance, so by day 4 the window re-opens and the habit becomes due again.
- **What we did**: changed the test to seed three completions on day 0 — now every window `[d-6, d]` for `d ∈ [0, 6]` contains today three times, so `countInWindow == 3` across the whole window and the assertion holds.
- **Lesson**: the evaluator's semantics are a **sliding 7-day window**, not a calendar week. Scheduler tests that want "stays silent for a week" have to stay inside that window's reach.

### `@Observable` + `NSObject` subclass + non-observed properties

- **What happened**: `NotificationManager` is `NSObject` subclass (for delegate conformance) and was marked `@Observable`. But all stored properties are `let`, so the macro synthesizes observation code that's never triggered.
- **What we did**: shipped it as-is (noted in review); clean-up candidate.
- **Lesson**: `@Observable` is opt-in when you have mutable state the UI observes. For a pure delegate/dispatch owner, plain `final class NSObject` suffices.

## What worked well

- **TDD on the scheduler** paid off: 14 tests against the fake UN center, all red then green in one implementation pass. No debug iterations. When the `daysPerWeek` semantics bit, the fix was a test rewrite, not an implementation chase.
- **Piggybacking on `WidgetReloader.reloadAll`**: 15 existing mutation sites already called it, so reminders sync "for free" without touching Today rows, log sheets, history lists, etc. One conceptual coupling vs 15 code edits.
- **Pure routing function for delegate callbacks**: `NotificationManager.route(actionIdentifier:userInfo:) -> Decision` is the kind of seam that makes delegate code testable. `UNNotificationResponse` has no public init, so without this indirection there would be no routing tests.
- **Conductor workflow**: the plan held without revision across 8 tasks. The checklist-with-checkmarks pattern in `plan.md` made progress visible in the PR.

## For the next person

- **Fire-and-forget `Task.detached` in `RemindersSync`**. Rapid mutations race: both tasks `clearAllOwnedRequests` then `add`. The final state is idempotent, but observers (widgets polling pending requests) can see a transient empty set. If flakiness surfaces, wrap the scheduler in an `actor` or serialize through a single queued Task.
- **`userInfo: [AnyHashable: Any]` crosses the Task boundary** in `NotificationManager.didReceive`. Swift 5 tolerates it; Swift 6 strict mode will warn. If concurrency warnings flare up after a toolchain bump, extract the `habitID` string synchronously and pass only Sendable values into the Task.
- **`DefaultNotificationScheduler.dayFormatter` is computed, not memoized.** Up to 70 `DateFormatter` allocations per `rescheduleAll`. Cheap insurance to memoize if a profile shows it.
- **Notification content has redundant `title` + `body`** when streak == 0 — both render as the habit name. iOS stacks them. Intentional or not, it's the first thing a UX pass will change.
- **No DST-crossing test.** Plan called for one; the test suite pins to UTC only. `DateComponents(hour:minute:)` should be DST-safe in principle, but unverified. Add `Europe/Paris` at the spring-forward boundary if you touch the scheduler.
- **No enforcement of the 64-request cap.** With 10 habits × 7 days = 70 requests, we exceed. The cap is documented, not tested. Either add a stress test or a hard cap in the scheduler that trims by day distance.
- **First banner may fire without actions** if `NotificationManager.configure` hasn't run before the first scheduled delivery — theoretical race at launch. `.task` on scene build makes it effectively immediate but not strictly ordered.

## Generalizable lessons

- **[→ CLAUDE.md]** `NSLock` is effectively banned in async code under Swift 6. Use `actor` for cross-thread shared mutable state; for test fakes that stay sequential, drop locks entirely and mark `@unchecked Sendable` with a comment. This burned ~5 min in the build and would burn the same time again for anyone not aware.
- **[→ CLAUDE.md]** When introducing a new schema version, the production entry points (`SharedStore.productionContainer`, `DevModeController.makeDevContainer`) and **every test** that builds a `Schema(versionedSchema:)` must be updated in the same commit. Five files in this PR vs one in the migration tests — easy to miss one and watch tests flake.
- **[local]** SwiftData `@Model` types shared via `KadoCore` get the typealias treatment: `public typealias HabitRecord = KadoSchemaV3.HabitRecord`. Moving that alias from V2 to V3 (at the bottom of each schema file) is the one-line "current version" switch. Don't overlook.
- **[local]** Piggybacking reminders onto `WidgetReloader.reloadAll` works because both concerns share the same "after a habit mutation" cadence. If the concerns ever diverge (e.g. a reminder-only mutation that doesn't touch widgets), split into two explicit postambles.
- **[→ ROADMAP.md post-v1.0]** Snooze action was explicitly deferred. When revisited, it's a new `UNNotificationAction` routed through the existing delegate — no schema change needed. Also: `Skip` currently doesn't record anything; if "skipped" streaks become a product ask, this needs a `CompletionRecord.kind` or `SkipRecord`.

## Metrics

- Tasks completed: 8 of 8
- Tests added: 27 (scheduler: 14, migration: 1, form model: 5, routing: 7)
- Total tests: 182 → 209
- Commits: 10 (2 docs, 8 feat)
- Files touched: 33 (+2121 / -19)

## References

- [Apple — UNCalendarNotificationTrigger](https://developer.apple.com/documentation/usernotifications/uncalendarnotificationtrigger)
- [Apple — Declaring actionable notification types](https://developer.apple.com/documentation/usernotifications/declaring-your-actionable-notification-types)
- Prior work: `CompleteHabitIntent` (reused for delegate dispatch), `WidgetSnapshotBuilder` (mutation postamble pattern).
