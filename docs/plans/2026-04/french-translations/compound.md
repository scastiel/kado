---
# Compound — French translations

**Date**: 2026-04-19
**Status**: complete
**Research**: [research.md](./research.md)
**Plan**: [plan.md](./plan.md)
**Branch / PR**: [feature/french-translations](https://github.com/scastiel/kado/tree/feature/french-translations) → [kado#20](https://github.com/scastiel/kado/pull/20)

## Summary

Delivered native French across the whole app by hand-editing
`Localizable.xcstrings`. ~160 EN keys translated in 8 feature
chunks, plus a regression test that walks the catalog and asserts
100 % FR coverage. The headline lesson: **Xcode IDE vs MCP work
asymmetrically on the catalog** — the IDE re-adds `extractionState`
flags and re-inserts keys between sessions, so Edit-based catalog
work has to treat the file as something the IDE co-owns, not as
pure source text.

## Decisions made

- **`tu` (not `vous`)** throughout the UI. Matches Streaks / Loop
  FR and the HIG personal-app default. A self-reflective habit
  tracker reads warmer in second-person singular.
- **`série` for "streak"** over `enchaînement` or `suite`. Short,
  widely understood, matches other FR habit apps. Feminine form
  drives `meilleure série` agreement in the `%lld / best %lld`
  metric card.
- **Brand & technical loanwords preserved**: `Kadō` (with the
  macron), `score`, `widget`, `emoji`. French speakers already
  read these in English elsewhere in iOS; inventing French
  equivalents would create distance, not accessibility.
- **Drop `%lld` in FR `one` plural when idiomatic** — e.g.
  `Every %lld days` → `one: "Tous les jours"` (no number), not
  `"Tous les 1 jour"` (grammatically awkward). ICU plural syntax
  allows this; each variant's value is a template, not a
  constraint on which args must appear.
- **Feminine-plural agreement where the antecedent is explicit**:
  `Habits: %lld (%lld new, %lld updated)` →
  `Habitudes : %1$lld (%2$lld nouvelles, %3$lld modifiées)`.
  Masculine-plural default when subject is generic: `%lld (%lld
  new, %lld updated)` → `%1$lld (%2$lld nouveaux, %3$lld modifiés)`.
- **`Programmé %@` for "Fires on %@"** with the past-participle
  form agreeing with implicit masculine "rappel." First attempt
  dropped the accent (`Programme %@`, noun form) based on a user
  typo during review; reverted after clarification.
- **`Mode de mesure` for "How is it measured?"** — nominal over
  interrogative. Cleaner section-header tone; French prefers
  noun-style labels in forms.
- **Lowercase VO states match EN convention**: `done` → `fait`,
  `not done` → `non fait`, `missed` → `manqué`, `completed` →
  `fait`. Reads naturally inside an interpolated sentence
  (`"Méditer, fait"`).
- **Regression test lives in main app tests**, not a separate
  scheme. Cheap to run, catches missed FR the moment an EN key
  lands. Falls back to reading the source catalog when the test
  bundle doesn't copy the resource.
- **Widget streak-suffix localized**: `Text("\(row.streak)d")` now
  maps to a `%lldd` catalog key → FR value `%lldj`. Percent sign
  left untranslated (universal).

## Surprises and how we handled them

### Xcode IDE re-injects `extractionState: "stale"` between sessions

- **What happened**: Task 1 cleanly removed all 22 stale flags
  on widget / AppIntent entries (they're still referenced, just
  not traceable from the main-app target). By Task 8, Xcode IDE
  had re-added them during a session. My prepared `old_string`
  patterns failed because they didn't include the re-inserted
  `"extractionState" : "stale",` line.
- **What we did**: redo the failed edits with the stale flag
  included. Accepted that the flag is cosmetic — it doesn't
  affect runtime. Stopped treating it as a cleanup target.
- **Lesson**: `.xcstrings` is co-owned by the Xcode IDE and the
  source tree. Before each pass of catalog Edits, assume the
  last IDE open may have re-shaped the file. Grep-verify exact
  block contents for any key before asserting an `old_string`.

### Some keys visible in the UI weren't in the catalog at all

- **What happened**: "Create your first habit" (Today empty state
  button), "Habit" (rectangular lock widget display name), and a
  couple of dev-mode strings ("Your habits will be replaced by
  a demo dataset…", "Your real habits are safe in iCloud…") had
  never been extracted. The first two because Xcode IDE hadn't
  synced them from source; the last two because they're
  `String(localized:)` calls whose format-shells hadn't been
  picked up.
- **What we did**: hand-added each in alphabetical order. The
  regression test caught the dev-mode ones — it's how we
  discovered the gap.
- **Lesson**: the plan's audit (done via Explore agent + grep)
  over-estimated coverage. A regression test at the end is
  much cheaper than trying to hand-verify every call site up
  front. Land the test early in the verification phase to
  surface gaps, not late as a rubber stamp.

### The FR draft-review loop caught stylistic choices, not translation errors

- **What happened**: after Task 3 (New Habit form) the author
  pushed back on three choices: `Every %lld days` n=1 form,
  `How is it measured?` phrasing, and `Fires on %@` form. None
  were "wrong FR" — they were stylistic calls the research stage
  hadn't locked. The review-loop surfaced preferences (idiomatic
  "Tous les jours" over "Tous les 1 jour"; nominal "Mode de
  mesure" over interrogative "Comment la mesurer ?").
- **What we did**: applied the revisions, then treated them as
  per-chunk conventions going forward (ICU plural idiomatic
  dropping of %lld; nominal labels for picker / form headers).
- **Lesson**: for future translation work, front-load a short
  "style conventions" checkpoint *with concrete examples* after
  the first chunk, not after the research. Research-level
  conventions read as abstract; concrete examples force
  decisions.

### The regression test exposed seven FR gaps I hadn't seen

- **What happened**: after landing all 8 chunks (Tasks 3-10), the
  test failed on: `%lld`, `%lld%%`, `+5m`, `•`, `%lldd`,
  `Archived`, `Couldn't read file`, plus two dev-mode strings
  and one iCloud description. Total: ~10 keys missed across
  ~160 translated.
- **What we did**: each failure pointed at the exact key; fixed
  one at a time, then wrote a Python one-liner to get the full
  gap list at once and finished in a single batch.
- **Lesson**: iterative test-fail-fix was slower than "list all
  gaps then fix in one batch." When a test has a bounded failure
  surface, ask it for the full list up front.

### Post-merge review: widget extension bundle has no fr.lproj

- **What happened**: a post-build inspection of
  `Kado.app/PlugIns/KadoWidgetsExtension.appex/` found no
  `fr.lproj` and the Info.plist had no `CFBundleLocalizations`.
  The catalog lives in the main app target's synchronized folder
  (`Kado/Resources/Localizable.xcstrings`) and isn't included in
  the widget extension's target membership. Widget kind names,
  descriptions, and lock-screen fallbacks would render EN
  regardless of system language — even though the main catalog
  contains all the FR translations.
- **What we did**: added a second catalog at
  `KadoWidgets/Resources/Localizable.xcstrings` with the
  ~26 widget-used keys (kind names, descriptions, lock-screen
  fallbacks, format shells, VO states) and their FR values. The
  synchronized-folder mechanism automatically compiles the
  catalog into `fr.lproj/Localizable.strings` inside the widget
  extension bundle. Verified post-build:
  `KadoWidgetsExtension.appex/fr.lproj/Localizable.strings`
  contains all 26 translated entries.
- **Lesson**: when localizing an app with extensions, **verify
  each extension's compiled `.appex` contains the language's
  `.lproj` before claiming the feature complete**. The
  `LocalizationCoverageTests` guard the catalog source — but the
  catalog is only source; target-membership determines whether
  the compiled bundle ships it. For synchronized-folder projects,
  the pattern is one catalog per target folder; cross-target
  sharing requires either pbxproj exceptions (Xcode-IDE-only) or
  Bundle.module lookups via a package. Duplicating widget keys
  was the cheapest fix that stays MCP-automatable.
- **Test update**: `LocalizationCoverageTests.catalogPaths` now
  walks both catalogs. Future new targets with user-facing
  strings should append their catalog path to this list.

### Code review polish after compound

- **What happened**: a `/review` pass after compound flagged four
  minor polish items on `LocalizationCoverageTests`: unused
  `@testable` import, unneeded `@MainActor`, permissive plural
  check (any form passing), and a zombie catalog key
  (`Habits you create will show up here with their history.`).
- **What we did**: applied three of the four in a follow-up
  commit (`test(l10n): tighten plural coverage and trim imports`).
  The zombie key had already been removed by an Xcode IDE pass
  before the fix could land — harmless serendipity.
- **Lesson**: compound is worth running *after* review, not
  before. The review caught testability issues that a compound
  written pre-review would have missed. Also: tightening the
  plural check from "any non-empty form" to "every declared form
  non-empty" turned a latent false-negative into a real check
  with no code cost.

## What worked well

- **Draft-review loop at chunk boundaries**, per plan. The author
  caught stylistic calls I'd gotten wrong (tu-form imperatives,
  plural idioms) without me having to guess conventions.
  Per-chunk commits made revision granular.
- **Three phases in one PR stream**, single draft PR. Kept all
  work in one place for review, avoided multi-PR overhead for
  what's essentially one cross-cutting change.
- **JSON validation + build + test after each chunk**. Catch
  broken JSON (missing comma, duplicate key) before committing.
  Python's `json.load` is one shell command away and gives
  line-accurate errors; built-in Xcode parsing doesn't.
- **Regression test as the ground-truth coverage check**. Cheaper
  than hand-auditing, catches drift automatically when future
  PRs add EN keys. Already guards the catalog going forward.
- **`Calendar.*StandaloneWeekdaySymbols` and date formatters
  are locale-aware for free** — zero FR work on weekday /
  month / relative-date rendering. The v0.1 translations-catalog
  work prepaid this dividend.

## For the next person

- **Adding a new user-facing string**: the `LocalizationCoverageTests`
  test will fail if you add an EN key without FR. The failure
  message names the key. Don't skip the test.
- **Plural variants in FR**: ICU's `one` rule covers {0, 1}; don't
  default to `%lld X` in `one` if the idiom would drop the
  number. Examples in this feature: `Tous les jours` /
  `tous les jours` for the n=1 `everyNDays` branch.
- **Feminine agreement**: `habitude` (f.), `complétion` (f.),
  `série` (f.), `journée` (f.), `sauvegarde` (f.). Adjective,
  past-participle, and ordinal agreement follows from the
  antecedent, not from "FR defaults." When the antecedent is
  generic or the phrase stands alone, default to masculine.
- **Technical loanwords kept in English**: `score`, `widget`,
  `emoji`, `Kadō`. Don't "translate" them in future PRs.
- **Don't over-localize dev-mode or debug strings**: they're in
  the catalog because the compiler extracts them, but user never
  sees them. Translate loosely; review isn't warranted.
- **`iCloud`, `%`, numeric digits, `%1$@` positional args are
  universal** — don't "translate" them.
- **Xcode IDE re-edits `.xcstrings` when open**: expect the file
  to have extra `extractionState: "stale"` flags, re-inserted
  orphan keys, reordered entries between sessions. None of it
  affects runtime. The regression test is the only thing that
  has to stay green.

## Generalizable lessons

- **[→ CLAUDE.md]** Added: "FR conventions locked: `tu` (not
  `vous`), `série` for streak, `habitude` (feminine) drives
  agreement, technical loanwords kept. Drop %lld in FR `one`
  plural when idiomatic." Also: "A regression test
  (`LocalizationCoverageTests`) walks the shipped catalog and
  fails if any user-facing key lacks FR. Run before merging
  any PR that adds EN keys."
