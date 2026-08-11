# Compound — Day starts at (custom day-rollover hour)

**Date**: 2026-08-10
**Status**: complete
**Research**: [research.md](./research.md)
**Plan**: [plan.md](./plan.md)
**Branch / PR**: `feature/day-start-hour` — [#60](https://github.com/scastiel/kado/pull/60), closes [#58](https://github.com/scastiel/kado/issues/58)

## Summary

Shipped a "Day starts at" hour (midnight…6 AM, default midnight) so
late-night logging keeps the one-tap Today flow. The plan held: one
injected `DayBoundary`, normalisation on write, calculators untouched,
no schema change.

The headline lesson isn't about the design — it's about **verification
shape**. Every real bug in this feature was found by a *different* kind
of check than the one that was supposed to find it. The unit tests were
green through two rounds of bugs that a screenshot and a review caught.

## Decisions made

- **Normalise on write, never on read.** A completion's day is fixed at
  log time, so changing the setting can't re-date history. Makes the
  issue's hard requirement true by construction rather than by care.
- **No schema change.** The hour lives in the App Group `UserDefaults`,
  mirroring `DevModeDefaults`. Avoids a `KadoSchemaV5` and the manual
  CloudKit Production deploy that cost two App Store reviews (#52).
- **`DayBoundary` is a plain struct, not a protocol.** Nothing to mock —
  a different `startHour` *is* the test double. Follows the
  `CompletionToggler` precedent.
- **Reminders stay on wall-clock time.** 9 PM means 9 PM; only the tick
  the banner applies lands on the logical day. Pinned by a regression
  test so a future "make it all consistent" pass has to argue with a red
  bar rather than silently shifting people's alarms.
- **`createdAt` / `archivedAt` stamp the logical day**, so a habit made
  at 2am is due that same night and `everyNDays` anchors where the user
  expects.
- **Clamping is split**: `DayBoundary` accepts `0...23` (any hour is
  mathematically valid), `DayStartDefaults` owns the `0...6` the picker
  offers. Widening the product range is now a one-line change.
- **The picker and the Today caption share one label formatter.** They
  render the same value in two places; letting them diverge would be
  worse than showing nothing.

## Surprises and how we handled them

### The sweep was smaller than planned, and the reason is the design

- **What happened**: Task 4 was budgeted as a wide `DayBoundary` sweep.
  Most sites needed only `.now` → `today`.
- **What we did**: Kept plain `calendar.startOfDay` for stored dates.
- **Lesson**: the rule that fell out is worth stating plainly —
  **`dayBoundary` answers "what day is it now"; `calendar` buckets an
  already-stored date.** Applying the boundary to a stored date *is* the
  read-normalisation design we rejected, so the small blast radius was a
  signal the design was right, not that the plan was wrong.

### A screenshot caught two bugs that were green in CI

- **What happened**: `setLocalizedDateFormatFromTemplate("EEEE")`
  silently negotiated down to the abbreviated weekday ("Still Sun"), and
  the rollover time was formatted in the *device's* time zone rather
  than the boundary's — a UTC 04:00 boundary displayed as "00:00".
- **What we did**: Switched to `Weekday.localizedFull` (the convention
  already in `CLAUDE.md`), and derived the label from the picked hour in
  the boundary's calendar instead of re-rendering an instant.
- **Lesson**: `CLAUDE.md`'s "only a literal pixel check catches design
  bugs" is stronger than it reads. Both bugs were in *string formatting*
  — the category that feels safest to skip a visual check on.

### The DST coverage was the wrong shape, not just thin

- **What happened**: Review found `startOfDay` returning a non-midnight
  instant in zones whose DST transition happens **at** 00:00
  (America/Havana 2026-03-08). There the day's first instant is 01:00,
  and `date(byAdding: .day, value: -1, to: midnight)` preserves it.
  `\.today` stopped being a calendar midnight.
- **What we did**: Re-anchored with `startOfDay`, and replaced the
  example-based tests with two property sweeps over six zones.
- **Lesson**: `Europe/Paris` — the zone `CLAUDE.md` names — **cannot**
  catch this class, because its transitions are at 02:00/03:00 so
  midnight always exists. Example-based DST tests only cover the shapes
  you already thought of. The fix is to assert the *invariant*
  ("`startOfDay` always returns a real midnight") across a zone set
  chosen for its shapes.

### A test that couldn't fail

- **What happened**: the anti-re-bucketing test's final loop discarded
  the boundary it constructed and asserted a loop-invariant constant, so
  the feature's headline guarantee had no real coverage.
- **What we did**: rewrote it to read the stored date back through each
  candidate boundary.
- **Lesson**: it was written knowingly ("somewhat tautological") and
  shipped anyway. **A loop whose assertion doesn't mention its loop
  variable is the tell.** Noticing the smell and proceeding is the
  failure mode, not missing it.

### Hand-rolling what a helper already did

- **What happened**: the rollover tick called `rebuildAndWrite` +
  `RemindersSync` directly, re-implementing two thirds of
  `WidgetReloader.reloadAll` and dropping the third
  (`reloadAllTimelines()`). It also captured a `ModelContainer` that
  goes stale on a dev-mode swap.
- **What we did**: Called `WidgetReloader.reloadAll` and read
  `ActiveContainer.shared`, the pattern `CLAUDE.md` already mandates.
- **Lesson**: writing the postamble by hand at a *new* call site is how
  a centralised postamble decays. Reach for the helper.

### The caption only handled one edge

- **What happened**: the rollover tick fired when the window *closed*.
  Nothing fired at wall-clock midnight, when it *opens* — an instant at
  which, by design, no view input changes and SwiftUI has no reason to
  re-render.
- **What we did**: Task sleeps until `min(rollover, next midnight)`,
  keyed on `clockMark` so it reschedules after either edge.
- **Lesson**: a feature that deliberately decouples the logical day from
  the wall clock has **two** edges. Handling only the one you named the
  feature after is an easy miss.

## What worked well

- **Writing the tests first for `DayBoundary`** paid for itself: the
  spec was the artifact, and the DST fix later slotted in without
  touching a single assertion's intent.
- **The plan's own post-sweep grep mitigation earned its place** —
  re-grepping `startOfDay` / `inSameDayAs` / `isDateInToday` after the
  main tasks found three genuine misses (`DayColumnHeader`,
  `WeeklyGridLargeWidget`, `DevModeSeed`) that no test covered.
- **Verifying the review's biggest claim before acting on it.** A
  throwaway probe test confirmed the Havana bug in one cycle and made
  the rest of the triage trustworthy.
- **Deriving `\.today` rather than storing it.** Changing the hour
  re-resolves the current day for free, with no invalidation path.

## For the next person

- The two seams are the *reference date* passed to calculators and the
  *date stamped* on a new completion. If you add a surface, those are
  the only two places to think about.
- **Never apply `DayBoundary` to a stored `completion.date`.** That's
  read-normalisation, and it re-dates history the moment the setting
  changes. Bucket stored dates with the plain calendar.
- Writes are **pinned to the displayed day**
  (`loggingInstant(for:on:)`), not recomputed from `.now`, so a tap does
  what the user saw even if it executes across the boundary.
- Widgets never ask what day it is — they render a snapshot the app
  builds. The weekly grid's "today" comes from `matrixDays.last`.
- The setting is **device-local**. Two devices disagreeing causes no
  corruption: a completion's day is fixed by whichever device wrote it.
- `DayStartDefaults.boundary()` is the non-SwiftUI accessor (intents,
  notification handler, snapshot builder). Views should use
  `@Environment(\.dayBoundary)` — it re-renders on change; the defaults
  read does not.

## Generalizable lessons

Graduated 2026-08-10; the rest were considered and deliberately left
in this doc.

- **[→ CLAUDE.md — done]** Pin DST tests to a zone set chosen for
  *shapes*, not just to `Europe/Paris`. A midnight-transition zone
  (`America/Havana`) is a necessary second fixture — Paris structurally
  cannot catch midnight-boundary bugs. Prefer asserting invariants
  across a sweep over asserting examples.
- **[considered, not graduated]** A test whose assertion doesn't
  reference its loop variable is vacuous. Sits alongside the existing
  "don't hand-compute canonical serialized strings" rule — both are ways
  a green test can mean nothing. Left here rather than in `CLAUDE.md`:
  arguably general programming hygiene rather than a Kadō convention.
- **[considered, not graduated]** After a cross-cutting sweep, re-grep
  the patterns you replaced and justify every remaining hit. Found three
  real bugs here. Left here as a technique, not a rule.
- **[considered, not graduated]** `.xcstrings` is source: edit it
  without re-sorting or re-serializing. Xcode maintains its own key
  order and `" : "` separators; a naive `json.dump` turns a six-key
  addition into a 5,000-line diff. Only bites tooling that rewrites the
  catalog programmatically.
- **[→ ROADMAP.md — done]** Rollover-aware widget refresh
  (`.after(nextRollover)` instead of hourly). Fixes a staleness bug that
  **already exists at midnight**, independent of this feature.
- **[→ ROADMAP.md — done]** iCloud-sync the day-start hour via
  `NSUbiquitousKeyValueStore` so iPhone and iPad don't need it set
  twice.
- **[local]** `DayBoundary` clamps `0...23` while `DayStartDefaults`
  clamps `0...6`; widen the latter to widen the product.

## Metrics

- Tasks completed: 10 of 10
- Tests: 362 → 416 (+54), 5 new test files
- Commits: 14
- Files touched: 35

## References

- [Issue #58](https://github.com/scastiel/kado/issues/58) — the request,
  and the three alternatives weighed in `research.md`
- `docs/plans/2026-04/habit-backdate/` — closest prior art; same
  "one derived day-semantics change, many call sites" shape
- `CLAUDE.md` § Dates and calendars — the injected-`Calendar` rule this
  feature leans on entirely
