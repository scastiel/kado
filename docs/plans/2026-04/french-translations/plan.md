---
# Plan — French translations

**Date**: 2026-04-19
**Status**: done
**Research**: [research.md](./research.md)
**Compound**: [compound.md](./compound.md)

## Summary

Deliver native French across the whole app by hand-editing
`Localizable.xcstrings`. Before drafting, clean up the catalog
(collapse one duplicate, add a couple of missing format shells,
resolve 22 stale entries). Then draft FR in **8 feature chunks** via
a draft-review loop — Claude proposes, the author (native speaker)
reviews and revises. Wrap with a regression test, an FR-locale
`build_sim` + `test_sim` pass, a pseudo-locale IDE smoke test, and
a ROADMAP move.

## Decisions locked in

- **Second person**: `tu`. Warm, matches Streaks/Loop FR and Apple's
  HIG personal-app default.
- **Streak** → `série`. Short, natural, widely used in FR habit apps.
- **Score** kept as-is (same word in FR, already used in sports /
  gaming).
- **Habit** → `habitude` (feminine) — drives agreement rules.
- **App name** "Kadō" kept as-is with the macron.
- **Widget lock-screen streak suffix**: localize. `d` → `j` via a
  new catalog key.
- **Pseudo-locale smoke test**: do it now as part of verification.
  IDE-only step (author-run); Claude prepares the checklist.
- **Author = final arbiter on FR content**. Claude drafts, author
  edits or confirms per chunk commit.
