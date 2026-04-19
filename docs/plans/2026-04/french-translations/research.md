---
# Research — French translations

**Date**: 2026-04-19
**Status**: ready for plan
**Related**: `docs/ROADMAP.md` (v1.0 → "Complete native FR"),
`docs/plans/2026-04/translations-catalog/` (v0.1 EN catalog pass),
`CLAUDE.md` → Localization.

## Problem

`Kado/Resources/Localizable.xcstrings` currently ships **EN only**.
CLAUDE.md mandates native FR (no machine translation); ROADMAP placed
the FR pass at v1.0. Since the v0.1 catalog work, seven feature PRs
landed (widgets, notifications, import/export, multi-habit overview,
today-row-actions, paper-sage-reskin + polish, score-info-popover),
growing the catalog from ~60 to **~160 EN keys**. The app's author
is a native French speaker; we're pulling this forward from v1.0
because the EN surface is now stable enough that FR strings won't
churn, and shipping FR unlocks the bilingual user base the author
actually uses Kadō in.

**"Done" from the user's perspective**: switching the device to
French renders every user-facing surface — Today, Detail, New Habit,
Settings, Overview, widgets, notification actions, import/export,
score explanations — in natural, native French. No machine-translated
phrasing, no English leakage, no broken plurals (1 jour vs. 2 jours
handled via the catalog, not Swift-side).

## Current state of the codebase

Catalog audit (2026-04-19, Explore agent walk across `Kado/`,
`KadoWidgets/`, `KadoLiveActivity/`, `Packages/KadoCore/`):

- **Total catalog keys**: ~160 (up from ~60 at v0.1).
- **With translator comments**: 181 out of ~160 distinct key blocks —
  effectively every non-auto-generated entry is annotated. Good
  hand-off shape for a translator.
- **Plural variants already declared**: 3 keys —
  `%lld days per week`, `%lld days ago`, `Every %lld days` (each with
  `one` / `other` in EN).
- **`extractionState: "stale"` entries**: 22. Most are widget
  configuration strings that Xcode-via-MCP can't confirm from source
  (kind display names, description strings) but are in fact still
  referenced. Cleanup is a side quest, not the main translation
  work.
- **Localization call-site health** (post-v0.1 sweep): very good. The
  Explore agent found **0 net-new user-facing literals** across the
  seven v0.2 feature PRs that bypass localization. The v0.1 pass's
  muscle memory held up.

### Genuine gaps found

Four small items, all localizable by adding a catalog key + a
one-line Swift tweak each:

1. `KadoWidgets/.../LockCircularWidget.swift:53` —
   `Text("\(Int(row.progress * 100))")` renders a bare number.
   Either keep as-is (numbers are locale-neutral in ASCII digits)
   or wrap with a format key `"%lld%%"` for the `%` sign.
2. `KadoWidgets/.../LockRectangularWidget.swift:43` —
   `Text("\(row.streak)d")` has a hardcoded `"d"` for "days." Needs
   a catalog format like `"%lldd"` with FR variant (`"j"`) or the
   full word (`"j"` / `"jours"` — decide at plan time).
3. `KadoWidgets/.../LockRectangularWidget.swift:48` —
   `Text("\(row.scorePercent)%")` — `%` is universal, safe to
   leave.
4. `Kado/Views/Overview/OverviewView.swift:74` — empty-state copy
   `"Habits you create will show up here with their history."` is
   a subtle variation of the catalog's
   `"Habits you create will appear here."`. Likely an inadvertent
   duplicate. **Fix**: collapse to one key before translating.

### Call-site patterns to double-check

- `HabitDetailView.swift` has
  `String(localized: "Counter · target \(Int(target))")` and similar.
  `String(localized:)` with **interpolation inside** extracts a
  format-shell key (`"Counter · target %lld"`) on Xcode IDE builds,
  but MCP `xcodebuild` runs don't re-extract at all. Need to verify
  these exact shells exist in the catalog as-is before assuming
  they'll take an FR translation.
- `SyncStatusSection.swift:76` —
  `"\(title(for: status)). \(subtitle(for: status))"` is a raw
  concat of two separately-localized halves with a hardcoded
  `". "` glue. The glue isn't fatal in FR (the punctuation is the
  same) but doesn't round-trip through the catalog. Flag for
  cleanup.
- `OverviewView.swift:272` —
  `"\(habit.name), \(dateString), \(state)"` in an accessibility
  label is another raw concat. FR accessibility users will hear
  the right words in the wrong flow without a format string. Low
  priority; batch with the polish pass.

## Proposed approach

**Three phases, one PR stream, one draft-and-review loop per
phase.** The draft-review loop is the defining rhythm: the user is
the native speaker and final arbiter, so every chunk of FR strings
is draft → review → revise → commit.

### Phase 1 — Catalog prep (mechanical, no FR content)

1. Collapse the `OverviewView` duplicate empty-state key. Single
   source of truth.
2. Add the two missing widget format keys
   (`%lldd` for streak suffix — if we choose to localize the suffix)
   and any others surfaced by a pre-flight `build_sim` + source
   grep.
