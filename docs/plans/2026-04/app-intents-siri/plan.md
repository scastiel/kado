# Plan — App Intents and Siri

**Date**: 2026-04-20
**Status**: build complete, pending manual Siri verification
**Research**: [research.md](./research.md)

## Summary

Expose Kadō's habit actions to Siri and the Shortcuts app. Refactor
the existing widget-only `CompleteHabitIntent` to speak a
confirmation dialog, build `LogHabitValueIntent` and
`GetHabitStatsIntent` from scratch, and register all three through
a single `AppShortcutsProvider`. Stats-reading stays process-safe
by going through the widget App Group JSON snapshot, not
SwiftData.

## Decisions locked in

- **Bundled scope**: one feature / one PR / one research + plan.
- **Mutating intents**: `openAppWhenRun = true`. Non-negotiable —
  the CloudKit two-container trap forbids running a writer in a
  separate process. Actual visual-foreground behavior is verified
  by Task 1 before we build on it.
- **`GetHabitStatsIntent` reads from the widget snapshot.** This
  requires extending `WidgetHabit` with `currentStreak`,
  `bestStreak`, and `currentScore` (written on every snapshot
  rebuild). Gives the intent a process-independent data source.
- **Suggestions surface = `suggestedInvocationPhrase` only.** No
  `ShortcutTile` / morning-evening predicates in this cycle.
- **Dialog copy (EN + FR) drafted upfront** (see "Copy sheet"
  below). Build tasks paste verbatim.