- **PR stream**: single PR (`feature/french-translations`, draft
  PR [kado#20](https://github.com/scastiel/kado/pull/20)). Mark
  ready for review after Task 15.
- **Test suite**: one test — walk `.xcstrings`, assert every EN
  key has a non-empty FR translation. Land it once all FR content
  is in so CI stays green through Phase 2.

## FR style conventions (lock these before drafting)

Apply consistently across every chunk:

- Second-person singular (`tu`, `ton`, `ta`, `tes`).
- Verb-first imperatives where EN is imperative
  ("Add habit" → "Ajoute une habitude"). Avoid infinitive forms
  except in toolbar buttons where EN already uses an infinitive
  (`Cancel` → `Annuler`, `Save` → `Enregistrer`).
- Gender-neutral phrasing where natural, but default to the
  grammatical gender of the antecedent when it forces agreement
  (habitude → feminine). Don't contort phrases for neutrality.
- Keep technical loanwords intact when French already accepts them
  (`score`, `widget`, `streak` → `série`, `emoji`). Don't invent
  French equivalents for terms iOS users already read in English
  elsewhere.
- Avoid hyphens in strings where French prefers spaces
  ("iCloud sync" → "Synchronisation iCloud", not "Sync-iCloud").
- Prefer sentence-case consistent with EN. Don't capitalize every
  noun.
- Date / number formatting: rely on `DateFormatter` / `NumberFormatter`
  with `Locale.current`. No manual tweaks.

## Task list

### Phase 1 — Catalog prep

#### Task 1: Catalog hygiene

**Goal**: make the catalog FR-ready without touching any FR content.

**Changes**:
- `Kado/Resources/Localizable.xcstrings`:
  - Remove the orphan empty key (`"" : {}` at line 4).
  - Resolve the 22 `extractionState: "stale"` entries. For each:
    grep the codebase; if still referenced, drop the `stale` flag;
    if genuinely unused, delete the entry.
  - Collapse the duplicate empty-state copy in
    `Kado/Views/Overview/OverviewView.swift:74`
    (`"Habits you create will show up here with their history."`)
    to the existing `"Habits you create will appear here."` key by
    editing the Swift source, not the catalog.
- `Kado/Views/HabitDetail/HabitDetailView.swift:~278` — verify every
  `String(localized: "Counter · target \(Int(target))")`-style call
  site has its extracted format-shell key present in the catalog
  (`"Counter · target %lld"`, etc.). Add any missing shells with
  translator comments; do not fill FR yet.
- `Kado/Views/Settings/SyncStatusSection.swift:76` — the
  `"\(title). \(subtitle)"` glue concat: leave for Task 11 unless
  the grep turns up something worse.

**Tests / verification**:
- `build_sim` green, no new warnings.
- `test_sim` green (all 106 passing).
- Catalog diff is cleanup-only — no FR entries yet.

**Commit message (suggested)**: `chore(l10n): catalog hygiene ahead of FR pass`

---

#### Task 2: Add missing format shells

**Goal**: every user-facing surface has a catalog key by the time
drafting starts.

**Changes**:
- `KadoWidgets/.../LockCircularWidget.swift:53` — bare number is
  fine as-is (digits are locale-neutral); leave.
- `KadoWidgets/.../LockRectangularWidget.swift:43` — replace
  `Text("\(row.streak)d")` with a localized format. Add catalog
  key `"%lldd"` with comment "Short streak suffix on the lock-screen
  rectangular widget. Arg: streak length in days." Leave
  `LockRectangularWidget.swift:48` (`"\(row.scorePercent)%"`) as-is;
  `%` is universal.
- If Task 1's verification turns up additional missing shells, add
  them here.

**Tests / verification**:
- `build_sim` on Widgets scheme green.
- Screenshot the Kado lock-screen widget on iPhone 17 Pro (EN
  still); confirm "Nd" renders correctly.

**Commit message (suggested)**: `chore(l10n): add missing format shells for widgets`

---

### Phase 2 — FR drafting (one commit per chunk, draft → review)

For each of Tasks 3–10: Claude drafts the FR strings directly in
`.xcstrings` per the style conventions above, including plural
variants (`one`/`other` with FR grammar) on count-driven keys.
Author reviews the diff, edits anything off-key, then commits
or asks for a revision. Each chunk is ~15-30 keys; keeping them
small keeps review pace steady.

#### Task 3: FR — New Habit form

**Goal**: the habit-creation flow reads naturally in FR.

**Scope** (catalog keys, approx.):
- Section headers: `Habit name`, `Appearance`, `Frequency`, `Type`,
  `How is it measured?`
- Frequency labels: `%lld days per week` (with FR plurals),
  `%lld specific days`, `Every %lld days` (FR plurals), `Daily`.
- Type labels: `Yes / no`, `Counter`, `Timer`, `Avoid`.
- Stepper/picker ancillaries, unit labels (`minutes`, `hours`).
- Toolbar: `Cancel` → `Annuler`, `Save` → `Enregistrer`.
- Validation: placeholder text, required-field messages.

**Changes**: `Kado/Resources/Localizable.xcstrings` only.

**Tests / verification**: `build_sim` green. Manual: open New Habit
sheet under fr_FR, confirm rendering.

**Commit message (suggested)**: `feat(l10n/fr): new habit form`

---

#### Task 4: FR — Today tab

**Goal**: Today view (tab, list, row actions, empty states) in FR.

**Scope**:
- Tab label: `Today` → `Aujourd'hui`.
- Empty states: `No habits yet`, `Habits you create will appear here.`
  → `Aucune habitude pour l'instant`,
  `Les habitudes que tu crées apparaîtront ici.`
- Section headers: `Scheduled`, `Not scheduled today`.
- Row actions: `Log session`, `Log value`, `Log specific value…`,
  `Open detail`, `Edit`, `Archive`, `Archive this habit?`,
  `Increment`, `Decrement`, `Add 5 minutes`, `Undo`, `Mark as done`,
  `Mark as not done`, `Slipped`.
- VoiceOver labels (`%@, %@`, `%@, counter, target %lld`,
  `%@, timer, target %@`, `%@, streak %lld, score %lld percent`,
  `%@, score %lld percent`) — keep `%1$@`-style placeholders,
  localize the glue/words only.

**Changes**: catalog only.

**Tests / verification**: FR screenshot of Today (empty, 1 habit,
multiple habits).

**Commit message (suggested)**: `feat(l10n/fr): today tab`

---

#### Task 5: FR — Habit Detail

**Goal**: detail view, metric cards, score explanation, history in FR.

**Scope**:
- Metric card headers: `Streak` → `Série`, `Score` unchanged,
  `%lld / best %lld` → `%lld / meilleure %lld` (feminine agreement).
- Score explanation popover: `About this score` and the 4 bullets
  about EMA decay, scheduled days, young-habit ramp.
- History list: date labels (rely on `Calendar`), relative dates
  `%lld days ago` (FR plurals — "il y a 1 jour" / "il y a 2 jours"),
  empty-state for history.
- Edit/Archive toolbar buttons.
- Log a session / Log value sheet: `Log a session`, `Log value`,
  target copy, time picker labels.
- Calendar grid: month header format, day-of-week row (handled by
  `Calendar.standaloneShortWeekdaySymbols` — free).
- Type descriptors: `Counter · target %lld`,
  `Timer · target %@`, etc.

**Changes**: catalog only. Sanity-check the `String(localized:)`
interpolations flagged in Task 1 — may need a small Swift tweak if
Xcode didn't extract them.

**Tests / verification**: FR screenshot of Detail view with a
counter habit, a timer habit, and the score popover open.

**Commit message (suggested)**: `feat(l10n/fr): habit detail`

---

#### Task 6: FR — Multi-habit Overview

**Goal**: overview grid + cell popover in FR.

**Scope**:
- Tab label: `Overview` → `Vue d'ensemble`.
- Cell states: `Completed` → `Complété/ée` (agree with antecedent;
  rephrase to avoid gender if cleaner, e.g. `Fait`), `Missed` →
  `Manqué`, `Not scheduled` → `Non prévu`, `Upcoming` →
  `À venir`, `upcoming` (lowercase variant).
- Cell popover: `%lld%% complete` → rephrase to
  `%lld %% accompli` (masculine, avoids habit-gender agreement) or
  equivalent; finalize during draft.
- Empty state (post-Task 1 dedupe).

**Changes**: catalog only.

**Tests / verification**: FR screenshot of Overview with 3+ habits
and 14 days visible.

**Commit message (suggested)**: `feat(l10n/fr): overview`

---

#### Task 7: FR — Settings

**Goal**: Settings tab end-to-end in FR.

**Scope**:
- Tab label: `Settings` → `Réglages` (standard Apple FR).
- Sections: `Data`, `Notifications`, `Sync`, `About`.
- Notifications sub-section: `Notifications on/off`, `not yet
  requested`, `Open Settings`, `Enable notifications in Settings…`,
  `Reminders are delivered…`, `Reminders won't fire…`, `You'll be
  asked…`.
- Sync sub-section: `Syncing with iCloud`, `Not signed in to iCloud`,
  `iCloud is temporarily unavailable`.
- Data sub-section: `Export Data`, `Import Data`,
  `Last export: %@`, `Import Kadō backup`, `Completions`, `Habits`,
  `%lld (%lld new, %lld updated)` — **needs FR plural variants**
  for `new` (nouveau/nouveaux/nouvelle/nouvelles) and `updated`
  (modifié/modifiée/modifiés/modifiées). Finalize during draft.
- About: app name, version, legal links (keep URLs).

**Changes**: catalog only.

**Tests / verification**: FR screenshot of Settings root + one
nested sheet.

**Commit message (suggested)**: `feat(l10n/fr): settings`

---

#### Task 8: FR — Widgets

**Goal**: all widget kinds and lock-screen fallbacks in FR.

**Scope**:
- Widget kind display names and descriptions (the 22-ish entries
  Task 1 resolved): `Today · Progress`, `This Week`, `Today
  Summary`, `Habit Progress`, `Habit`, plus descriptions.
- Lock-screen fallbacks: `No habits due today`, `All done`,
  `Tap to pick a habit`, `Pick a habit`.
- Widget progress strings: `%lld / %lld done`,
  `%lldd` (from Task 2), `%lld%% complete` (shared with Overview —
  avoid duplicate work if Task 6 landed the right phrasing).

**Changes**: catalog only.

**Tests / verification**: FR screenshots of small/medium/large home
widgets + circular/rectangular lock widgets on iPhone 17 Pro.

**Commit message (suggested)**: `feat(l10n/fr): widgets`

---

#### Task 9: FR — Notifications

**Goal**: notification permission nudge, action titles, reminder
bodies in FR.

**Scope**:
- Action titles: `Complete` → `Terminer`, `Skip` → `Passer`.
- Permission nudge copy (covered in Task 7 if bundled; otherwise
  here).
- Reminder notification body templates (if any are in the catalog
  vs. computed Swift-side — confirm during draft).

**Changes**: catalog only. Potentially one source tweak if a
reminder body is built via Swift concat rather than via catalog
format.

**Tests / verification**: trigger a test notification on simulator
under fr_FR, screenshot the action sheet.

**Commit message (suggested)**: `feat(l10n/fr): notifications`

---

#### Task 10: FR — System, errors, miscellany

**Goal**: sweep everything not covered by Tasks 3-9.

**Scope**:
- Error sheets: `Import failed`, `Export failed`,
  `Couldn't read file`, `Not a Kadō backup`, `Newer Kadō version`,
  `Import complete`.
- Confirmation dialogs not yet covered (e.g. `Archive this habit?`
  if it wasn't in Today chunk).
- Glue / separators: `·`, `%@, %@`, `%@. %@` — usually kept as-is
  but commented.
- Anything else the grep surfaces that wasn't translated.

**Changes**: catalog only.

**Tests / verification**: trigger import of a deliberately-malformed
file; screenshot each error sheet.

**Commit message (suggested)**: `feat(l10n/fr): system & error strings`

---

### Phase 3 — Verification

#### Task 11: Regression test — every EN key has an FR translation

**Goal**: prevent silent drift when new EN strings land post-FR.

**Changes**:
- `KadoTests/` — new test `LocalizationCoverageTests.swift`:

  ```swift
  @Test("Every EN catalog key has a non-empty FR translation")
  func frenchCoverage() throws {
      let url = Bundle.main.url(forResource: "Localizable",
                                withExtension: "xcstrings")
      let data = try Data(contentsOf: #require(url))
      let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
      let strings = json?["strings"] as? [String: [String: Any]] ?? [:]
      for (key, entry) in strings where !key.isEmpty {
          guard let locs = entry["localizations"] as? [String: Any],
                let fr = locs["fr"] as? [String: Any] else {
              Issue.record("Missing FR localization for key: \(key)")
              continue
          }
          // Accept either a direct stringUnit or a variations/plural wrapper.
          #expect(hasNonEmptyFR(fr), "Empty FR value for key: \(key)")
      }
  }
  ```

  `hasNonEmptyFR` recurses into `variations.plural.{one,other}` when
  present.

**Tests / verification**: `test_sim`, all previous passing plus the
new one.

**Commit message (suggested)**: `test(l10n): assert every EN key has FR coverage`

---

#### Task 12: FR-locale build + screenshot sweep

**Goal**: visually verify FR on every primary surface.

**Changes**: none (docs only if needed).

**Verification**:
- `build_sim` on iPhone 17 Pro + iPad Air.
- `launch_app_sim` with scheme args `-AppleLanguages (fr)
  -AppleLocale fr_FR`.
- `screenshot` of: Today (empty + with habits), Habit Detail (all
  three types + score popover), New Habit (all 3 frequency types),
  Overview, Settings (root + each sub-sheet), Import/Export flow,
  lock-screen widget, home-screen widgets.
- Note truncation or alignment regressions; fix by shortening the
  FR string or tightening the layout.

**Commit message (suggested)** (if tweaks needed):
`feat(l10n/fr): tighten copy for truncation edge cases`

---

#### Task 13: Pseudo-locale IDE smoke test

**Goal**: catch any remaining un-localized literals (EN text that
renders unaccented under accented-pseudo).

**Author-driven** (IDE-only, per v0.1 compound note):
- In Xcode: **Product → Scheme → Edit Scheme → Run → Options → App
  Language: Double-Length Pseudolanguage** (or Accented).
- Run Kado on iPhone 17 Pro simulator.
- Manually tap through every surface. Any Latin letters that
  appear un-accented or un-doubled are unlocalized — report back.

**Claude will**: take the author's findings (if any) and fold
fixes into a follow-up commit.

**Verification**: clean sweep or documented exceptions.

**Commit message (suggested)** (only if fixes needed):
`fix(l10n): wrap remaining literals surfaced by pseudo-locale sweep`

---

#### Task 14: ROADMAP + CLAUDE updates, compound

**Goal**: record the bring-forward and lock in conventions.

**Changes**:
- `docs/ROADMAP.md` — move "Complete native FR (not
  machine-translated)" from v1.0 Localization section to v0.2 (or
  wherever this PR lands). Leave "FR App Store screenshots" and
  Privacy Label pass at v1.0.
- `CLAUDE.md` → Localization — add a line recording the **tu**
  convention and **série** for streak. These are the sort of
  decisions future-Claude will guess wrong without a memo.
- `docs/plans/2026-04/french-translations/compound.md` — the
  standard wrap-up.

**Verification**: docs only, render sanely in GitHub.

**Commit message (suggested)**: `docs(french-translations): roadmap & compound`

---

### Final: mark PR ready

Switch draft PR [kado#20](https://github.com/scastiel/kado/pull/20)
to ready-for-review. Author merges.

## Risks and mitigation

- **FR truncation** in metric cards, widget titles, tab bar: catch
  in Task 12 (screenshot sweep). Mitigation: shorten the string or
  tighten the layout in the same commit that surfaces it. Budget
  ~2-3 micro-fixes.
- **Plural variants for import counts** (`%lld new`, `%lld updated`)
  get gender-dependent in FR: handled via `variations.plural.{one,other}`
  per key in Task 7; if grammatically intractable, rephrase to avoid
  agreement ("1 entrée ajoutée" → "1 ajoutée" reads awkwardly; fall
  back to neutral "1 ajout" if agreement forces ugliness).
- **Interpolated-localized drift**
  (`String(localized: "Counter · target \(Int(target))")`): caught
  in Task 1's audit. If Xcode's IDE has already auto-extracted these
  in a prior build and the catalog key is present, no source change
  needed; otherwise minor refactor to split format and argument.
- **Catalog JSON diff noise** on merges: the file reorders keys
  occasionally. Rebase-onto-main before ready-for-review; don't
  worry otherwise. Recorded as a v0.1 lesson.
- **Regression test flake** from `Bundle.main` resolution in
  headless test runs: if the test can't find the catalog in the
  test bundle, fall back to a build-phase copy or load from the
  main bundle via `Bundle(for: …)`.

## Open questions — resolved

- [x] **Second regression test pinning FR strings to views?** —
  Deferred. The catalog-level `LocalizationCoverageTests` caught
  every gap (~10 missed keys) without visual assertions.
  Reassess if Task 12's screenshot sweep surfaces real FR drift;
  none observed.
- [x] **FR plurals on `%lld / best %lld`?** — No. Kept
  `%1$lld / meilleure %2$lld` as non-plural; "meilleure 1"
  reads fine idiomatically.
- [x] **Second human-speaker review pass?** — Author is the
  native French speaker and final arbiter. Self-review
  through the chunk-by-chunk draft loop was sufficient.

## Out of scope

- **FR App Store screenshots, description, Privacy Label**: stays
  at v1.0.
- **`String(format: "%02d:%02d", …)` → `DateComponentsFormatter`
  migration**: flagged in the v0.1 compound, still deferred. FR
  doesn't force this.
- **RTL support**: no RTL language in plan.
- **Second target language (ES, DE, etc.)**: out. FR is the
  deliberate first and — per ROADMAP — only v1.0 target.
- **Gender-neutral rewrites beyond what natural FR already allows**:
  out. The style conventions favor readability over ideological
  neutrality; revisit as a separate pass if user preference shifts.
