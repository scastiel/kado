# Plan — Notifications

**Date**: 2026-04-18
**Status**: in progress
**Research**: [research.md](./research.md)

## Summary

Add per-habit local reminders for v0.2. Each habit gets one
`remindersEnabled` flag and one `reminderHour:Minute` time. The
scheduler re-derives the next 7 due days from the habit's existing
`Frequency` on every app activate and every mutation, then registers
`UNCalendarNotificationTrigger`s via `UNUserNotificationCenter`. The
banner exposes **Complete** (routes through `CompletionToggler`
in-process via the notification-center delegate) and **Skip** (pure
dismiss). Body is `"<Habit name> — <N> day streak"` when streak > 0,
else name-only.

## Decisions locked in

- Schedule is derived from `Frequency` via the existing
  `DefaultFrequencyEvaluator`. No independent day picker in the UI.
- One fixed `HH:MM` time per habit, stored as two `Int`s on the
  `@Model` (no enum-storage dance — primitives only).
- Action routing through a `UNUserNotificationCenterDelegate` in the
  main app, not AppIntents. Reuses `ActiveContainer.shared` +
  `CompletionToggler` (the same path `CompleteHabitIntent` uses).
- `Skip` is a pure dismiss — no record written, no state change.
- Banner body uses `StreakCalculator`; streak ≤ 0 collapses to
  name-only.
- First permission prompt fires on first habit create with reminders
  enabled, not preemptively at launch.
- Cap at next **7 due occurrences per habit** to stay under the 64-
  pending-request system limit (supports ~9 habits before we trim;
  when we need more, bump to a sliding window rebuilt on activate).
- No Snooze action (deferred post-v0.2).

## Task list

### Task 1: Schema V3 + domain fields ✅

**Goal**: Persist `remindersEnabled`, `reminderHour`, `reminderMinute`
on habits with a lightweight migration from V2. No behavior wired up
yet — fields default to off.

**Changes**:
- `Packages/KadoCore/Sources/KadoCore/Models/Persistence/KadoSchemaV3.swift`
  (new) — copy `KadoSchemaV2.HabitRecord` and append the three
  stored properties. All default-valued. Also mirror the snapshot /
  `Habit` projection.
- `Packages/KadoCore/Sources/KadoCore/Models/Persistence/KadoMigrationPlan.swift`
  — append `MigrationStage.lightweight(fromVersion: KadoSchemaV2.self, toVersion: KadoSchemaV3.self)`
  and `KadoSchemaV3.self` in `schemas`.
- `Packages/KadoCore/Sources/KadoCore/Models/Habit.swift` — add
  `remindersEnabled: Bool`, `reminderHour: Int`, `reminderMinute: Int`.
- Any `Habit` init sites across tests + previews that don't use
  default args: update to pass defaults.
- `KadoTests/CloudKitShapeTests.swift` — no new assertions needed if
  the walk is generic; re-run to confirm V3 still satisfies the
  "both-sides-optional / no @unique / no ordered" rules.

**Tests / verification**:
- New `@Test("V2 store loads into V3 container with reminder fields defaulted off")`
  in `KadoTests/MigrationTests.swift` (create if absent). Seed a V2
  SQLite file via `ModelContainer(for: KadoSchemaV2.self, …)`, close,
  reopen with the V3 migration plan, assert fields = off / 9 / 0.
- `test_sim` passes.

**Commit message**: `feat(schema): add V3 reminder fields to HabitRecord`

---

### Task 2: Scheduler protocol + center wrapper + fake ✅

**Goal**: Define the scheduling surface and the system-API seam
without implementing the real logic yet. Unlocks TDD for task 3.

**Changes**:
- `Packages/KadoCore/Sources/KadoCore/Services/Notifications/UserNotificationCenterProtocol.swift`
  (new) — protocol wrapping the three `UNUserNotificationCenter`
  methods we need: `add(_:)`, `removePendingNotificationRequests(withIdentifiers:)`,
  `pendingNotificationRequests()`, and `requestAuthorization(options:)`.
  Conform `UNUserNotificationCenter` in the main app (not KadoCore —
  the center's init is `@MainActor` and the wrapper stays
  `nonisolated` per CLAUDE.md).
- `Packages/KadoCore/Sources/KadoCore/Services/Notifications/NotificationScheduling.swift`
  (new) — public protocol:
  ```swift
  public protocol NotificationScheduling: Sendable {
      func rescheduleAll(habits: [Habit], completions: [Completion]) async
      func cancel(habitID: UUID) async
      func requestAuthorizationIfNeeded() async -> UNAuthorizationStatus
  }
  ```