3. Clean up stale catalog entries (delete or revive): each of the
   22 `extractionState: "stale"` items is either a live string Xcode
   mis-extracted or genuinely unused. Resolve before translating so
   we don't pay for FR on dead keys.
4. Decide whether to declare additional plural variants. EN got
   away with three; FR will realistically want plurals on a handful
   more — list finalized at plan time. Candidates:
   - `"%lld (%lld new, %lld updated)"` (import summary) — FR:
     "1 nouveau" / "2 nouveaux," "1 modifiée" / "2 modifiées"
     (agreement with feminine "habitude" vs. masculine "entrée").
   - `"Habits: %lld (…)\nCompletions: %lld (…)"` — same.
   - `"%lld / best %lld"` — FR: "meilleur" agrees; probably fine
     with `other` form.
   - `"%lld%% complete"` — FR: "complété/complétée" depends on
     antecedent; rephrase to avoid.

### Phase 2 — FR translation pass (content work, draft-review loop)

Draft FR for every catalog entry in **logical chunks** (by feature,
so each review session is coherent):

1. Onboarding-adjacent: New Habit form, validators, picker labels.
2. Today tab: row labels, row actions, accessibility labels, empty
   state.
3. Habit Detail: metric cards, score explanation, history list,
   weekday labels, calendar header.
4. Multi-habit Overview: grid cells, popover, empty state.
5. Settings: Notifications, Sync, Backup/Import/Export,
   About/Theme.