- **TDD for business-logic tasks** (`CompletionToggler` addition,
  each intent's `apply(...)` static-test surface). Matches the
  pattern in `CompleteHabitIntentTests`.

## Copy sheet

All strings must land in `Localizable.xcstrings` as hand-authored
entries (CLAUDE.md: `.xcstrings` is source, not a build artifact
under `xcodebuild`). FR uses `tu`, `série` for streak, `habitude`
as feminine.

### CompleteHabitIntent

| Context | EN | FR |
|---|---|---|
| Toggled on | `Marked %@ as done.` | `%@, c'est fait !` |
| Toggled off | `Unmarked %@.` | `%@ : décoché.` |
| Counter / timer opens app | `%@ needs a value — opening Kadō.` | `%@ a besoin d'une valeur — j'ouvre Kadō.` |
| Not found (existing) | `This habit no longer exists.` | `Cette habitude n'existe plus.` |
| Archived (existing) | `This habit is archived.` | `Cette habitude est archivée.` |

### LogHabitValueIntent

| Context | EN | FR |
|---|---|---|
| Value prompt | `What value for %@?` | `Quelle valeur pour %@ ?` |
| Logged counter | `Logged %1$@ for %2$@.` | `%1$@ enregistré pour %2$@.` |
| Logged timer (minutes) | `Logged %1$lld minutes for %2$@.` | `%1$lld minutes enregistrées pour %2$@.` |
| Wrong habit type | `%@ is a yes/no habit — say "Complete %@" instead.` | `%@ est une habitude oui/non — dis plutôt « Valide %@ ».` |

### GetHabitStatsIntent

| Context | EN | FR |
|---|---|---|
| Active streak, done today | `%1$@: %2$lld-day streak, score %3$lld%%. Today is done.` | `%1$@ : série de %2$lld jours, score %3$lld %%. Fait aujourd'hui.` |
| Active streak, not done | `%1$@: %2$lld-day streak, score %3$lld%%. Not done today yet.` | `%1$@ : série de %2$lld jours, score %3$lld %%. Pas encore fait aujourd'hui.` |
| No streak | `%1$@: no active streak. Score %2$lld%%.` | `%1$@ : pas de série en cours. Score %2$lld %%.` |
| Archived refused | `%@ is archived.` | `%@ est archivée.` |

### AppShortcut phrases (invocation)

| Intent | EN | FR |
|---|---|---|
| Complete | `Complete \(.applicationName) habit \(\.$habit)` | `Valide l'habitude \(\.$habit) dans \(.applicationName)` |
| Log value | `Log \(\.$value) for \(\.$habit) in \(.applicationName)` | `Enregistre \(\.$value) pour \(\.$habit) dans \(.applicationName)` |
| Stats | `Stats for \(\.$habit) in \(.applicationName)` | `Stats de \(\.$habit) dans \(.applicationName)` |

## Task list

### Task 1: Smoke-test `openAppWhenRun = true` foreground behavior

**Goal**: Resolve the blocking open question before we build dialog
UX on an assumption. Verify: when the user triggers
`CompleteHabitIntent` from Shortcuts on a booted simulator, does
the app visually foreground, or does it run in the background
while Siri speaks?

**Changes**: None (research-only task).

**Verification**:
- `session_show_defaults` → `build_run_sim` to install the current
  build on iPhone 17 Pro sim.
- Open Shortcuts app manually (or via MCP), add a shortcut for the
  existing `CompleteHabitIntent`.
- Run the shortcut. `screenshot` during invocation.
- Record finding in this plan (update "Decisions locked in" and
  cross this task off).
- If the app foregrounds: accept that Siri + Kadō means "Siri
  opens the app and speaks"; update dialog copy accordingly.
- If the app stays backgrounded: proceed with the "silent w/
  spoken reply" UX.

**Commit**: No code commit. A plan update commit if the finding
shifts design.

**Build notes (2026-04-20)**: XcodeBuildMCP in the current install
doesn't expose tap primitives to drive the Shortcuts app (see
CLAUDE.md known-limitation "Tap / type / gesture primitives are
not enabled"). Can't automate this smoke test in the build loop.
**Handed off to user for manual verification pre-merge** (run
Shortcuts app → add Complete Habit shortcut → trigger it → observe
whether app foregrounds). Design proceeds assuming Apple's
documented behavior: `openAppWhenRun = true` + no UI in `perform()`
keeps the app backgrounded. If verification contradicts that,
follow-up PR adjusts Copy sheet only — no structural rework.

---

### Task 2: Extend `WidgetHabit` with streak + score fields

**Goal**: Give `GetHabitStatsIntent` a process-independent read
path. No intent code changes yet — this is the snapshot lift.

**Changes**:
- `Packages/KadoCore/.../Widgets/WidgetHabit.swift`: add
  `currentStreak: Int`, `bestStreak: Int`, `currentScore: Double`.
  All non-optional with defaults for backward-read safety.
- `Packages/KadoCore/.../Widgets/WidgetSnapshotBuilder.swift`:
  compute values via existing `DefaultStreakCalculator` +
  `DefaultHabitScoreCalculator` and set them on each
  `WidgetHabit`.
- `WidgetSnapshotBuilderTests`: extend existing assertions to
  cover the three new fields on a multi-completion fixture.

**Tests / verification**:
- `@Test("Snapshot exposes current streak for a daily habit")`
- `@Test("Snapshot exposes best streak across history")`
- `@Test("Snapshot exposes score as Double in [0, 1]")`
- `test_sim` green.
- Hand-check the widget still renders correctly — we're adding
  fields, not renaming. No widget UI change expected.

**Commit**: `feat(widget-snapshot): expose streak and score for app intents`

---

### Task 3: `KadoAppShortcuts: AppShortcutsProvider` scaffold

**Goal**: Make Siri see Kadō. Register only the existing
`CompleteHabitIntent` first so we can verify registration in
isolation before adding intents that don't exist yet.

**Changes**:
- New file `Kado/App/KadoAppShortcuts.swift` (main app target).
- Registers `CompleteHabitIntent` with EN + FR invocation phrases
  from the Copy sheet (via `LocalizedStringResource`).
- `Localizable.xcstrings`: add the AppShortcut phrase key for
  Complete in EN + FR.

**Tests / verification**:
- `build_sim` clean.
- Launch Shortcuts app on simulator: Kadō appears in the app list
  with "Complete Habit" under it. `screenshot` evidence.
- Add the shortcut, run it, pick a habit, verify completion lands
  in SwiftData (app still opens as before — dialog comes in Task 4).

**Commit**: `feat(app-intents): register AppShortcutsProvider`

---

### Task 4: `CompleteHabitIntent` — add `IntentDialog` output

**Goal**: Siri speaks "Marked X as done" / "Unmarked X" / "X needs
a value — opening Kadō" after the toggle.

**Changes**:
- `CompleteHabitIntent.swift`:
  - Change `perform()` return type to
    `some IntentResult & ProvidesDialog`
  - Return `.result(dialog: IntentDialog(...))` with the three
    cases from the Copy sheet. `Outcome.toggled` branches further
    on "did we add a completion?" vs "did we remove one?" — add a
    third `Outcome` case (`.toggledOn` / `.toggledOff`) to
    preserve testability.
- `CompletionToggler`: `toggleToday(...)` currently returns
  `Void`. Refactor to return a `ToggleResult` enum
  (`.completed` / `.uncompleted`). Keep the caller signature at
  the top level backward-compatible by accepting discard.
- `CompleteHabitIntentTests`: update assertions to match the new
  `Outcome` cases + add a dialog-content assertion per case.
- Catalog: add the four EN + FR entries from the Copy sheet.

**Tests / verification**:
- Existing tests still pass after the `Outcome` split.
- New `@Test("Dialog after toggle-on reads 'Marked X as done'")`
  and `@Test("Dialog after toggle-off reads 'Unmarked X'")`.
- Manual Shortcuts-app run: Siri / iOS speaks or displays the
  dialog string.

**Commit**: `feat(complete-intent): speak confirmation dialog`

---

### Task 5: `CompletionToggler.setValueToday(_:for:in:)`

**Goal**: Give counter / timer intents a primitive that sets an
explicit value (overwriting any existing same-day completion)
instead of toggling. TDD: write the tests first.

**Changes**:
- `Packages/KadoCore/.../Services/CompletionToggler.swift`: new
  method that writes / replaces today's `CompletionRecord` with a
  given `Double` value.
- `KadoTests/CompletionTogglerTests.swift`: add four test cases
  covering counter, timer, overwrite-existing, and zero-value
  handling.

**Tests / verification**:
- `@Test("setValueToday writes a new completion when none exists")`
- `@Test("setValueToday overwrites today's existing completion")`
- `@Test("setValueToday with zero removes today's completion")`
- `@Test("setValueToday respects injected Calendar")`
- `test_sim` green before any intent code consumes it.

**Commit**: `feat(completion-toggler): add setValueToday primitive`

---

### Task 6: `LogHabitValueIntent`

**Goal**: "Log 2 glasses for water" works from Siri and writes a
counter / timer completion.

**Changes**:
- New `Packages/KadoCore/.../Services/Intents/LogHabitValueIntent.swift`:
  - `@Parameter(title: "Habit") var habit: HabitEntity`
  - `@Parameter(title: "Value", requestValueDialog: ...)` as
    `Double`
  - Static `apply(habitID:value:in:calendar:now:)` returning an
    `Outcome` enum (`.logged(value: Double)`,
    `.wrongType(HabitType)`) — mirrors `CompleteHabitIntent`'s
    testable surface
  - `openAppWhenRun = true`, reuses `ActiveContainer.shared`
  - Dialog + error strings from the Copy sheet
  - Timer case: interpret `value` as minutes, multiply to seconds
    internally
- Register in `KadoAppShortcuts`.
- Catalog entries (EN + FR).
- `KadoTests/LogHabitValueIntentTests.swift`: TDD.

**Tests / verification**:
- `@Test("Logs a counter completion with the given value")`
- `@Test("Overwrites same-day counter completion")`
- `@Test("Timer habit logs minutes → seconds internally")`
- `@Test("Binary habit refused with wrongType(.binary)")`
- `@Test("Negative habit refused with wrongType(.negative)")`
- `@Test("Archived habit throws habitArchived")`
- `@Test("Unknown habit id throws habitNotFound")`
- Shortcuts-app manual run with a counter habit.

**Commit**: `feat(app-intents): add LogHabitValueIntent`

---

### Task 7: `GetHabitStatsIntent`

**Goal**: "What's my meditation streak?" speaks a one-sentence
summary. Read path goes through the widget snapshot (Task 2's
foundation), so this intent can run even if the main app isn't
primed — no `ActiveContainer` dependency.

**Changes**:
- New `Packages/KadoCore/.../Services/Intents/GetHabitStatsIntent.swift`:
  - `@Parameter var habit: HabitEntity`
  - `openAppWhenRun = false` — read-only, no SwiftData, safe in
    any process (this is the payoff of the snapshot design).
  - `perform()` reads from `WidgetSnapshotStore.read()` and looks
    up the habit by id. Formats a dialog from streak + score +
    today-completion state.
  - Static `makeDialog(from: WidgetHabit, today: Date, calendar: Calendar)`
    for testability.
- Register in `KadoAppShortcuts`.
- Catalog entries.
- `KadoTests/GetHabitStatsIntentTests.swift`.

**Tests / verification**:
- `@Test("Dialog reports active streak and score")`
- `@Test("Dialog reports zero streak with no completions")`
- `@Test("Dialog distinguishes done-today from not-done-today")`
- `@Test("Score formatted as integer percent 0-100")`
- `@Test("Archived habit refused")` — archived habits aren't in
  the snapshot; check how this surfaces and refuse gracefully.
- Shortcuts-app manual run: Siri speaks the sentence.

**Commit**: `feat(app-intents): add GetHabitStatsIntent`

---

### Task 8: Localization coverage + full-catalog sweep

**Goal**: Every new key has EN + FR. `LocalizationCoverageTests`
stays green.

**Changes**:
- Audit diff: any key added by tasks 3 / 4 / 6 / 7 that wasn't
  author-edited in the catalog, add now.
- Verify `Kado/Resources/Localizable.xcstrings` entries all have
  non-empty FR strings.
- If there's a separate widget-extension catalog, audit it too.

**Tests / verification**:
- `LocalizationCoverageTests` green.
- Manual scan in Xcode's catalog UI (or by opening the JSON) for
  TODO / empty entries.

**Commit**: `feat(app-intents): localize intent titles and dialogs in FR`

---

### Task 9: End-to-end verification pass

**Goal**: Sanity-check the whole track as a user would experience
it — pre-compound.

**Changes**: None (verification only).

**Verification**:
- Boot iPhone 17 Pro sim. `build_run_sim`.
- Shortcuts app: all three intents appear under Kadō with the
  right titles in EN *and* FR (switch simulator language, relaunch).
- Add each as a shortcut, run from Shortcuts app, verify:
  1. Complete: toggles SwiftData + speaks dialog.
  2. Log: prompts for value, writes counter completion.
  3. Stats: speaks streak + score + today status.
- Screenshots per step saved to `docs/screenshots/app-intents/` if
  the screenshot budget is reasonable.
- If a physical device is handy: one live Siri-voice test per
  intent, EN only.

**Commit**: If screenshots are captured:
`docs(app-intents-siri): screenshots from verification pass`.
Otherwise no commit.

## Risks and mitigation

- **Risk**: `openAppWhenRun = true` foregrounds the app on every
  Siri invocation.
  **Mitigation**: Task 1 detects this before we commit to silent
  UX. If it's a hard foreground, rewrite the Copy sheet to match
  ("Opening Kadō and marking X as done…") and accept the
  limitation.
- **Risk**: Simulator can't voice-dispatch Siri (XcodeBuildMCP
  limitation).
  **Mitigation**: Test everything through the Shortcuts app UI,
  which fires the same intents. Live Siri on a device is
  stretch-quality validation.