- `Packages/KadoCore/Sources/KadoCore/Services/Notifications/DefaultNotificationScheduler.swift`
  (new) — stub that stores the injected center + evaluator + streak
  calculator + calendar. Empty method bodies returning early / trap
  on call. Not wired yet.
- `KadoTests/Notifications/FakeUserNotificationCenter.swift` — in-
  memory `UserNotificationCenterProtocol` recording all calls.
- Environment plumbing: add a `notificationScheduler` entry in
  `EnvironmentValues+Services.swift` using the `@Entry` macro (this
  is a `@MainActor` protocol-existential consumed by Views; mock
  default in `Preview Content/`).

**Tests / verification**:
- `test_sim` passes with the stub present but unreferenced.
- No behavior change user-visible.

**Commit message**: `feat(notifications): add scheduler protocol and test fake`

---

### Task 3: Schedule derivation tests + implementation (TDD) ✅

**Goal**: Given a habit and its completions, produce the correct set
of pending `UNNotificationRequest`s for the next 7 days.

**Changes** (tests first):
- `KadoTests/Notifications/DefaultNotificationSchedulerTests.swift`
  (new):
  - `@Test("Reminders off → no pending requests for the habit")`
  - `@Test("Daily habit yields 7 pending requests over 7 days")`
  - `@Test(".specificDays(mon/wed/fri) yields 3 requests this week")`
  - `@Test(".everyNDays(3) anchored to createdAt spaces requests correctly")`
  - `@Test(".daysPerWeek(3) with 3 completions already this week yields 0 requests")`
  - `@Test("rescheduleAll clears requests for archived habits")`
  - `@Test("rescheduleAll clears requests for habits toggled off")`
  - `@Test("Request identifier format: kado.reminder.<habitID>.<yyyy-MM-dd>")`
  - `@Test("Body shows '<Name> — N day streak' when streak > 0")`
  - `@Test("Body shows '<Name>' only when streak == 0")`
  - `@Test("Trigger uses DateComponents(hour:minute:) in the injected calendar's timezone")`
  - Use `TestCalendar` helper (UTC + Europe/Paris for DST-crossing).
- Then implement `DefaultNotificationScheduler.rescheduleAll`:
  - Iterate habits → for each enabled habit, walk next 7 calendar
    days, skip non-due days via `FrequencyEvaluating.isDue`, build
    `UNCalendarNotificationTrigger` with `DateComponents(year:month:day:hour:minute:)`,
    identifier `kado.reminder.<habitID>.<yyyy-MM-dd>`, content with
    `title = habit.name`, `body = streak string`, `categoryIdentifier = "kado.habit"`,
    `userInfo = ["habitID": habitID.uuidString]`.
  - Before adding new requests, call
    `removePendingNotificationRequests(withIdentifiers:)` filtered to
    this habit's existing `kado.reminder.<habitID>.` prefix.
  - `cancel(habitID:)` removes by identifier prefix.
  - `requestAuthorizationIfNeeded` reads `UNNotificationSettings.authorizationStatus`,
    calls `requestAuthorization(options: [.alert, .sound, .badge])`
    only when `.notDetermined`.

**Tests / verification**:
- All new tests green.
- `test_sim` full suite green.

**Commit message**: `feat(notifications): derive 7-day schedule from Frequency`

---

### Task 4: Reminder section in New/Edit habit form ✅

**Goal**: Let the user enable reminders and pick a time when creating
or editing a habit.

**Changes**:
- `Kado/ViewModels/NewHabitFormModel.swift` — add
  `remindersEnabled: Bool = false`,
  `reminderTime: Date` (default to `Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: .now)!`).
  Extract to `reminderHour` / `reminderMinute` on save via
  `Calendar.component(.hour, from:)`. Preserve time across
  kind switches (same "picker over associated-value" invariant
  pattern as `FrequencyKind`).
- `Kado/Views/NewHabit/NewHabitFormView.swift` — new
  `Section("Reminder")` after the frequency section:
  ```swift
  Toggle("Remind me", isOn: $model.remindersEnabled)
  if model.remindersEnabled {
      DatePicker("Time", selection: $model.reminderTime,
                 displayedComponents: .hourAndMinute)
      // Footer: "Fires on: <frequency description>"
  }
  ```
  Footer text is derived from the habit's `Frequency` using existing
  description helpers (reuse whatever `Frequency` ships; add a short
  one if missing).
- Update preview variants — include one reminders-on preview in the
  file's `#Preview` + the required `#Preview("Dark")`.
- Add localized keys: `"Reminder"`, `"Remind me"`, `"Time"`,
  `"Fires on: %@"` (with `variations` if needed).

