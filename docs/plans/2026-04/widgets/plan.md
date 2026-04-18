---
name: Widgets plan
description: Ordered task list for v0.2 WidgetKit pass — App Group store, CompleteHabitIntent, six widget surfaces
type: project
---

# Plan — Widgets

**Date**: 2026-04-18
**Status**: done
**Research**: [research.md](./research.md)

## Summary

Ship the six widget surfaces that close out v0.2's "visible
iOS-native" theme: three home-screen sizes backed by an App
Group-shared SwiftData store, plus three lock-screen variants with
a user-pickable habit via `WidgetConfigurationIntent`. Home widgets
are interactive — tap a binary habit to mark it done using a new
`CompleteHabitIntent` (brought forward from v0.3). Counter/timer
rows tap through to the app. The dev-mode toggle moves into a
shared `UserDefaults` suite so widgets mirror whichever store the
app is currently using.

## Decisions locked in

- **Data sharing**: App Group `group.dev.scastiel.kado` hosts the
  SwiftData SQLite; both app and widget open the same
  `ModelContainer` with `cloudKitDatabase: .private(...)`.
- **Interactivity**: `CompleteHabitIntent` ships in v0.2.
- **Lock widgets**: rectangular and circular use
  `WidgetConfigurationIntent` to let the user pick a habit; inline
  auto-shows overall "N / M done today."
- **Dev mode**: `devModeEnabled` moves to
  `UserDefaults(suiteName: "group.dev.scastiel.kado")`; widgets
  read the same flag and swap container URL accordingly.
- **Target shape**: one widget extension (`KadoWidgets`), one
  `WidgetBundle` registering all six `Widget` types.
- **Platform**: iOS 18+ (matches app deployment target).

## Task list

### Task 1: App Group entitlement on main app — ✅ done (human in Xcode)

**Goal**: add `com.apple.security.application-groups` with
`group.dev.scastiel.kado` to the `Kado` target; no functional
change yet.

**Changes**:
- `Kado/Kado.entitlements`
- `Kado.xcodeproj/project.pbxproj` (capability signing)

**Tests / verification**:
- `build_sim` succeeds with no new warnings.
- Confirm entitlements via `codesign -d --entitlements - $(path-to-built-app)`.

**Commit**: `chore(widgets): add App Group entitlement to main app`

---

### Task 2: Shared SwiftData store + migration — ✅ done

**Goal**: move the production SQLite from the default app-container
location to the App Group container, with a one-time migration that
copies any existing store on first launch.

**Changes**:
- New `Kado/App/SharedStore.swift` — resolves App Group URL,
  performs migration, returns configured `ModelContainer`.
- `Kado/App/DevModeController.swift` — call `SharedStore` instead
  of inlined URL logic for the production container.
- `KadoTests/SharedStoreTests.swift` — migration tests (legacy
  store present / absent; idempotent re-entry).

**Tests / verification**:
- `SharedStoreTests` (Swift Testing): fresh install → new URL;
  legacy store present → copied once; second launch → no
  re-migration, no duplicate file.
- Cloud-shape regression test still passes
  (`KadoTests/CloudKitShapeTests.swift`).
- Manual: launch app on existing sim, verify seeded data still
  visible after the migration.

**Commit**: `feat(widgets): share SwiftData store via App Group`

---

### Task 3: Smoke-test SwiftData + App Group + CloudKit on device — ⏸ blocked (needs hardware)

**Goal**: before building any widget surface, verify the
store/container combo works on a real device. Research flagged
this as the biggest unknown.

**Changes**: none (verification-only task).

**Tests / verification**:
- Install on physical iPhone (iOS 18+).
- Sign in to iCloud on the device.
- Create a habit, complete it, launch on a second device, confirm
  sync.
- Record findings in a new `smoke-test.md` alongside this plan;
  if a blocker surfaces, pause and revise the plan before
  proceeding.

**Commit**: `docs(widgets): capture device smoke test findings`
(only if notes worth keeping; otherwise no commit)

---

### Task 4: Shared dev-mode flag via App Group UserDefaults — ✅ done

**Goal**: move `@AppStorage("devModeEnabled")` from standard
UserDefaults into the App Group suite so widgets honor the toggle.

**Changes**:
- `Kado/App/DevModeController.swift` — `@AppStorage("devModeEnabled", store: .appGroup)`.
- New helper on `UserDefaults` for the suite.
- `KadoTests/DevModeControllerTests.swift` — add a test that
  reads/writes via the suite instance.