- **[→ CLAUDE.md]** Already documented: catalog as source code
  (hand-author, Xcode merges on open). Reconfirmed here — the
  IDE round-tripping pattern is durable enough to document once
  more concretely in the compound.
- **[local]** `Programmé %@` as "Fires on %@" works because the
  %@ value is an adverbial phrase (`chaque jour`, `lun · mer ·
  ven`). If we later change the `frequencyFooter` to return a
  noun phrase, the FR needs a re-check — past-participle
  agreement would need revision.
- **[local]** The `%lld%% complete` / `%lld%% accompli` pair
  uses an imported space (`%lld %% accompli`) following FR
  typography convention (space before `%`). EN doesn't use the
  space. Keep this convention for any other FR percentage
  formats.
- **[→ ROADMAP.md]** FR App Store screenshots + Privacy Label
  translation remain v1.0-scoped. This PR only ships in-app FR.
  Pseudo-locale IDE sweep also deferred — MCP can't drive the
  scheme-level option; author runs it before v1.0 App Store
  submission.
- **[→ CLAUDE.md candidate]** For multi-target iOS apps using
  synchronized folders, **each target with user-facing strings
  needs its own `Localizable.xcstrings`**. The widget extension
  (and any future extension — Live Activities, watchOS, etc.)
  keeps overlapping keys in sync with the main app's catalog
  through copy-paste. `LocalizationCoverageTests` walks every
  catalog listed in `catalogPaths`; append when a new target
  ships.

