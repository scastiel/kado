---
# Research — Today Row Actions

**Date**: 2026-04-18
**Status**: ready for plan (open questions resolved 2026-04-18)
**Related**:
- [today-view research](../today-view/research.md) — the v0.1 row this redesigns
- [detail-quick-log compound](../detail-quick-log/compound.md) — counter/timer affordances we're now mirroring on Today
- [ROADMAP v0.x — Views](../../../ROADMAP.md)

## Problem

The Today tab is the app's daily touchpoint, but its row interaction
model has two bugs *as a UX*:

1. **The primary action is invisible.** Tapping the leading badge
   marks a binary/negative habit done, but nothing in the visual
   tells the user that. Subtle outlined→filled is the only feedback;
   no label, no shape that reads as a button. Users have to be
   *told* the affordance exists.
2. **Counter and timer rows have no Today action.** They render
   `3/8` or `12:34/30:00` and require navigating to Detail to log.
   That breaks the implicit promise of the Today tab — that this is
   where you act on today.

The current behavior also has a split tap target: the leading icon
is a `Button` (toggles), the rest of the row is a `NavigationLink`
(pushes Detail). Half the row does one thing, half does another,
and there's no visual seam to communicate that.

Decisions already locked with the user before research:

- **Row body still navigates to Detail.** Don't fold Detail behind a
  long-press — the calendar grid + history is something users want
  often, and Detail discovery matters.