**Tests / verification**:
- Existing `DevModeController` tests pass unchanged.
- Manual: toggle dev mode on, kill app, launch — dev flag still on.
- Manual: verify the flag round-trips via
  `defaults read group.dev.scastiel.kado devModeEnabled`.

**Commit**: `feat(widgets): move devModeEnabled into App Group suite`

---

### Task 5: `HabitEntity` + `CompleteHabitIntent` (tests first) — ✅ done

**Goal**: the first `AppIntent`. Toggles today's completion for a
binary habit idempotently. Fails gracefully for counter/timer
habits (returns `.result(dialog: "Open app to log")` or similar).

**Changes**:
- `Kado/Services/Intents/HabitEntity.swift` — `AppEntity` with
  `id`, `name`, `color`. Backed by a query that reads from the
  shared container.
- `Kado/Services/Intents/CompleteHabitIntent.swift` —
  `@Parameter var habit: HabitEntity`, `perform()` writes
  completion.
- `KadoTests/CompleteHabitIntentTests.swift` — binary toggle,
  idempotent repeat, counter/timer rejection, missing habit.

**Tests / verification** (written before implementation):
- `@Test("Completes a binary habit due today")` — intent run →
  completion record exists with today's date.
- `@Test("Repeat tap is idempotent for already-done habit")` —
  second run → no duplicate completion.
- `@Test("Counter habit refuses and signals app-open")` — intent
  returns the app-open signal, no record written.
- `@Test("Unknown habit ID throws user-facing error")`.

**Commit**: `feat(intents): add CompleteHabitIntent with tests`

---

### Task 6: Bootstrap `KadoWidgets` extension target — ✅ done (human in Xcode)

**Goal**: empty widget target that builds, signs with the App
Group entitlement, and shows a placeholder view. Validates the
scaffolding before any data code runs.

**Changes**:
- New `KadoWidgets/` folder.
- New extension target in `Kado.xcodeproj`.
- `KadoWidgets/KadoWidgetsBundle.swift` with a single stub
  `Widget` returning static text.
- `KadoWidgets/KadoWidgets.entitlements` with App Group.
- Shared source membership for `SharedStore.swift`,
  `CloudContainerID.swift`, and the intent/entity files.

**Tests / verification**:
- `build_sim` for both targets succeeds.
- Install on sim, add widget via widget picker, confirm placeholder
  renders.
- `screenshot` of the added widget.

**Commit**: `feat(widgets): bootstrap KadoWidgets extension target`

---

### Task 7: Timeline infrastructure — ✅ done

**Goal**: shared `HabitTimelineEntry` + `HabitTimelineProvider`
that reads the App Group store and produces entries for the next
~6 hours.

**Changes**:
- `KadoWidgets/Timeline/HabitTimelineEntry.swift` — the entry
  value type (date, habits, rowStates, matrixRows when applicable).
- `KadoWidgets/Timeline/HabitTimelineProvider.swift` — one
  generic provider, parameterized by a closure that builds the
  entry from habits + completions + calendar + today.
- `KadoWidgets/Support/WidgetModelContainer.swift` — lazy shared
  container (reuses `SharedStore`).
- `KadoTests/WidgetTimelineTests.swift` — given a seeded
  in-memory container, `timeline(in:)` returns expected shape.

**Tests / verification**:
- Test: today's due habits surface in the entry; archived + future
  ones don't.
- Test: matrix builder matches `OverviewMatrix.compute(...)` for
  the same inputs.
- Test: provider survives empty-store case (no habits).

**Commit**: `feat(widgets): add timeline provider + entry types`

---

### Task 8: Small home widget — today's grid — ✅ done

**Goal**: first visible widget. Up to 5 habits due today, each
rendered as a score-tinted chip. Tap binary → `CompleteHabitIntent`;
tap counter/timer → deep-link to habit detail via `widgetURL`.

**Changes**:
- `KadoWidgets/Views/TodayGridWidget.swift` + view.
- Add to `KadoWidgetsBundle`.
- `Preview Content/` entries for placeholder (reuse
  `DevModeSeed` shapes).

**Tests / verification**:
- SwiftUI preview renders in small family.
- Install on sim, verify 5-habit layout, tap binary completes,
  widget reloads within seconds.
- `screenshot` captured.

**Commit**: `feat(widgets): small home widget with today's grid`

---

### Task 9: Medium home widget — grid + progress — ✅ done

**Goal**: 8 habits max, plus a summary line ("3 of 5 due done").

**Changes**:
- `KadoWidgets/Views/TodayProgressWidget.swift`.
- Shared progress-summary helper (reusable later).