**Tests / verification**:
- New regression test: `@Test("Toggling reminders off then on preserves the chosen time")`
  in `KadoTests/NewHabitFormModelTests.swift` (matching the
  existing FrequencyKind invariant test).
- `test_sim` green.
- `screenshot` of the form with reminders enabled (light + dark).

**Commit message**: `feat(new-habit): reminder toggle and time picker`

---

### Task 5: NotificationManager, category + action registration, delegate routing

**Goal**: Register the `.complete` and `.skip` actions with the
system, handle banner taps in-process, save a completion without
relaunch.

**Changes**:
- `Kado/Managers/NotificationManager.swift` (new) — `@MainActor`
  `@Observable` class. On init:
  - Sets `UNUserNotificationCenter.current().delegate = self`.
  - Registers a single `UNNotificationCategory` with identifier
    `"kado.habit"` and two actions:
    - `UNNotificationAction(identifier: "kado.action.complete", title: "Complete", options: [.authenticationRequired])`
    - `UNNotificationAction(identifier: "kado.action.skip", title: "Skip", options: [.destructive])`
  - Conforms to `UNUserNotificationCenterDelegate` (as a
    `NSObject` subclass or extension on a shim — `@Observable` +
    `NSObject` is fine).
- Delegate `userNotificationCenter(_:didReceive:withCompletionHandler:)`:
  - Read `habitID` from `userInfo`.
  - If `.complete` identifier: grab container via
    `ActiveContainer.shared.get()`, `context.fetch` the
    `HabitRecord` by `id`, call `CompletionToggler.toggleToday`,
    `context.save()`, `WidgetSnapshotBuilder.build(from:)` if
    applicable, then `notificationScheduler.rescheduleAll(...)` to
    drop the now-completed day's remaining requests.
  - If `.skip`: just call the completion handler. Pure dismiss.
- `Kado/App/KadoApp.swift` — instantiate `NotificationManager` as a
  `@State` on the root scene and inject via `.environment(...)`.
  Ensure it's created **after** `ActiveContainer` priming (same
  pattern used for the container swap).

**Tests / verification**:
- Unit test `NotificationActionRoutingTests`: construct a fake
  `UNNotificationResponse` (via a testable shim since
  `UNNotificationResponse` has no public init — test the router
  by extracting the routing logic into a free function that takes
  `(actionIdentifier: String, userInfo: [AnyHashable: Any])` and
  returns the decision).
- Manual: run on simulator, schedule a notification 30s out via a
  debug-only menu, observe banner → tap Complete → verify completion
  recorded + banner dismissed + next scheduled request replaced.

**Commit message**: `feat(notifications): register actions and route Complete through toggler`

---

### Task 6: Wire `rescheduleAll` into the app lifecycle

**Goal**: Keep the pending set coherent with SwiftData state.

**Changes**:
- `KadoApp.swift` — call `rescheduleAll` on:
  - `.onAppear` of the root scene (app launch).
  - `.onChange(of: scenePhase)` when transitioning to `.active`.
- `CompletionToggler` call sites — after `context.save()`, call
  `rescheduleAll`. This is already where `WidgetSnapshotBuilder.build`
  runs, so co-locate.
- `HabitRecord` mutation save sites (new habit save, edit save,
  archive, delete) — same pattern.
- Add a small fetch helper in the scheduling entry points: fetch all
  non-archived habits + recent completions (the window is 7 days so
  only the last ~4 weeks of completions are needed for
  `.daysPerWeek`).

**Tests / verification**:
- Manual: create a daily habit with reminders at a time 1 min in the
  future, background the app, observe banner. Tap Complete, confirm
  next day's banner still fires.
- `test_sim` green (no new unit tests — this is plumbing).

**Commit message**: `feat(notifications): rescheduleAll on lifecycle and mutations`

---

### Task 7: First-run permission prompt

**Goal**: When a user saves a new habit with reminders enabled and
authorization is `.notDetermined`, request permission inline.

**Changes**:
- `NewHabitFormView.save()` — before calling `rescheduleAll`, if
  `model.remindersEnabled` and current status is `.notDetermined`,
  `await notificationScheduler.requestAuthorizationIfNeeded()`. If
  denied: show an inline `.alert` explaining and pointing to iOS
  Settings via `UIApplication.shared.open(URL(string: UIApplication.openNotificationSettingsURLString)!)`.
- No preemptive prompt anywhere else.

**Tests / verification**:
- Manual: reset simulator (`xcrun simctl privacy … reset notifications`)
  or wipe app, create a reminders-on habit, confirm prompt fires
  once; subsequent saves do not reprompt.