- **Risk**: `AppShortcutsProvider` changes not picked up by the
  system (Apple recommends kill + relaunch in some cases).
  **Mitigation**: Document the relaunch step in Task 3 and 9
  verification. If an intent appears missing, force-quit Kadō on
  the sim and relaunch before declaring broken.
- **Risk**: `WidgetHabit` schema extension breaks existing
  snapshot consumers (widgets).
  **Mitigation**: All new fields are non-optional with defaults.
  `JSONDecoder` with `nil`-safe defaulting handles older snapshot
  files from pre-upgrade installs. Covered by existing
  `WidgetSnapshotStore` tests.
- **Risk**: `GetHabitStatsIntent` runs before the app has ever
  built a snapshot (fresh install, Siri fires first).
  **Mitigation**: App already seeds the snapshot in its launch
  `.task` (`WidgetSnapshotBuilder.rebuildAndWrite` at
  `KadoApp.swift:39`). If a user installs and asks Siri for stats
  without ever opening the app, intent returns "No Kadō data yet
  — open the app to set up a habit" dialog — worth adding as an
  empty-snapshot case in Task 7's tests.

## Open questions

- [ ] **(Blocking for Task 4)** Does `openAppWhenRun = true` +
  dialog-only `perform()` keep the app backgrounded on iOS 18+?
  **Resolved by Task 1.**
