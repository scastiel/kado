---
# Plan — Translations catalog for v0.1

**Date**: 2026-04-17
**Status**: ready to build
**Research**: [research.md](./research.md)

## Summary

Make `Kado/Resources/Localizable.xcstrings` complete, consistent, and
translation-ready so that v1.0's FR pass is purely a translator's job.
No user-visible EN change. Two phases: normalize every user-facing
call site to `LocalizedStringKey` or `String(localized:)`, then curate
the auto-extracted catalog with translator comments and plural
variants for the ~12 count-driven interpolations.

## Decisions locked in

- **English text as catalog keys** (Xcode 16 default). Use `comment`
  to disambiguate duplicates; only namespace on genuine conflict.
- **Weekday labels consolidated** onto the `Weekday` enum
  (`localizedShort`, `localizedFull`). Both `WeekdayPicker` and
  `MonthlyCalendarView` migrate.
- **Pseudo-locale verification is manual** for v0.1 (launch with
  `-AppleLocale en_XA` on iPhone 16 Pro, spot-check each view). No
  automated test. Formalize in v1.0 pre-FR pass.
- **Time formatter migration (`String(format:)` → `DateComponentsFormatter`)
  is out-of-scope.** Flagged for a separate pre-v1.0 PR.
- **No `LOCALIZATION_PREFERS_STRING_CATALOGS` build-setting change**
  unless Xcode 16 requires it — the project already uses
  `.xcstrings`; verify during Task 1's smoke build.
- **Scope excludes `NSUsageDescription` strings** — none exist yet
  (HealthKit / CloudKit / biometrics land in v0.2+).

## Task list

Each task leaves the project compiling, tests green, and the visible
EN UI unchanged. The `Localizable.xcstrings` file grows on every
normalization task (Xcode auto-extracts on build); commit it alongside
its source change to keep diffs narrow.

### Task 1: Weekday helpers + migrate consumers ✅

**Goal**: add `Weekday.localizedShort: String` and
`Weekday.localizedFull: String` so weekday labels have one source of
truth and localize through the catalog.

**Changes**:
- `Kado/Models/Weekday.swift` — add both computed properties returning
  `String(localized:)` values with clear translator comments.
- [WeekdayPicker.swift:46–64](Kado/UIComponents/WeekdayPicker.swift) —
  replace hardcoded `"M"..."Sunday"` with
  `weekday.localizedShort` / `weekday.localizedFull`.
- [MonthlyCalendarView.swift:82–88](Kado/Views/HabitDetail/MonthlyCalendarView.swift) —
  replace column-header literals with `Weekday.allCases.map(\.localizedShort)`.
- `Kado/Resources/Localizable.xcstrings` — auto-extracted entries for
  14 keys (7 short + 7 full).