- **Streak and score appear on the row.** This deliberately reverses
  a v0.1 minimalism call ("Today's row is about today's state
  only"; see [today-view research §Open questions](../today-view/research.md#open-questions)).
  v0.1 prioritized calm; we now have enough surface and Detail
  parity to justify making Today situationally aware.

## Current state of the codebase

What this redesign touches:

- [TodayView](../../../../Kado/Views/Today/TodayView.swift) —
  fetches habits via `@Query`, filters by `frequencyEvaluator.isDue`,
  renders rows in a `List(due) { NavigationLink(value: record) { ... } }`
  shape (lines 58-67). Computes `isCompletedToday` (lines 90-93) and
  `todayValue` (lines 95-100) per row.
- [HabitRowView](../../../../Kado/UIComponents/HabitRowView.swift) —
  the row itself: `HStack` of `leadingIcon` + name + `Spacer` + `trailingState`.
  `leadingIcon` is a `Button` only when `onToggle` is non-nil
  (binary/negative; lines 38-43). Counter/timer trailing state is a
  `Text("3/8")` / `Text("12:34/30:00")` (lines 80-87). Has full
  preview coverage including dark mode and Dynamic Type XXXL.
- [CompletionToggler](../../../../Kado/Services/CompletionToggler.swift) —
  `toggleToday(for:on:in:)` inserts a `value=1` completion or
  deletes today's. Used by binary/negative.
- [CompletionLogger](../../../../Kado/Services/CompletionLogger.swift) —
  `incrementCounter`, `decrementCounter`, `logTimerSession`,
  `delete`. Already covers everything counter/timer need on Today;
  no new service code required.

What we'll lift onto Today (already exists in Detail):

- Score: `\.habitScoreCalculator.currentScore(for:completions:asOf:)`
  ([HabitDetailView lines 191-198](../../../../Kado/Views/HabitDetail/HabitDetailView.swift)).
- Streak: `\.streakCalculator.current(for:completions:asOf:)`
  ([HabitDetailView lines 200-206](../../../../Kado/Views/HabitDetail/HabitDetailView.swift)).
- Counter `−/+` mechanics: [CounterQuickLogView](../../../../Kado/UIComponents/CounterQuickLogView.swift)
  is the visual reference; we'll implement a denser inline variant
  for Today rather than reuse this 80px-tall control.
- Timer log sheet: [TimerLogSheet](../../../../Kado/Views/HabitDetail/TimerLogSheet.swift)
  — present unchanged from Today via the existing `+5m` chip's
  long-press or via the context menu.

What's missing entirely:

- **No "skip today" model state.** `CompletionRecord` is just `date`
  + `value` + `habit` (no `kind` / `status` discriminator). A "skip"
  context-menu action would require either a SchemaV2 migration to
  add a `kind: completed | skipped` enum, or a special-value
  convention (e.g. `value = -1`). This is a real model decision —
  see open question #1.
- **No "completed today" semantics for counter/timer.** `TodayView.isCompletedToday`
  treats *any* completion record as "done" (line 92), so a counter
  at 1/8 is "complete" by that flag. This is fine as long as nothing
  visual depends on the flag — and currently nothing does. The
  redesign needs an explicit *trichotomy* (none / partial /
  target-reached) for the progress ring and dimming.
- **Localization for new strings.** The catalog at
  `Kado/Resources/Localizable.xcstrings` (currently modified, per
  git status — multi-habit-overview work) needs hand-authored
  entries for "Mark done", "Done", "Slipped", "+5m", and the
  context-menu actions. Pattern per CLAUDE.md: `LocalizedStringKey`
  initializers where possible, `String(localized:)` for dynamic
  accessibility labels.

## Proposed approach

One PR: redesign `HabitRowView` end to end, push the `todayValue` /
`isCompletedToday` derivation into a small free struct so tests can
target it without a SwiftUI host, and add the missing localization
entries. No SwiftData schema change in v1 of this redesign; "Skip
today" is deferred unless the user opts in to schema work (open
question #1).

### Key components

- **`HabitRowView` (rewritten)** — three regions:
  - **Leading**: 32-38pt circular badge. For counter/timer, the
    fill becomes a *progress ring* (`Circle().trim(...)`) showing
    `min(value/target, 1)`; the icon stays centered. For
    binary/negative, the badge keeps the current filled-disk-when-
    done treatment.
  - **Center**: two-line stack — habit name (Body) on top,
    `streak · score` chip line (Caption, secondary) underneath.
    Streak shown as `🔥 12` (or "12 day streak" at large Dynamic
    Type), score as `87%`.
  - **Trailing**: type-aware action region.
    - *Binary*: pill `Button("Mark done")` with `.borderedProminent`
      tint; flips to a filled checkmark capsule when `isCompletedToday`.
    - *Negative*: pill `Button("Slipped")` with red tint; flips to a
      filled red capsule when slipped today. (Negative semantics:
      pressing the button records a "slip" — same as today's behavior,
      just labeled.)
    - *Counter*: inline stepper — `Button("−") Text("3/8") Button("+")`,
      tight 28pt circular buttons, `−` disabled at 0. Reuses
      `CompletionLogger.{increment,decrement}Counter`.
    - *Timer*: `Button("+5m")` chip + a `.contextMenu` entry that
      opens `TimerLogSheet`. (Tapping the row body still navigates
      to Detail, where the full sheet is one tap away.)
- **`HabitRowState` (new free struct, `Models/` or alongside the
  view)** — pure data: `kind: .binary | .negative | .counter | .timer`,
  `valueToday: Double?`, `target: Double?`, `progress: Double?`
  (clamped 0…1), `status: .none | .partial | .complete`. Built from
  `(Habit, [Completion], Calendar, Date)`. Tests target this rather
  than the SwiftUI view.
- **`.contextMenu` on every row** with: *Log specific value…*
  (counter/timer only; opens existing sheets), *Open detail*, *Edit*,
  *Archive*. (Skip today omitted — see open question.)
- **`.swipeActions(edge: .trailing)` on completed binary/negative rows**:
  destructive **Undo** that calls `CompletionToggler.toggleToday`.
  Counter/timer don't need swipe-Undo because the `−` button is
  already on the row and is the natural undo affordance.

### Data model changes

None proposed. Schema stays at V1.

If the user wants "Skip today" in this PR (open question #1), the
minimal model change is:

```swift
// New in KadoSchemaV2
nonisolated enum CompletionKind: String, Codable, Sendable {
    case completed
    case skipped
}
// CompletionRecord adds:
private var kindRaw: String = CompletionKind.completed.rawValue
var kind: CompletionKind { CompletionKind(rawValue: kindRaw) ?? .completed }
```

Migration: `MigrationStage.lightweight(...)` — old records have no
`kindRaw`, default to `completed`. Plus the SwiftData enum-storage
workaround per CLAUDE.md (raw-value enums must be stored as raw
strings, not as the enum itself).

### UI changes

- `HabitRowView`: full redesign as above.
- `TodayView`: pass through `currentStreak` and `currentScore` to
  the row, sourced from `\.streakCalculator` and `\.habitScoreCalculator`.
  Keep the row inside `NavigationLink(value:)` — confirmed to compose
  correctly with row-level `Button`s on iOS 18+ (the buttons absorb
  their own taps, the link absorbs the rest).
- Optional: a small "trending" arrow next to the score
  (↑/↓/→ vs the previous 7-day average). Useful but adds a third
  dependency (need a `priorScore` derivation). Defer to open
  question #2.

### Tests to write

`HabitRowStateTests` (Swift Testing, no SwiftUI):

```swift
@Test("Binary habit with no completion today is .none / not complete")
@Test("Binary habit with a completion today is .complete")
@Test("Counter habit with value below target is .partial with progress = value/target")
@Test("Counter habit with value at or above target is .complete with progress = 1")
@Test("Timer habit with no completion today is .none with progress = 0")
@Test("Timer habit with seconds equal to target is .complete with progress = 1")
@Test("Negative habit with a slip recorded today is .complete (= slipped)")
@Test("Progress is clamped to 1 even if today's value exceeds target")
```

Plus a regression test for the existing toggle path (already covered
by `CompletionTogglerTests`; just confirm Today's wiring still calls
through it).

UI: previews per type with `.none`, `.partial`, `.complete` states,
plus dark mode and Dynamic Type XXXL. Snapshot the row at each
state if `screenshot` is available, otherwise rely on previews +
manual sim check.

## Alternatives considered

### A. Single big "Done" CTA per row, drill-in via long-press

- Idea: row body = primary action, Detail behind a chevron or
  long-press.
- Why not: rejected upstream by the user. Detail discovery matters.

### B. Inline expand on tap (row reveals quick-log controls)

- Idea: tap a row → it expands in place to show stepper / timer
  controls; tap again to collapse.
- Why not: doesn't help binary/negative (already one-tap), adds
  animation surface area, and conflicts with the locked decision
  that row tap → Detail. Would require a separate "expand" gesture.

### C. Keep the leading-icon tap, just add a label or adjust
visuals to make it look more like a button

- Idea: smallest possible change — make the badge look more
  buttony, maybe a tiny "tap" hint on first launch.
- Why not: doesn't fix counter/timer parity (the real problem),
  and parity is what locked the user's "yes to streak + score" call —
  Today is being upgraded as a surface, not just a row.

### D. Add a separate "log" tab / sheet entirely

- Idea: a global "+ Log" floating button that opens a habit picker
  → quick-log flow.
- Why not: adds a navigation layer for what should be one tap from
  Today. Solves nothing; pushes the affordance further away.

## Risks and unknowns

- **Buttons inside `NavigationLink` rows in a `List` (iOS 18+)**:
  this works on modern iOS, but `.buttonStyle(.plain)` /
  `.borderless` / `.borderedProminent` interact differently with
  the link's tap region. Need to verify with a build that:
  (a) tapping the trailing pill fires its action without pushing
  Detail, (b) tapping the row body still pushes Detail, (c) the
  whole row isn't shaded on tap when only the pill should
  highlight. First Xcode 26 build will confirm; if it misbehaves,
  the fallback is to wrap the whole row in `.background(NavigationLink…)`
  / `.tag` or to hoist navigation to a manual `selection` binding.
- **Dynamic Type XXXL layout**: name + `streak · score` line +
  trailing pill is dense. At XXXL the trailing pill may need to
  drop below the name (`ViewThatFits` with a vertical fallback).
  Counter stepper at XXXL is a known-tight layout — the existing
  `CounterQuickLogView` solves it with 44pt buttons in a column;
  Today's denser variant needs a `ViewThatFits` fallback or a
  policy decision (pill becomes "Log" → opens existing sheet at
  large sizes).
- **Negative-habit semantics labeling**: today's code already calls
  these "Slipped" colloquially in this conversation, but the model
  comment for negative is just "avoid". Picking "Slipped" is a
  product call — alternatives are "Yes (slipped)", "Failed"
  (judgmental, avoid), "Slip" (noun, awkward). Going with
  "Slipped" unless overruled.
- **Localization burden**: ~10 new strings + their FR translations.
  Per CLAUDE.md, the catalog is source code under XcodeBuildMCP
  (Xcode IDE doesn't run sync); we hand-author entries.
- **Counter overshoot**: the existing logger lets `value` exceed
  `target`. The progress ring clamps to 1, but the displayed
  `12/8` looks weird. Decision: keep showing the raw value
  (truthful), let the ring stay full. Same as Detail.
- **Widget / Live Activity parity**: not in scope for this PR, but
  any model change (skip flag) propagates. Argues for deferring
  the schema change unless the user wants it.
- **Sensory feedback**: today fires `.success` on `isCompletedToday`
  changes for binary/negative. Need to extend to counter (`.success`
  when target is first reached, *not* on every increment) and
  timer (same). Pattern already in `CounterQuickLogView` lines
  59-61: `.sensoryFeedback(.success, trigger: targetReached) { old, new in !old && new }`.

## Open questions

All resolved 2026-04-18:

- [x] **Q1 — "Skip today" in this PR?** **Defer.** Skip lands in a
  later PR with the SchemaV2 migration (`CompletionKind`
  discriminator) and the matching Detail-history plumbing. This
  PR's context menu ships *Open detail*, *Edit*, *Archive*.
- [x] **Q2 — Score trend arrow (↑/↓/→)?** **Defer.** Ship
  score-only first; trend is a follow-up polish.
- [x] **Q3 — Negative habit trailing label?** **"Slipped"** (past
  tense, neutral). FR translation choice deferred to build —
  candidates: "Raté", "Cédé".
- [x] **Q4 — Counter trailing: stepper or `+1` only?** **Stepper
  `−/+`** for parity with Detail. `ViewThatFits` collapses to
  `+1` only at Dynamic Type XXL+ where the row width can't host
  both buttons.
- [x] **Q5 — Timer trailing: chip and/or sheet?** **Both.**
  Trailing `+5m` chip for the fast path; *Log specific session…*
  in the context menu opens the existing `TimerLogSheet`.

## References

- [SwiftUI Button inside NavigationLink in List](https://developer.apple.com/documentation/swiftui/navigationlink) (iOS 17+ behavior)
- [.contextMenu](https://developer.apple.com/documentation/swiftui/view/contextmenu(menuitems:))
- [.swipeActions](https://developer.apple.com/documentation/swiftui/view/swipeactions(edge:allowsfullswipe:content:))
- [.sensoryFeedback](https://developer.apple.com/documentation/swiftui/view/sensoryfeedback(_:trigger:))
- [Circle().trim — progress ring pattern](https://developer.apple.com/documentation/swiftui/circle)
- Prior art: Streaks (named action button on completed row), Loop Habit Tracker (inline stepper for counters), (Not Boring) Habits (progress ring + animated badge)