- [ ] Should app-intent strings live in `InfoPlist.xcstrings` vs
  `Localizable.xcstrings`? Verify in Task 3 and document.

## Out of scope

- `ShortcutTile` / `Tip` API for morning / evening lock-screen
  suggestions. Deferred.
- Settings → "Siri & Shortcuts" deep-link row in the app. Nice to
  have; not blocking.
- Unit-aware counter intents ("200 ml" vs "2 glasses"). Requires
  a unit field on `HabitType.counter` — separate feature.
- HealthKit auto-completion. Separate v0.3 track.
- Live Activities. Separate v0.3 track.
- Apple Watch app. Separate v0.3 track.

## Notes during build

- **Task 1** — deferred to manual pre-merge verification. XcodeBuildMCP
  in the current install can't drive Shortcuts-app UI to trigger
  the intent on a booted simulator. Task docs updated with the
  required manual steps.
- **Task 2** — initial test assumption (10-day perfect streak pushes
  EMA past 0.5) was wrong for Kadō's tuned α. Relaxed to the actual
  invariant: score ∈ [0, 1] and > 0 after any completion.
- **Task 4** — `CompletionToggler.toggleToday` return type changed
  from `Void` to `ToggleResult`. Kept `@discardableResult` so three
  existing callers (TodayView, HabitDetailView, tests) stayed
  source-compatible without touching them.