**Tests / verification**:
- Existing `test_sim` stays green (no existing tests target these
  views' text content directly).
- Quick preview check: `WeekdayPicker` and `MonthlyCalendarView`
  previews render identical labels.

**Commit message**: `refactor(weekday): consolidate localized labels onto Weekday enum`

---

### Task 2: Normalize ContentView + SettingsView ✅ (no-op)

**Goal**: close the `Tab()` / `ContentUnavailableView` localization
leaks flagged in research.

**Changes**:
- [ContentView.swift:12,15](Kado/Views/ContentView.swift) — wrap tab
  titles: `Tab(String(localized: "Today"), ...)`,
  `Tab(String(localized: "Settings"), ...)`. (`Tab.init` takes a
  `String` for the title, not a `LocalizedStringKey`, so the explicit
  wrap is required.)
- [SettingsView.swift:11,13,15](Kado/Views/Settings/SettingsView.swift) —
  wrap the `ContentUnavailableView` title (String-typed) and
  `navigationTitle` if not already `Text`-wrapped.

**Tests / verification**:
- Launch sim, confirm tab bar + settings placeholder read identically.
- Check `.xcstrings` gained `"Today"`, `"Settings"`,
  `"Preferences will land here as the app grows."`.

**Commit message**: `chore(l10n): wrap tab titles and settings placeholder`

---

### Task 3: Normalize TodayView ✅ (no-op)

**Goal**: localize empty-state strings and the "New habit" toolbar
label.

**Changes**:
- [TodayView.swift:31,45,47,53,55](Kado/Views/Today/TodayView.swift) —
  wrap `"New habit"`, `"No habits yet"`, `"Habits you create will
  appear here."`, `"Nothing due today"`, `"Come back tomorrow, or
  check your habit detail to log a past day."`. Most just need to pass
  through `LocalizedStringKey`; `ContentUnavailableView`'s String-typed
  init needs `String(localized:)`.

**Tests / verification**:
- Run the empty-state preview and the loaded preview; confirm visual
  parity.
- `.xcstrings` now has the five strings above.

**Commit message**: `chore(l10n): localize Today view empty states and toolbar`

---

### Task 4: Normalize NewHabitFormView

**Goal**: localize picker options, Cancel/Save buttons, and the
conditional navigation title.

**Changes**:
- [NewHabitFormView.swift:23](Kado/Views/NewHabit/NewHabitFormView.swift) —
  replace `Text(model.isEditing ? "Edit Habit" : "New Habit")` with
  two explicit `String(localized:)` keys so each arm feeds the
  catalog. `.navigationTitle(Text(...))` stays; the literal lookup is
  done beforehand.
- Lines 27, 30 — `Button("Cancel")`, `Button("Save")` already go
  through `LocalizedStringKey`, so no source change — verify they
  appear in the catalog after build.
- Lines 50–53, 81–84 — `Text(...)` picker options already go through
  `LocalizedStringKey`; verify extraction.
- Lines 61, 70, 92, 99 — interpolated stepper labels are already
  `String(localized:)`; no source change, but translator comments go
  in during Task 7.

**Tests / verification**:
- Open the form preview (default + counter + specific-days variants);
  all labels render identically.
- `.xcstrings` gains picker options, button labels, both
  nav-title variants.

**Commit message**: `chore(l10n): localize new habit form strings`

---

### Task 5: Normalize HabitDetailView + TimerLogSheet + CompletionHistoryList

**Goal**: wrap the remaining raw literals in the detail surface
(`"Archived"` badge, timer-sheet headers/footers/buttons, history
section header, empty state, "Delete" swipe action).

**Changes**:
- [HabitDetailView.swift:144](Kado/Views/HabitDetail/HabitDetailView.swift) —
  wrap `"Archived"` badge text.
- [HabitDetailView.swift:99](Kado/Views/HabitDetail/HabitDetailView.swift) —
  `Label("Log a session", systemImage: ...)` already takes
  `LocalizedStringKey`; verify extraction.
- [TimerLogSheet.swift:33,35,38,42,45](Kado/Views/HabitDetail/TimerLogSheet.swift) —
  wrap section header, footer, nav title, Cancel, Save. Most can use
  `Text("…")` / `Button("…")` directly (LocalizedStringKey path).
- [CompletionHistoryList.swift:19,24,73](Kado/Views/HabitDetail/CompletionHistoryList.swift) —
  wrap `"History"`, `"No history yet."`, `"Delete"`.

**Tests / verification**:
- `HabitDetailView` preview (and archive-state variant), timer sheet
  preview, history list preview — all visually identical.
- `.xcstrings` gains these ~10 entries.

**Commit message**: `chore(l10n): localize detail view, timer sheet, and history list`

---

### Task 6: Curate catalog — comments + plural variants

**Goal**: turn the raw extracted catalog into something a translator
can work with cold. This is the only task that edits `.xcstrings`
directly (rather than via auto-extraction).

**Changes**:
- `Kado/Resources/Localizable.xcstrings`:
  - Add a `comment` on every key describing where it appears and what
    it means. Format: imperative, context-first, under ~80 chars.
    Example for `"New habit"`: `"Toolbar button that opens the
    new-habit sheet from Today view"`.
  - Declare plural variants (`one` / `other`) for these 12 keys:
    - `"%lld days per week"` (from `NewHabitFormView` and
      `HabitDetailView`)
    - `"Every %lld days"` (both views)
    - `"%lld days ago"` (`CompletionHistoryList`)
    - `"%lld min"` (`TimerLogSheet`, likely
      `"%lld minute"` / `"%lld minutes"` in EN plural forms)
    - `"Target: %lld"` (counter stepper)
    - `"Target: %lld min"` (timer stepper)
    - `"Counter · target %lld"` / `"Timer · target %lld min"` (habit
      detail subtitle)
    - `"%lld / best %lld"` (streak metric — needs per-arg plural
      handling; document if not cleanly expressible)
    - `"of %lld"` (counter quick-log)
    - Accessibility: `"%@, counter, target %lld"`,
      `"%@, timer, target %@"` (these mix `%@` and `%lld`; plural
      applies only to `%lld`).
  - For strings that appear identically in two views (e.g.
    `"Every day"`, `"Yes / no"`), ensure they collapse to one catalog
    entry and the comment covers both contexts.

**Tests / verification**:
- `build_sim` stays green.
- Open the `.xcstrings` in Xcode, confirm the plural editor shows
  `one` / `other` filled for EN.
- `test_sim` stays green.

**Commit message**: `chore(l10n): add translator comments and plural variants`

---

### Task 7: Manual pseudo-locale verification

**Goal**: prove every visible string is in the catalog by running the
app in the accented-pseudo-locale (`en_XA`) and eyeballing each view.

**Changes**:
- None to the project. This task is a verification gate.
- Procedure:
  1. `build_run_sim` with scheme arguments appended:
     `-AppleLanguages (en-XA) -AppleLocale en_XA`. Confirm the MCP
     tool path, or if unsupported, launch via Xcode's scheme editor
     once.
  2. Navigate Today (empty + loaded), open a habit, open the
     edit form, open timer log sheet, swipe to delete a completion,
     hit the archive confirmation, open Settings.
  3. Every visible string should appear with accents (e.g.
     `"T̂ôd̂áŷ"`). Any plain-ASCII string is **not** in the catalog —
     treat as a bug, fix before closing.
- Report back with a short list of any leaks found and a screenshot
  confirmation of one or two views.

**Tests / verification**: the pseudo-locale UI check is itself the
test.

**Commit message (if fixes found)**:
`fix(l10n): catch strings missed by pseudo-locale verification`

---

### Task 8: Mark plan `done` and wrap up

**Goal**: close out the PR for review.

**Changes**:
- Update `plan.md` status to `done`.
- Flip the GitHub PR from draft to ready for review.
- (Compound stage happens next, as its own conductor step.)

**Commit message**: `docs(translations-catalog): mark plan done`

## Risks and mitigation

- **Xcode auto-extraction misses a string**: spotted by the Task 7
  pseudo-locale pass. Mitigation: that task is the explicit gate.
- **`.xcstrings` diff noise across commits**: Xcode reorders the JSON
  occasionally. Mitigation: if it bites, pre-commit sort script.
  Defer unless it actually makes reviews hard.
- **`Tab.init` signature surprise**: research assumes `Tab("Today", ...)`
  takes `String`, not `LocalizedStringKey`. Verify on Task 2 build;
  if it accepts `LocalizedStringKey`, drop the `String(localized:)`
  wrap and save one extraction step. No functional impact either way.
- **Plural variant for multi-arg format strings** (`"%lld / best %lld"`):
  `.xcstrings` plural handling is per-argument and can be awkward for
  multi-`%lld` formats. Mitigation: if it doesn't express cleanly,
  restructure the string (e.g. separate labels for current and best)
  rather than fight the tooling. Decide when we hit it in Task 6.
- **`en_XA` pseudo-locale launch argument flakiness under MCP**:
  the `build_run_sim` wrapper may not expose custom launch args. If
  so, launch once via Xcode's scheme editor and report back. Don't
  block progress on MCP ergonomics.

## Open questions

None blocking. Deferred:
- **Automated pseudo-locale test**: revisit during v1.0 pre-FR pass.
- **`.xcstrings` stable-sort hook**: revisit if diffs become unreadable.

## Notes during build

- **Task 1 pivot**: instead of hand-rolling 14 catalog entries for
  weekday labels, the helpers now wrap
  `Calendar.veryShortStandaloneWeekdaySymbols` and
  `Calendar.standaloneWeekdaySymbols`. Strictly better: auto-localized
  in every language Apple ships, removes the `"T"/"T"` and `"S"/"S"`
  EN-collision problem entirely, and drops 14 keys from Task 6's
  curation scope. Zero visible EN change (EN symbols match what we
  were typing by hand).
- **Task 2 no-op**: `Tab(_:systemImage:)`,
  `ContentUnavailableView(_:systemImage:description:)`, and
  `.navigationTitle(_:)` all accept `LocalizedStringKey` in iOS 18.
  Research flagged these as raw-literal leaks — they aren't. Source
  already correct; strings will surface in the catalog during Task 6.
- **Catalog auto-population under xcodebuild**:
  `LOCALIZATION_PREFERS_STRING_CATALOGS=YES` and
  `SWIFT_EMIT_LOC_STRINGS=YES` are set, but `xcodebuild` (MCP) does
  NOT write the extracted strings back into the `.xcstrings` file
  during a normal build — that sync happens in the Xcode IDE. Impact:
  Task 6 hand-authors the catalog JSON from the inventory rather than
  relying on auto-extraction. Same endpoint, just more explicit. The
  hand-authored keys will be preserved by Xcode on future extractions
  (it merges, doesn't overwrite).

## Out of scope

- **FR translations** (v1.0).
- **`String(format: "%02d:%02d", ...)` time formatters** in
  `HabitRowView` and `CompletionHistoryList` — separate PR, pre-v1.0.
- **`DateFormatter` style tuning** — formatters already localize via
  `Locale.current`; nothing to do at catalog level.
- **`NSUsageDescription` entries** — none exist yet; lands with
  v0.2 HealthKit / widgets / notifications work.
- **Generated Swift enum for keys** (SwiftGen-style) — rejected in
  research; third-party dep is forbidden for v0.x.
- **Compound stage** — handled as a separate conductor step after the
  build tasks land.