6. Widgets: kind names, descriptions, lock-screen fallbacks.
7. Notifications: action titles, body strings, permission nudges.
8. System-adjacent: error sheets ("Couldn't read file," "Newer Kadō
   version"), confirmation dialogs.

Per chunk: Claude drafts FR strings directly in the `.xcstrings`
JSON (with plural variants where declared), commits, posts a
summary for review, user edits or confirms in a follow-up
commit. Small commits keep review scope manageable.

### Phase 3 — Integration and verification

1. `build_sim` + `test_sim` on iPhone 17 Pro, FR locale simulated
   via scheme argument (`-AppleLanguages (fr) -AppleLocale fr_FR`).
2. `screenshot` of Today, Detail, New Habit, Overview, Settings in
   FR — visual sanity check for truncation (FR runs ~20 % longer
   than EN typically) and alignment.
3. VoiceOver spot-check on one habit row and one settings section
   in FR.
4. Update `docs/ROADMAP.md`: move "Complete native FR" from v1.0
   Localization to v0.2-or-v0.3 (whichever this lands in).
5. Update `CLAUDE.md` Localization section with any conventions
   introduced here (tu/vous choice, formatter handling, etc.).

### Key components

- **`Kado/Resources/Localizable.xcstrings`**: the single file touched
  for the bulk of Phase 2. Hand-edited JSON per the
  `translations-catalog` compound lesson (MCP can't auto-extract;
  hand-authoring is the workflow).
- **Handful of source files**: `OverviewView`, two widget lock-screen
  views, possibly `SyncStatusSection` for the glue-punctuation
  cleanup, `HabitDetailView` for the interpolation-inside-localized
  spot-checks.
- **`docs/ROADMAP.md`**: bring-forward note.
- **`docs/plans/2026-04/french-translations/compound.md`**: wrap-up
  with the tu/vous decision, terminology choices (habitude, score,
  streak → série?), and a note for future translators.

### Data model changes

None.

### UI changes

FR strings everywhere. No structural or layout changes expected,
though truncation in tight spots (metric cards, widget headers) may
force an abbreviation or line-height tweak. Batch any such tweak
inside the same PR as the string that forced it.

### Tests to write

Localization tests are scarce in this codebase by design — the
`translations-catalog` compound explicitly deferred a pseudo-locale
smoke test to "v1.0 pre-FR." That's **now**. Minimal proposed suite:

```swift
@Test("Every catalog key has a non-empty FR translation")
// Walk the .xcstrings JSON at test time (bundle resource or file
// URL), assert each EN key has an `fr` stringUnit with state
// 'translated' and non-empty value. Fails loudly on drift.
```

```swift
@Test("Key French UI strings render without English fallback under fr locale")
// Snapshot-ish: render a handful of representative views
// (TodayView empty state, HabitDetailView score popover,
// SettingsView.NotificationsSection) with
// `.environment(\.locale, Locale(identifier: "fr_FR"))` and assert
// the rendered Text contains the expected FR phrase.
```

The first test is the load-bearing one — cheap to run, catches the
"new EN key added without FR" regression immediately. The second is
higher-value but costlier to maintain; defer unless a build
surfaces real drift.

## Alternatives considered

### Alternative A: Defer FR to v1.0 as the ROADMAP originally planned

- Idea: keep EN-only through v0.3, do the FR pass as part of App
  Store launch prep.
- Why not: user explicitly chose "bring forward now." The EN
  catalog is stable, the author uses Kadō in French daily, and
  doing FR while the features are fresh is cheaper than waiting
  9+ months and relearning each string's context. v1.0 still owns
  "FR App Store screenshots" and the privacy-label pass — those
  remain v1.0 scope.

### Alternative B: Use a translation service (Apple Translate, DeepL, Crowdin)

- Idea: machine-translate the catalog, then do a FR speaker pass
  for corrections.
- Why not: CLAUDE.md explicitly bans this —
  "FR must be native French (no machine translation), with
  attention to gender-neutral phrasing when possible." The
  draft-review loop with a native-speaker author is the
  prescribed workflow.

### Alternative C: Full EN-audit first, then FR in a separate PR stream

- Idea: split into two features — "catalog audit & cleanup" and
  "french translations."
- Why not: the audit finding is thin (4 gaps, 22 stale flags, no
  structural code changes needed). Phase 1 here *is* the audit; it
  costs a couple of commits to fold into the FR PR and spares us a
  PR-overhead round. Revisit the split if Phase 1 balloons.

### Alternative D: Start FR with just the user-visible "hot path"
(Today + Detail) and ship incrementally

- Idea: partial FR, complete over multiple PRs.
- Why not: iOS treats an app as either localized or not — a half-FR
  UI with EN in Settings reads like a bug. The catalog is small
  enough (~160 keys) that a single pass is tractable. User chose
  "Audit + full FR" explicitly.

## Risks and unknowns

- **Truncation in tight UI**: metric cards, widget headers, tab
  titles. FR often runs longer than EN. Budget a short visual pass
  in Phase 3 with screenshots; expect 1-3 string shortenings or
  abbreviations.
- **Interpolated localized strings**
  (`String(localized: "Counter · target \(Int(target))")`): the
  catalog may not hold the right format shell if the v0.1 Xcode IDE
  extraction didn't pick them up. Need to grep the catalog for each
  such call site's format and add missing ones in Phase 1.
- **`extractionState: "stale"` entries**: if we translate a stale
  key and then Xcode IDE later deletes it, the FR string vanishes
  with it. Resolve stale status before translating (either reaffirm
  the key's usage and re-mark `translated`, or delete).
- **Weekday/month labels**: already delegated to
  `Calendar.*StandaloneWeekdaySymbols`, so "correct in FR" is free.
  Verify once with a screenshot; no manual catalog work needed.
- **String formatters outside the catalog** (`String(format: "%02d:%02d", …)`
  in `HabitRowView`): these don't hit the catalog and are FR-safe
  as-is (digits and `:` are locale-neutral). The
  `DateComponentsFormatter` migration remains deferred — the
  `translations-catalog` compound noted it as a pre-v1.0 follow-up.
  No reason to fold it in here.
- **App name "Kadō"**: kept as-is in FR per native-brand
  convention. Same glyphs, same macron on the ō.
- **Terminology drift**: "streak" has two natural FR translations —
  `série` (common, neutral) vs `enchaînement` (stronger but more
  formal). "Score" works identically. "Habit" = `habitude`. Lock
  these in up front so the draft is consistent (see open questions).

## Open questions

- [ ] **Tu vs vous?** Second-person singular (tu) feels warmer and
  matches how a personal-use habit tracker addresses its user
  (Streaks, Loop in FR both use tu). Second-person plural (vous) is
  the historical-default for Apple apps but feels stiff for a
  self-reflective tool. **Recommendation: tu**. Confirm with
  author.
- [ ] **Streak → série or enchaînement?** Leaning `série` (shorter,
  widely understood, matches other FR habit apps). Confirm.
- [ ] **"Score" as-is or translate?** `Score` is universally
  understood in French and already used in FR sports/gaming
  contexts. Keep as-is.
- [ ] **Day abbreviations in score explanation**
  ("If your habit runs Mon/Wed/Fri, other days are skipped."):
  rewrite with neutral phrasing to avoid hand-translating
  abbreviations that `Calendar` already handles elsewhere. Draft:
  "Si ton habitude est programmée sur certains jours, les autres
  sont ignorés."
- [ ] **Pseudo-locale / accented-pseudo smoke test**: the
  `translations-catalog` compound deferred this as "v1.0 pre-FR."
  Do it now in Phase 3, or still skip? Lightweight IDE step — worth
  doing once.
- [ ] **FR App Store assets** (screenshots, Privacy Label wording,
  description): out of scope for this PR, reaffirm as v1.0.

## References

- [Apple Human Interface Guidelines — Writing](https://developer.apple.com/design/human-interface-guidelines/writing)
  (FR tone section: tu is the HIG default for personal apps)
- [Xcode 16 String Catalogs](https://developer.apple.com/documentation/xcode/localizing-and-varying-text-with-a-string-catalog)
- [`Calendar.standaloneWeekdaySymbols`](https://developer.apple.com/documentation/foundation/calendar/2293301-standaloneweekdaysymbols)
- `docs/plans/2026-04/translations-catalog/compound.md` — v0.1
  lessons (catalog-as-source-code, weekday helpers, plural handling)
- CLAUDE.md → Localization section (current conventions)
- `docs/ROADMAP.md` v1.0 → "Complete native FR (not
  machine-translated)"
