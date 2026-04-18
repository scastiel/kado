# Research — Notifications

**Date**: 2026-04-18
**Status**: ready for plan
**Related**: `docs/ROADMAP.md` (v0.2 → Notifications), prior widget + AppIntent work in `docs/plans/2026-04/widgets/`

## Problem

v0.2 ships the "visible iOS-native" layer. Widgets and Overview landed
already (#12, #14). Local notifications are the remaining day-to-day
surface: the user wants a gentle nudge at a chosen time on the days a
habit is *due*, and wants to tick it off from the banner without
opening the app.

"Done" for the user:
- Pick one time of day per habit; enable/disable per habit.
- The reminder fires only on days the habit is due (derived from
  `Frequency`, not independently configured).
- The banner exposes **Complete** and **Skip** actions plus the
  default "open app" tap.
- No cloud service, no push server — everything is
  `UNUserNotificationCenter` scheduled from local SwiftData state.

## Current state of the codebase

**No notification infrastructure exists yet.** Zero
`UNUserNotificationCenter` references across `Kado/`, `KadoCore/`,
and the extension targets. Clean slate.

Adjacent code this feature will build on:

- **Model**: `KadoCore/Models/Persistence/KadoSchemaV2.swift` —
  `HabitRecord` with the `Data`-backed enum-storage workaround (needed
  because SwiftData on Xcode 26 still can't round-trip custom enums
  directly; see CLAUDE.md).
- **Frequency evaluation**: `KadoCore/Services/DefaultFrequencyEvaluator.swift`
  already answers "is this habit due on date D given completions C?" —
  the exact predicate we need before scheduling.
- **AppIntent mutation pattern**: `CompleteHabitIntent` in
  `KadoCore/Services/Intents/CompleteHabitIntent.swift` uses
  `ActiveContainer.shared.get()` + `CompletionToggler.toggleToday` +
  `context.save()`. Notification actions reuse this path (the
  "don't open two CloudKit-attached containers per process" rule from
  CLAUDE.md applies).
- **Edit UI**: `NewHabitFormView` doubles as create and edit
  (`HabitDetailView.swift:57-58`). Per-habit reminder controls belong
  inside it.
- **Settings**: `Kado/Views/Settings/SettingsView.swift` — a new
  `NotificationsSection` hooks in alongside `SyncStatusSection` and
  `DevModeSection`.
- **Strings**: `Kado/Resources/Localizable.xcstrings` — hand-author
  new keys (xcstrings isn't auto-synced under `xcodebuild`).
- **Entitlements**: `Kado/Kado.entitlements` already has
  `aps-environment: development`. No change needed for local
  notifications — the APS entitlement is only consulted for remote
  push, but it's already there and harmless.

## Proposed approach

### Key components

- **`NotificationScheduling` protocol + `DefaultNotificationScheduler`**
  (in `KadoCore/Services/Notifications/`). Wraps
  `UNUserNotificationCenter`, injects `FrequencyEvaluating` and
  `Calendar`. Public API:
  - `requestAuthorizationIfNeeded() async -> UNAuthorizationStatus`
  - `rescheduleAll(habits:completions:) async` — the single entry
    point that clears and re-registers every habit's pending
    reminders.
  - `cancel(habitID:)` — local helper used on archive/delete.
- **`NotificationManager` (main app)**: a thin `@MainActor`
  `@Observable` class that owns the `UNUserNotificationCenterDelegate`,
  wires the action identifiers to `CompletionToggler`, and calls
  `rescheduleAll` on: app launch, `.didBecomeActive`, habit
  mutation, and completion toggle. Registered at scene build in
  `KadoApp`.
- **Action handlers**: two `UNNotificationAction` IDs (`.complete`,
  `.skip`) routed through the delegate. The delegate reuses
  `ActiveContainer.shared.get()` + `CompletionToggler` (same path as
  `CompleteHabitIntent`), then calls `rescheduleAll` so a completed
  habit's remaining same-week reminders go away.
- **Per-habit reminder UI**: a new section in `NewHabitFormView`
  with a master toggle + `DatePicker(displayedComponents: .hourAndMinute)`.
  `NewHabitFormModel` gains `remindersEnabled: Bool` +
  `reminderTime: Date`.
- **Settings**: new `NotificationsSection` showing the authorization
  status, a "Request permission" CTA when `.notDetermined`, and a
  deep-link to iOS Settings when `.denied`.

### Data model changes

Append `KadoSchemaV3` with a lightweight migration stage. New
properties on `HabitRecord`, all CloudKit-safe (default-valued):

```swift
var remindersEnabled: Bool = false
var reminderHour: Int = 9     // 0–23
var reminderMinute: Int = 0   // 0–59
```

Storing hour+minute as two `Int`s (rather than a `Date`) keeps the
CloudKit record simple and sidesteps DST/timezone cross-device
ambiguity — the reminder fires at "9:00 local wherever the device
is." This matches Apple's standard reminder semantics. No
`reminderTimeData: Data` wrapper needed because primitives don't
hit the custom-enum storage bug.

### UI changes

- **`NewHabitFormView`**: new `Section("Reminder")` with
  `Toggle("Remind me")` and, when enabled,
  `DatePicker(selection:displayedComponents: .hourAndMinute)`. The
  schedule-days copy underneath reads from the habit's `Frequency`
  so the user sees "Every Mon, Wed, Fri" without a second picker.
- **`SettingsView`**: `NotificationsSection` with status row +
  request/deep-link CTA. No global on/off master switch — if the
  user wants to silence all reminders, iOS Settings already owns
  that affordance.
- **First-run**: on first habit creation with reminders enabled,
  trigger the permission prompt if `.notDetermined`. No
  preemptive prompt at app launch.

### Tests to write

- `DefaultNotificationSchedulerTests`
  - `@Test("Schedules one UNCalendarNotificationTrigger per due day in the next 7 days")`
  - `@Test("Daily frequency yields 7 pending requests")`
  - `@Test("Specific-days(mon/wed/fri) yields 3 pending requests in a typical week")`
  - `@Test("everyNDays(3) anchored to createdAt produces correct day offsets")`
  - `@Test("daysPerWeek(3) with 3 completions already this week yields zero pending requests")`
  - `@Test("rescheduleAll clears requests for archived habits")`
  - `@Test("reminderHour/Minute respect the injected Calendar's timezone")`
- `CompletionTogglerTests` (existing): no change.
- `NotificationActionRoutingTests`: dispatch a fake
  `UNNotificationResponse` with the `.complete` identifier, assert a
  `CompletionRecord` lands in the test context.

Mocking: wrap `UNUserNotificationCenter` behind a
`UserNotificationCenterProtocol` with an in-memory fake that records
`.add` / `.removePendingNotificationRequests(withIdentifiers:)`
calls. Pattern matches the existing `HabitScoreCalculating` /
`FrequencyEvaluating` convention.

## Alternatives considered

### Alternative A: Repeating `UNCalendarNotificationTrigger` per habit

- Idea: one repeating trigger per habit (e.g. daily at 09:00), let
  iOS fire it every day; suppress via a Notification Service
  Extension when the habit is already completed.
- Why not: Notification Service Extensions can mutate content but
  **cannot suppress delivery**. We'd still get the banner on
  already-completed days. Also breaks cleanly for
  `.daysPerWeek` (state-dependent) and `.everyNDays` (not a simple
  weekday pattern).

### Alternative B: Schedule forever, never reschedule

- Idea: on habit create, schedule one repeating trigger; never
  touch it again.
- Why not: same suppression problem. Also misses edits (time
  change, frequency change, archive).

### Alternative C: Use AppIntents as notification actions

- Idea: iOS 17+ allows `UNNotificationAction` to invoke an
  `AppIntent` by identifier.
- Why not (for now): works, but pulls `openAppWhenRun` back into
  the picture. Adding a delegate that calls `CompletionToggler`
  directly is simpler, runs in-process without a relaunch, and
  reuses the same `ActiveContainer.shared` pattern. Can migrate to
  AppIntent-backed actions later if we want them to also show up
  in Focus filters / Shortcuts.

## Risks and unknowns

- **Rescheduling cost.** `rescheduleAll` with 10 habits × 7 days =
  70 `UNNotificationRequest`s. Well under the 64-per-app system
  limit *if we cap at "next 7 days" and re-run on `.didBecomeActive`*.
  Needs verification with a stress test (30 habits → 210 requests
  → exceeds 64, so we cap). Plan: cap at next 7 due occurrences
  per habit and reconcile daily.
- **CloudKit sync semantics.** Pending local notifications are
  device-local, not synced. Two devices independently compute the
  same schedule from the synced habit state — expected behavior,
  but worth a line in the doc.
- **DST.** Reminder semantics are "9:00 local time." A habit
  scheduled in Paris at 9:00 that syncs to a phone in NYC shows
  9:00 NYC. `DateComponents(hour:minute:)` handles this correctly
  — explicit tz pinning in tests as CLAUDE.md requires.
- **Permission denial UX.** If the user denies, the per-habit
  toggle flip must fall back gracefully — we surface the
  status in `SettingsView` and mark the toggle visually disabled
  with a tap-through explanation.
- **Icon**: `UNNotificationActionIcon(systemImageName:)` is
  iOS 15+; we're on 18+ so safe.

## Resolved decisions

- **Skip action = pure dismiss.** No state change, no record.
  Revisit only if "skipped" streaks become a product need; would
  require `CompletionRecord.kind` or a `SkipRecord` type.
- **Banner body = habit name + streak.** Format:
  `"<Habit name> — <N> day streak"` when streak > 0, else just
  `"<Habit name>"`. Reuses `StreakCalculator`; null/zero streaks
  gracefully collapse to name-only.
- **First-run permission prompt** fires on the first habit create
  with reminders enabled, not at app launch. More organic; avoids
  prompting users who never use the feature.

## Deferred

- Snooze action (user chose Complete + Skip only for v0.2).
  Revisit post-v0.2 if feedback asks for it.

## References

- Apple — [UserNotifications framework](https://developer.apple.com/documentation/usernotifications)
- Apple — [UNCalendarNotificationTrigger](https://developer.apple.com/documentation/usernotifications/uncalendarnotificationtrigger)
- Apple — [Handling actions in notifications](https://developer.apple.com/documentation/usernotifications/declaring-your-actionable-notification-types)
- Prior art in repo: `CompleteHabitIntent` (intent mutation pattern),
  `WidgetSnapshotBuilder` (mutation-driven rebuild pattern —
  `rescheduleAll` mirrors this).