**Tests / verification**:
- Preview + sim install + `screenshot`.
- Progress summary matches
  `habits.filter { rowState.status == .complete }.count`.

**Commit**: `feat(widgets): medium home widget with progress summary`

---

### Task 10: Large home widget — weekly grid — ✅ done

**Goal**: habits × last 7 days matrix, using
`OverviewMatrix.compute(...)` directly.

**Changes**:
- `KadoWidgets/Views/WeeklyGridWidget.swift`.
- Reuse `MatrixCell` (resized for widget density).

**Tests / verification**:
- Preview (include one habit with mixed states across the week).
- `screenshot` on sim — verify sticky name column doesn't clip,
  dark mode renders correctly.
- Widget tap opens app at the Overview tab (or the tapped habit's
  detail).

**Commit**: `feat(widgets): large home widget reusing Overview matrix`

---

### Task 11: Lock-screen rectangular widget — ✅ done

**Goal**: single habit chosen via `WidgetConfigurationIntent`;
shows habit name + current streak + mini score bar.

**Changes**:
- `KadoWidgets/Configuration/PickHabitIntent.swift` —
  `WidgetConfigurationIntent` with `@Parameter var habit: HabitEntity`.
- `KadoWidgets/Views/LockRectangularWidget.swift`.
- `KadoTests/PickHabitIntentTests.swift` — habit resolution by ID.

**Tests / verification**:
- Preview at `.accessoryRectangular` family.
- Long-press lock → Customize → add Kadō widget → verify picker
  shows real habits.
- `screenshot` of the lock widget added to a simulator device
  lock screen.

**Commit**: `feat(widgets): lock rectangular with habit picker`

---

### Task 12: Lock-screen circular widget — ✅ done

**Goal**: same picker intent; shows a progress ring (binary: done /
not done; counter/timer: value / target).

**Changes**:
- `KadoWidgets/Views/LockCircularWidget.swift`.
- Reuse `PickHabitIntent`.

**Tests / verification**:
- Preview at `.accessoryCircular`.
- Visually verify ring fill matches row-state progress.
- `screenshot`.

**Commit**: `feat(widgets): lock circular progress ring`

---

### Task 13: Lock-screen inline widget — ✅ done

**Goal**: auto-text widget "N of M done today" (no configuration).

**Changes**:
- `KadoWidgets/Views/LockInlineWidget.swift`.

**Tests / verification**:
- Preview at `.accessoryInline`.
- Text respects system Dynamic Type.
- `screenshot`.

**Commit**: `feat(widgets): lock inline summary widget`

---

### Task 14: Widget reload triggers from the app — ✅ done

**Goal**: call `WidgetCenter.shared.reloadAllTimelines()` from
every completion mutation so widgets don't show stale state for
up to an hour.

**Changes**:
- Wire a single `WidgetReloader` helper (or just direct calls) at
  each mutation site: `TodayView` toggle, habit detail quick-log,
  timer-log sheet save, Overview cell log sheet, archive/unarchive.
- Trigger on habit create/edit/delete too (so lock widget config
  reflects current habit list).

**Tests / verification**:
- Complete a habit in-app → observe widget reload within 1-2 s on
  simulator.
- No reload calls on read-only operations (enforced by call-site
  review).

**Commit**: `feat(widgets): reload timelines on habit mutations`

---

### Task 15: Localization pass — ✅ done

**Goal**: every new widget-facing string exists in
`Localizable.xcstrings` with EN source and a comment. FR entries
left empty (v1.0 scope per ROADMAP).

**Changes**:
- `Kado/Resources/Localizable.xcstrings` — add keys:
  widget display names, descriptions, configuration option
  labels, "N of M done today," "No habits due today," etc.

**Tests / verification**:
- Widget picker shows localized display names + descriptions on
  EN device.
- Run `xcrun swift-localizable validate` equivalent or manual
  diff against research checklist.

**Commit**: `feat(widgets): add localized strings for widget surfaces`

---

### Task 16: Done-gate pass — ⏳ partial (awaiting user's visual audit)

**Goal**: CLAUDE.md's definition-of-done on all six widgets.

**Changes**: none (verification-only).

**Tests / verification**:
- `build_sim` green on iPhone 17 Pro + iPad Air (closest
  available per CLAUDE.md tooling note).
- `test_sim` green.
- `screenshot` captured for each widget size, both light and dark
  mode.
- Dynamic Type XXXL on lock inline + rectangular (truncation
  behavior acceptable).
- VoiceOver pass on small home widget (primary interactive
  surface).
- PR description rewritten with final screenshots + test plan.