- **Task 6** — `LogHabitValueIntent.Outcome.logged` carries a
  `HabitKind` enum instead of the full `HabitType` so `Equatable`
  stays easy. Dialog switch initially wasn't exhaustive (Swift
  doesn't narrow `.logged` to just counter/timer cases); collapsed
  the timer+counter arms with a wildcard to compile.
- **Task 7** — original dialog factory split the sentence into a
  localized template + untranslated `streakPart` string fragment.
  Collapsed into three full-sentence keys so the catalog owns the
  whole spoken text.

## Verification — handed to the user

Run these on a device or booted simulator before merging:

1. Open Shortcuts app → browse Kadō's actions. Verify three
   appear: **Complete Habit**, **Log Habit Value**,
   **Get Habit Stats**. Both EN and FR phrasings should be
   reachable when the simulator language is switched.
2. Tap a **Complete Habit** shortcut → pick a binary habit → run.
   Observe: does the app foreground, or does Siri speak the
   "Marked X as done" dialog while the app stays in the background?
   **Record the finding** — it's the answer to Task 1's open
   question and decides whether the current Copy sheet needs
   tweaking in a follow-up.
3. **Log Habit Value** on a counter habit → enter a value → run.
   Open the app afterward: the counter's today value should be
   what you logged.
4. **Get Habit Stats** on any habit → Siri should speak a
   one-sentence summary of streak + score + today status.
5. Live Siri test (physical device, EN only): "Hey Siri, complete
   [habit] in Kadō". Same expected dialog.