## Metrics

- Tasks completed: 14 of 14 plan tasks + 2 post-review fixes
  (widget catalog, test polish)
- Tests added: 1 (`LocalizationCoverageTests`), extended
  post-review to walk both catalogs
- Commits: ~18 (1 research, 1 plan, 12 feat/fix/chore/test/docs
  across phases 2-3, 2 docs+polish commits after compound, 2
  widget-catalog commits)
- Catalog entries translated: ~160 in main catalog, ~26 in
  widget catalog (overlap with main on the shared keys)
- Source files touched: 3 (`OverviewView.swift` — empty-state
  dedupe; `ROADMAP.md`; `CLAUDE.md`). Widget Swift sources
  unchanged; the existing `Text("…")` call sites already sit
  on the LocalizedStringKey path.
- Build/test status: 243/243 passing, no new warnings.

## References

- [Xcode 16 String Catalogs documentation](https://developer.apple.com/documentation/xcode/localizing-and-varying-text-with-a-string-catalog)
- [ICU Plural Rules — FR](https://cldr.unicode.org/index/cldr-spec/plural-rules) —
  FR `one` covers {0, 1}, `other` covers {2, 3, …}.
- [Apple HIG — Writing (FR tone)](https://developer.apple.com/design/human-interface-guidelines/writing)
- Previous: `docs/plans/2026-04/translations-catalog/compound.md`
  — v0.1 EN pass, where weekday helpers and catalog-as-source
  lessons originated.