**Commit message**: `feat(notifications): request authorization on first reminders-on save`

---

### Task 8: SettingsView → NotificationsSection

**Goal**: Let the user see permission state and jump to iOS Settings
without opening the Settings app manually.

**Changes**:
- `Kado/Views/Settings/NotificationsSection.swift` (new) —
  `@Observable` wrapper fetches `UNNotificationSettings` in
  `.task`. Row variants:
  - `.authorized` / `.provisional` / `.ephemeral`:
    "Notifications on" with a chevron to iOS Settings.
  - `.denied`: red label "Notifications off — enable in Settings"
    with a button opening `openNotificationSettingsURLString`.
  - `.notDetermined`: "Notifications not yet requested. Create a
    habit with a reminder to enable them."
- `Kado/Views/Settings/SettingsView.swift` — add
  `NotificationsSection()` between `SyncStatusSection()` and
  `DevModeSection()`.
- Add localized keys: `"Notifications"` (section header),
  `"Notifications on"`, `"Notifications off"`, etc.
- Previews (light + dark) with each status.

**Tests / verification**:
- Manual: toggle notifications in iOS Settings, return to app,
  observe row reflects the new status.
- `screenshot` of Settings with each status (at least 2: authorized
  + denied).

**Commit message**: `feat(settings): surface notification authorization status`

---

## Integration checkpoints

- **Schema V3 migration** (task 1): confirm V2 → V3 lightweight
  stage actually migrates a seeded SQLite. Add a regression test
  if one doesn't cover migrations yet.
- **CloudKit shape** (task 1): re-run `CloudKitShapeTests` to
  confirm the three new primitive fields stay CloudKit-safe. No
  changes expected since they're all default-valued primitives.
- **AppIntents container rule** (task 5): confirm delegate handler
  reaches `ActiveContainer.shared.get()` — not
  `SharedStore.productionContainer()`. The "two CloudKit-attached
  containers per process" rule applies to the delegate just like
  it does to intents.
- **Widget snapshot** (task 5): delegate's Complete path must call
  `WidgetSnapshotBuilder.build` like other completion paths, else
  widgets lag behind notifications.
- **Dev mode swap** (task 6): when `DevModeController` swaps
  containers, `rescheduleAll` must re-run against the new
  container's state. Add a hook in the swap path.
- **Localization** (task 4, 8): add new xcstrings entries by hand
  (not via xcodebuild). Each entry needs a `comment` per
  CLAUDE.md.

## Risks and mitigation

- **64-request system limit**: capped at 7 days × N habits; >9
  habits will exceed. Mitigation: recalc on every `.active`
  transition (cheap) and trim the oldest pending requests. If
  stress testing shows >9 habits is a common case, we'll switch
  to a sliding-window approach that only pre-registers the next
  2-3 days and leans on `.active` rescheduling.
- **Permission denial UX**: surface in Settings + inline-alert on
  first-run prompt. The toggle itself stays user-togglable (we
  don't force-off), matching Apple's "user is always in charge"
  guidance.
- **DST correctness**: `DateComponents(hour:minute:)` + an injected
  `Calendar` avoids raw-seconds arithmetic. Test the `.daily` case
  with a DST-crossing `Europe/Paris` calendar per CLAUDE.md.
- **Widget/notification divergence**: route the delegate's Complete
  path through the same `CompletionToggler` + `WidgetSnapshotBuilder`
  sequence that `CompleteHabitIntent` uses. If we miss the snapshot
  rebuild, widgets will stay stale until next mutation.
- **Dev-mode container swap**: if the scheduler holds a stale
  container reference, it will write completions to the wrong
  store. Use `ActiveContainer.shared.get()` at call time, never
  cache.

## Open questions

None. All three from research were resolved before planning.

## Out of scope

- **Snooze action.** Deferred post-v0.2. When added, it's another
  `UNNotificationAction` routed through the delegate; no schema
  change needed.
- **Independent day picker.** Schedule is always derived from the
  habit's existing `Frequency`. If users later ask for "remind me
  Mon+Wed even though the habit is daily," that's a schema change.
- **Remote push / cross-device coordination.** Each device schedules
  independently from synced habit state.
- **Notification grouping by habit.** iOS groups by thread-id by
  default; we may add `threadIdentifier = habit.id.uuidString` if
  clutter becomes a complaint.
- **Quiet hours / per-day override.** If a user wants a weekday-
  only reminder, set the habit's Frequency to weekdays. No separate
  quiet-hours UI.
- **Widget-side notification badges.** Widgets stay read-only; the
  badge count (if any) is app-icon only.