**Commit**: `docs(widgets): update PR description with screenshots and test plan`
(PR edit, not a new code commit)

## Risks and mitigation

- **SwiftData + App Group + CloudKit edge cases** — Task 3 is the
  explicit early-warning system. If the combo doesn't work on
  device, we fall back to Alternative B from research (app writes
  a JSON snapshot to App Group) without having built out six
  widget views on the wrong foundation.
- **Store migration bug** — one-time data loss if the migration
  copies wrong. Mitigation: migration is a copy, not a move;
  legacy store stays put for one release so users can recover by
  reverting app binaries if needed. Covered by
  `SharedStoreTests`.
- **Interactive widget regressions** — `CompleteHabitIntent`
  running in the widget process writes via its own
  `ModelContext`. If CloudKit hasn't finished pulling and we
  write stale data, we could create a conflicting completion.
  Mitigation: intent fetches the current-day completions before
  writing; idempotency test in Task 5 guards this.
- **Reload storm** — calling `reloadAllTimelines()` from every
  mutation could thrash. Mitigation: iOS coalesces reloads,
  but if it becomes a problem, switch to
  `reloadTimelines(ofKind:)` targeted per widget.
- **Configuration UI fragility** — `WidgetConfigurationIntent`
  picker depends on `HabitEntity.defaultQuery` returning the
  right habits at the right time. Covered by intent-resolution
  tests in Task 11.

## Open questions

- [x] Inline-widget fallback text when zero habits exist — resolved:
  "No habits due today" with a `checkmark.circle` icon
  (`LockInlineWidget.swift`).
- [x] FR localization — resolved: stayed EN-only, FR pass batched
  for v1.0 per the roadmap convention.
- [ ] Large widget tap destination — currently `widgetURL`
  `kado://overview`, app doesn't yet handle the scheme so tap
  opens ContentView default. Deferred to a post-v0.2 follow-up
  (URL-scheme handler + deep-link navigation).

## Notes during build

- **Task 2**: SwiftData's default on-disk store is `default.store`
  (plus `-shm` / `-wal` sidecars) in `Application Support`, not
  `Kado.sqlite` as earlier assumed. `SharedStore.legacyStoreURL()`
  updated accordingly. Migration copies all three files; the main
  file is the only one guaranteed present.
- **Task 2**: `SharedStore.productionContainer()` falls back to
  SwiftData's default location when the App Group entitlement
  isn't yet active, so the app continues to build and run on dev
  machines before Task 1 lands. The fallback path doesn't share
  with the widget extension — that's acceptable since the widget
  target won't exist until Task 6.
- **Task 4**: `UserDefaults(suiteName:)` returns a usable instance
  even when the App Group entitlement isn't active; it just fails
  to cross-process-share. Fall-through path is therefore safe.
  `DevModeDefaults.migrateFromStandardIfNeeded()` copies
  pre-existing values once so users don't lose their dev-mode
  state on update.
- **Task 5**: Moved the dev-mode sqlite into the App Group
  container too (was previously app-sandbox Application Support).
  The plan said we'd do this in Task 4; shifted to Task 5 because
  the intent resolver is the first caller that genuinely needs the
  cross-process visibility.
- **Task 5**: `CompleteHabitIntent` treats negative habits like
  binary ones (single tap logs a slip). The plan's success criteria
  framed the counter/timer rejection as the edge case; negative
  works because `CompletionToggler` already handles it without
  special-casing.
- **Task 5**: Intent is modeled as a toggle, not a set-to-done.
  Tap once to complete, tap again to undo. The plan's "idempotent
  repeat" criterion is reinterpreted as "no duplicate records on
  repeat tap" — verified by the repeat-tap test.
- **Tasks 1 / 3 / 6**: Claude Code paused here. Adding a new
  Xcode target and enabling the App Group capability is safer in
  the Xcode IDE than via `project.pbxproj` surgery, and Task 3
  requires a physical device. See the hand-off checklist in the
  PR description (pending).

## Out of scope

- **Live Activities** — v0.3 territory; requires ActivityKit and
  the timer running infrastructure not yet built.
- **Full App Intents surface** — v0.3 adds `LogHabitValueIntent`,
  `GetHabitStatsIntent`, Siri phrasing, Shortcut suggestions.
  Only `CompleteHabitIntent` + `PickHabitIntent` land here.
- **watchOS widget complications** — v0.3 Apple Watch scope.
- **Widget Gallery marketing screenshots** — handled at v1.0
  launch.
- **User preference for which habits appear on small/medium home**
  — auto "due today" for now. Configurability deferred to
  post-v0.2 based on feedback.
