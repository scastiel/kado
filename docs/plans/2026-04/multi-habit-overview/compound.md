# Compound — Multi-habit overview

**Date**: 2026-04-17
**Status**: complete
**Research**: [research.md](./research.md)
**Plan**: [plan.md](./plan.md)
**PR**: [#12](https://github.com/scastiel/kado/pull/12)

## Summary

Built the v0.2 Overview tab: a habits × days matrix tinted by per-day
completion value, bundled with `Habit.color` + `Habit.icon` (v0.1
ROADMAP items that became load-bearing for the visual). Two
post-build pivots dominated the lessons: **the cells were initially
tinted by EMA score and looked uniform for daily habits — switched
to per-day value**, and **the matrix layout went through four
iterations of sticky / per-card / synced / overlay before landing
on a full-width single scroll with a transparent label overlay**.

## Decisions made

- **Bundle schema + matrix in one PR**: uniform-color cells defeated
  the visual, so `Habit.color/icon` had to land with the matrix
  rather than as a precursor PR.
- **Cells tint by per-day value, not EMA**: the EMA score is too
  smooth for daily habits; users expect the Overview to answer "did
  I do it that day?", not "what's the trend?"
- **`DailyValue` namespace**: per-day value extracted as a shared
  helper so the score calculator (EMA input) and the matrix (cell
  tint) agree on one definition.
- **Opacity floor 0.2, not 0.08**: 0.08 collapsed missed-due cells
  into the gray of `.notDue`; 0.2 keeps them clearly colored. Linear
  remap `0.2 + 0.8 × value` preserves counter/timer partial detail.
- **Single horizontal `ScrollView` + transparent label overlay**:
  after trying sticky-left, per-card, and synced `scrollPosition`,
  one shared scroll is by construction synchronized. Labels sit in
  a sibling overlay aligned to empty spacer rows inside the scroll.
- **Per-cell `.popover(isPresented:)`**: anchors the popover to the
  tapped cell. A single `.popover(item:)` at the view level anchored
  to the whole matrix (always floats at the top).
- **Dev sandbox wipe-and-retry on schema error**: disposable data +
  schema bumps = transparent recovery. Explicitly NOT applied to
  the production container.
- **`colorRaw: String` workaround for `HabitColor`**: SwiftData's
  `@Model` couldn't round-trip even a plain `String`-raw-value enum,
  so the existing JSON-blob pattern (used for `Frequency`/`HabitType`)
  extends to this simpler case.

## Surprises and how we handled them

### SwiftData enum round-trip ceiling

- **What happened**: storing `var color: HabitColor = .blue` directly
  on `@Model` crashed at load with `Could not cast Optional<Any> to
  Kado.HabitColor`, despite `HabitColor` being a plain
  `String`-raw-value, `Codable`, `Sendable` enum.
- **What we did**: generalized the `Frequency`/`HabitType` workaround
  — store raw `String` (`colorRaw: String = "blue"`), expose
  `color: HabitColor` via computed accessor.
- **Lesson**: on Xcode 26 / iOS 18, **any** custom enum type
  (including `RawRepresentable` with primitive raw value) is
  unreliable as a direct `@Model` stored property. CLAUDE.md only
  flagged composite / associated-value enums; the constraint is
  actually broader.

### `@Model` macro rejects shorthand defaults

- **What happened**: `var color: HabitColor = .blue` → "A default
  value requires a fully qualified domain named value (from macro
  'Model')". Also blew up the macro-generated code with "type
  'Any?' has no member 'blue'".
- **What we did**: `var color: HabitColor = HabitColor.blue`.
- **Lesson**: SwiftData's `@Model` macro needs fully-qualified
  enum defaults. Leading-dot shorthand breaks it. Applies to any
  enum-typed stored property.

### Stale dev sandbox broke launch

- **What happened**: after bumping to V2, the pre-existing V1 sqlite
  on the sim failed staged migration with "unknown model version".
- **What we did**: added a wipe-and-retry to
  `DevModeController.buildDevContainer`. Production container was
  explicitly not touched — user data is never silently discarded.
- **Lesson**: dev-sandbox containers deserve different resilience
  than production. Make the distinction explicit in code.

### EMA tinting hid daily variance

- **What happened**: the first working build showed every cell for
  every daily habit at roughly the same mid-opacity. Gym looked
  varied only because `specificDays` produced mostly `.notDue` gray
  cells next to scored ones.
- **What we did**: pivoted cell encoding from EMA score to per-day
  value (0 for missed, 1 for completed, `achieved/target` for
  counter/timer). Repurposed `DailyValue` to be shared.
- **Lesson**: "gradient tint" in a ROADMAP line can mean two
  different things. Verify visually against real-looking seed data
  before committing to the interpretation. Preview-backed review
  during plan stage would have caught this.

### `scrollPosition(id:)` sync across multiple scroll views

- **What happened**: tried syncing independent card-level horizontal
  `ScrollView`s via a shared `@State scrolledDay: Date?` binding
  with `.scrollPosition(id:)`. Pans didn't propagate reliably
  (likely compounded by `LazyVStack`'s late rendering overwriting
  the binding in `.onAppear`).
- **What we did**: collapsed to **one** `ScrollView(.horizontal)`
  wrapping the full matrix. Labels live in a sibling overlay, not
  inside separate scroll views.
- **Lesson**: if you need synchronized horizontal motion across
  many rows, prefer one scroll view over N with a shared binding.
  Cross-ScrollView sync via `scrollPosition(id:)` is brittle in
  practice on iOS 18.

### Popover always anchored at view center

- **What happened**: attaching `.popover(item: $selection)` to the
  matrix container always floated the popover at roughly the center
  of the view, not at the tapped cell.
- **What we did**: moved the popover to each cell `Button` with a
  per-cell `Binding<Bool>` derived from the shared `selection`
  state.
- **Lesson**: popover anchoring is tied to the view the modifier is
  attached to. For item-driven popovers on grids, attach per-item,
  even if it means N registered modifiers.

### Swift switch-return rule bit twice

- **What happened**: mixing single-expression arms with
  multi-statement arms in a computed property's `switch` produced
  the confusing "missing return in getter" error. Hit once in
  `CellPopoverContent.statusLabel` and again in
  `DayCell.colorOpacity` after adding a multi-step computation.
- **What we did**: explicit `return` on every arm in both cases.
- **Lesson**: CLAUDE.md already flags this. Worth re-reading when
  editing any `switch`-returning computed property.

### Float precision in tests

- **What happened**: `DayCell.scored(0.5).colorOpacity` returned
  `0.6000000000000001`, failing `== 0.6`.
- **What we did**: replaced `==` with a small tolerance helper in
  the opacity tests.
- **Lesson**: never assert exact equality on computed Doubles, even
  for "obvious" arithmetic like `0.2 + 0.8 * 0.5`.

## What worked well

- **TDD for `OverviewMatrix`**: writing red tests in one commit and
  then turning them green in the next kept the service contract
  crisp. Tests survived the per-day-value pivot with only one
  assertion change.
- **Conductor stages**: research caught the EMA vs per-day question
  but mis-resolved it on my interpretation, not the user's. The
  plan's open-questions section let design decisions queue up
  cleanly. Compound is now naming what drifted so we can correct
  for next time.
- **Small, themed commits (23 total)**: every post-build pivot was
  one focused commit, easy to review and revert. Review the branch
  by oneline git log and the story reads itself.
- **SwiftUI previews covering state space**: populated / empty /
  dark / Dynamic Type XXXL on every new component. Caught rendering
  issues without sim runs for most iterations.
- **XcodeBuildMCP's `launch_app_logs_sim`**: one command surfaced
  the `Could not cast Optional<Any> to Kado.HabitColor` crash. The
  logs-on-launch flow is a strong debugging loop.

## For the next person

- The Overview's label overlay and scroll content **must** keep
  their vertical heights in lockstep. Constants:
  `headerHeight(40) + rowGap(12) + N × (labelHeight(28) +
  labelBottomPadding(8) + cellSize(36) + optional rowGap)`. If you
  change any constant in one, change it in both. There's no
  regression test; rely on preview inspection.
- **`DailyValue.compute` is the single definition** of per-day
  value semantics. `DefaultHabitScoreCalculator` feeds it into the
  EMA; `OverviewMatrix` uses it as the cell tint source. New habit
  types must update it here.
- The tap popover's arrow points at the cell because each cell
  owns its own `.popover(isPresented:)` modifier. ~150 modifiers
  register simultaneously for a full seed (5 habits × 30 days).
  Performance is fine today; if perf shows up as an issue, consider
  a custom popover surface rather than reshaping this.
- `DevModeController.buildDevContainer` silently wipes the sandbox
  on migration failure. This is by design and documented in the
  method's comment. Do **not** copy this recovery into
  `defaultProductionContainer()`; the opposite behavior (fatal
  error + user-visible surfacing) is correct there.
- Adding a new `@Model` property with a non-primitive type
  (including `String`-raw-value enums) needs the JSON blob or raw
  String workaround. Direct storage crashes at load on Xcode 26.

## Generalizable lessons

- **[→ CLAUDE.md]** Broaden the "Composite Codable workaround"
  section: on Xcode 26 / iOS 18, even plain `RawRepresentable`
  enums with primitive raw values don't round-trip reliably as
  direct `@Model` stored properties. Store the raw value; expose a
  computed accessor. `HabitColor` is the second canonical example
  alongside `Frequency`/`HabitType`.
- **[→ CLAUDE.md]** `@Model` macro default values must be
  fully-qualified: `HabitColor.blue`, not `.blue`. Add a one-liner
  to the SwiftData section.
- **[→ CLAUDE.md]** `.scrollPosition(id:)` binding for
  cross-`ScrollView` sync is unreliable on iOS 18 (especially inside
  `LazyVStack`). When multiple rows need to scroll horizontally in
  lockstep, collapse to one `ScrollView` and layer non-scrolling
  content as overlays.
- **[→ CLAUDE.md]** `.popover(item:)` anchors to its attached view.
  For per-item popovers in a grid / list, attach per-item with
  `.popover(isPresented:)` + a derived `Binding<Bool>` — even
  though that means many registered modifiers.
- **[local]** EMA is the right model for the habit score; the
  overview surface is the wrong place to show it. Future "Stats"
  tab should be where EMA becomes visible cross-habit.
- **[local]** Overlay-label layout with matched heights is fragile.
  A single-source-of-truth layout helper (or a `Grid` / `Layout`)
  would be stronger if this gets extended.

## Metrics

- Tasks completed: 10 planned + 6 post-build fixes (per-day pivot,
  opacity floor, vertical-cards restructure, overlay labels, popover
  anchor, catalog additions)
- Tests: 125 → 140 (+15)
- Commits: 23 on `feature/multi-habit-overview`
- Files touched: 36
- Lines: +2271 / −113

## References

- Competitor survey (habit-tracker overview patterns):
  [Loop](https://loophabits.org/) · [Way of Life](https://wayoflifeapp.com/)
  · [HabitKit](https://www.habitkit.app/) ·
  [Sweet Setup review](https://thesweetsetup.com/apps/best-habit-tracking-app-ios/)
- CLAUDE.md's existing SwiftData / composite Codable workaround
  (this PR is the reason to broaden it).
