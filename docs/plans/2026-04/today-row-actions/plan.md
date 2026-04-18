# Plan — Today Row Actions

**Date**: 2026-04-18
**Status**: done (built 2026-04-18)
**Research**: [research.md](./research.md)

## Summary

Redesign the Today tab's habit row: type-aware trailing controls
(`Mark done` pill, `Slipped` pill, `−/+` stepper, `+5m` chip),
progress ring around the leading icon for counter/timer, a
`streak · score` line under the habit name, a long-press context
menu for *Log specific value… / Open detail / Edit / Archive*, and
swipe-from-trailing Undo on completed binary/negative rows. Row body
still navigates to Detail. No SwiftData schema change in this PR;
*Skip today* and the trend arrow are deferred to follow-ups.

## Decisions locked in

- Row body tap → Detail (Detail discovery preserved).
- Streak + score appear on the row (reverses v0.1 minimalism call).
- Negative trailing label = `Slipped`. FR translation chosen at
  build time; candidates: "Raté", "Cédé".
- Counter trailing = inline `− value/target +` stepper, with a
  `ViewThatFits` fallback to `+1` only at Dynamic Type XXL+.
- Timer trailing = `+5m` quick-log chip; *Log specific session…*
  available via the context menu, opening the existing
  `TimerLogSheet`.
- Skip today and the score trend arrow are out of scope.
- New testable seam: `HabitRowState` free struct returning
  `(status, progress)` from `(Habit, [Completion], Calendar, Date)`.
  Tests target this struct directly (no SwiftUI host needed).
- `isCompletedToday` semantics are **redefined for counter/timer**:
  `complete` = `value >= target`. `partial` (value > 0 < target)
  is a new state surfaced by the progress ring. Binary/negative
  semantics unchanged.
- New rule: tap the trailing pill / stepper / chip → action; tap
  anywhere else on the row → Detail. Verified at Task 3's first
  `build_run_sim`.

## Task list

### Task 1 ✅: `HabitRowState` tests (red)

**Goal**: Specify the row's derived state before writing the
implementation.

**Changes**:
- New file: `KadoTests/HabitRowStateTests.swift`.

**Tests / verification**:
- `@Test("Binary with no completion today is .none, progress 0")`
- `@Test("Binary with a completion today is .complete, progress 1")`
- `@Test("Negative with a slip recorded today is .complete (= slipped), progress 1")`
- `@Test("Counter with no completion today is .none, progress 0")`
- `@Test("Counter with value below target is .partial, progress = value/target")`
- `@Test("Counter with value at target is .complete, progress = 1")`
- `@Test("Counter with value above target is .complete, progress clamped to 1")`
- `@Test("Timer with no completion today is .none, progress 0")`
- `@Test("Timer with seconds equal to target is .complete, progress 1")`
- `@Test("Timer with partial seconds is .partial, progress = seconds/target")`
- `@Test("Day boundary: a completion at 23:59 yesterday Paris time does not count as today")` — pin calendar to Europe/Paris per CLAUDE.md, exercise the DST-safe path.
- `test_sim` (full suite) reports new tests **failing** (they reference a type that doesn't exist yet).

**Commit message**: `test(today): HabitRowState contract (red)`

---

### Task 2 ✅: `HabitRowState` implementation (green)

**Goal**: Make Task 1's tests pass.

**Changes**:
- New file: `Kado/Models/HabitRowState.swift` — value type with:
  ```swift
  nonisolated struct HabitRowState: Equatable, Sendable {
      enum Status: Equatable, Sendable { case none, partial, complete }
      let status: Status
      let progress: Double          // clamped 0...1
      let valueToday: Double?       // nil if no completion today
      static func resolve(habit:, completions:, calendar:, asOf:) -> Self
  }
  ```
- The `resolve` static reads today's completion (calendar-aware
  day comparison), then dispatches on `habit.type` to compute
  status/progress. Counter overshoot clamps progress to 1 but
  preserves the raw `valueToday`.

**Tests / verification**:
- `test_sim` reports the new tests **passing**.
- No regressions in existing suites.

**Commit message**: `feat(today): add HabitRowState value type`

---

### Task 3 ✅: Rewrite `HabitRowView` — layout, ring, metrics line

**Goal**: Establish the new visual structure end-to-end with
binary/negative trailing pills wired up. Counter/timer trailing
stays text-only this commit (replaced in Task 4 / 5).

**Changes**:
- `Kado/UIComponents/HabitRowView.swift`:
  - Accept new inputs: `state: HabitRowState`, `streak: Int`,
    `scorePercent: Int` (or pass a small `HabitRowMetrics` struct
    if call sites grow).
  - Three regions: leading badge (with `Circle().trim(...)`
    progress ring overlay for counter/timer; filled disk for
    binary/negative when `.complete`), center two-line stack
    (name + `🔥 streak · score%` caption), trailing pill region.
  - Trailing for binary: `Button("Mark done")` /
    `Button(label: { Label("Done", systemImage: "checkmark") })`
    using `.borderedProminent` tint with `habit.color` →
    completed state is filled-with-check capsule.
  - Trailing for negative: `Button("Slipped")` red
    `.borderedProminent` → completed state is filled red capsule.
  - Trailing for counter/timer: keep the existing text label
    until Tasks 4 / 5.
  - `accessibilityLabel` updated to include streak + score in the
    combined row label (per CLAUDE.md `LocalizedStringKey` pattern).
- `Kado/Views/Today/TodayView.swift`:
  - Inject `\.streakCalculator` and `\.habitScoreCalculator`.
  - Compute `state`, `streak`, `scorePercent` per row inline (the
    list is small in v0.x; defer memoization until measured).
  - Build `HabitRowState.resolve(...)` via the env calendar.
- Strings hand-authored into `Localizable.xcstrings` (EN + FR):
  `Mark done`, `Done`, `Slipped`, `Slipped today` (a11y), and the
  expanded combined a11y label (`{name}, {state}, streak {n}, score {p}%`).
  Includes cleanup of the Xcode auto-noise currently in the
  working copy (one cohesive l10n change, not two).

**Tests / verification**:
- `test_sim`: all green.
- `build_run_sim` on iPhone 17 Pro: tap the binary pill → row
  toggles, no navigation. Tap row body → pushes Detail. **This
  verifies the locked rule**; if it fails, fall back to a
  programmatic `selection`-bound `NavigationStack` (call out as a
  scope expansion before pivoting).
- Previews: light + dark + Dynamic Type XXXL each cover all four
  types in `.none` and `.complete` states.
- `screenshot` of the populated Today list to confirm visual
  parity with the design.

**Commit message**: `feat(today): redesign row layout with progress ring and metrics line`

---

### Task 4 ✅: Counter trailing stepper

**Goal**: Replace the counter row's text-only trailing with an
inline `− value/target +` stepper that calls `CompletionLogger`
directly.

**Changes**:
- `HabitRowView.swift`: counter trailing becomes a 3-element
  HStack — minus button (28pt circular, disabled at 0), value
  label (`"\(value)/\(target)"` monospaced), plus button (28pt
  filled with `habit.color.opacity(0.15)`).
- `ViewThatFits` wrapper: collapse to `+1` only above Dynamic Type
  XXL (use `XXXL` as the boundary; verify with the existing XXXL
  preview).
- `TodayView.swift`: pass `onIncrement` / `onDecrement` closures
  that call `CompletionLogger.{increment,decrement}Counter`.
- `.sensoryFeedback(.success, trigger: state.status == .complete)`
  guarded to fire only on the `.partial → .complete` edge (mirror
  the pattern from `CounterQuickLogView` lines 59-61).
- New strings: `Decrement` (a11y already exists in
  `CounterQuickLogView`; reuse the catalog key), `Increment`
  (same).

**Tests / verification**:
- `test_sim`: existing CompletionLogger suite still green; no new
  tests required (logic is logger-side, already covered).
- `build_run_sim`: tap `+` → value increments, ring fills, no
  navigation. Tap `−` at 0 → no-op (button disabled). Tap row
  body → Detail.
- Preview: counter row in `.none` / `.partial(3/8)` / `.complete(8/8)` / overshoot(`12/8`) states.

**Commit message**: `feat(today): inline counter stepper on row`

---

### Task 5 ✅: Timer `+5m` chip trailing

**Goal**: Replace the timer row's text-only trailing with a
`+5m` chip that adds 5 minutes to today's session.

**Changes**:
- `HabitRowView.swift`: timer trailing becomes a `Button("+5m")`
  in pill shape, secondary tint.
- New `CompletionLogger` helper (or extend
  `incrementCounter` to support a custom delta, which it
  already does — pass `delta: 300` directly via a new
  `incrementTimerSeconds(by:)` thin wrapper for clarity at the
  call site).
- `.sensoryFeedback(.success, trigger:)` on the `.partial → .complete` edge.
- New strings: `+5m`, `Add 5 minutes` (a11y).

**Tests / verification**:
- `test_sim`: if a new `incrementTimerSeconds` thin wrapper is
  added, add a one-line test asserting it inserts a value=300
  completion when none exists and increments by 300 when one
  does.
- `build_run_sim`: tap `+5m` repeatedly → ring fills proportionally.
  Tap row body → Detail. Confirm the existing `TimerLogSheet`
  on Detail still works (sanity check).

**Commit message**: `feat(today): timer +5m quick-log chip on row`

---

### Task 6 ✅: Context menu — Log specific value, Open detail, Edit, Archive

**Goal**: Add a `.contextMenu` to every row exposing the
secondary actions.

**Changes**:
- `HabitRowView.swift`: add `.contextMenu { ... }` modifier with:
  - `Button("Log specific value…")` — counter/timer only.
    Counter sets `editingCounterHabit = record` on Today (sheet
    presents a numeric prompt — minimal `Form` with a `TextField`
    + Save, can reuse `CounterQuickLogView` patterns); timer sets
    `loggingTimerHabit = record` (presents existing
    `TimerLogSheet`).
  - `Button("Open detail")` — sets `selection = record` on
    Today's `NavigationStack`.
  - `Button("Edit")` — sets `editingHabit = record` (presents
    existing `NewHabitFormView(model: NewHabitFormModel(editing:))`).
  - `Button("Archive", role: .destructive)` — sets
    `confirmingArchiveOf = record` (presents
    `confirmationDialog` mirroring Detail's lines 62-73).
- `TodayView.swift`: introduce a single `@State` enum for
  presented sheets (CLAUDE.md prefers enums over bool soup):
  ```swift
  enum TodaySheet: Identifiable {
      case newHabit
      case editHabit(HabitRecord)
      case logCounter(HabitRecord)
      case logTimer(HabitRecord)
      var id: String { ... }
  }
  @State private var sheet: TodaySheet?
  @State private var confirmingArchiveOf: HabitRecord?
  ```
  Replace the existing `showingNewHabit` bool. `.sheet(item: $sheet)`
  switches on the case to render the right view.
- New strings: `Log specific value…`, `Open detail`, all the
  context-menu items in EN + FR.

**Tests / verification**:
- `test_sim`: all green (no new business logic).
- `build_run_sim`: long-press a row → menu appears. Each action
  presents the expected sheet/dialog. Archive → habit disappears
  from Today. Edit → name change reflects on next render.

**Commit message**: `feat(today): context menu with quick actions`

---

### Task 7 ✅: Swipe-from-trailing Undo on completed binary/negative

**Goal**: Match the iOS convention for "I marked the wrong row" —
swipe in from the trailing edge of a completed binary/negative
row to reveal a destructive Undo.

**Changes**:
- `HabitRowView.swift`: add `.swipeActions(edge: .trailing, allowsFullSwipe: true) { ... }` only when
  `state.status == .complete && (habit.type == .binary || habit.type == .negative)`.
  Action calls `onToggle` (which already toggles off).
- New string: `Undo` (a11y / button label) in EN + FR.

**Tests / verification**:
- `test_sim`: green (no new logic).
- `build_run_sim`: complete a binary habit → swipe trailing →
  Undo → row reverts. Same for negative. Swipe on a non-
  completed row or counter/timer row → no swipe action shown.

**Commit message**: `feat(today): swipe to undo completed binary rows`

---

### Task 8 ✅: Accessibility + Dynamic Type + dark-mode polish

**Goal**: Validation pass; tighten anything that surfaced.

**Changes**:
- Audit all four types' rows at Dynamic Type XXXL — does the
  stepper collapse correctly? Does the streak/score line wrap?
- VoiceOver pass on iPhone 17 Pro: every action has a clear
  label; the row is a single accessibility element where
  appropriate (per current `accessibilityElement(children: .combine)`
  pattern).
- Dark-mode preview audit (one preview per state combination).
- iPad simulator `build_sim` to confirm layout in regular size
  class.
- Re-run `screenshot` for the README / docs (Task 3's screenshot
  was for verification; this one is for the record).

**Tests / verification**:
- `test_sim`: all green.
- Manual: VoiceOver navigates row → name + state + streak +
  score is announced as one item; trailing button is a separate
  reachable element.

**Commit message**: `polish(today): accessibility and dynamic type pass`

---

## Risks and mitigation

- **Button inside NavigationLink tap-region behavior on iOS 18+**:
  if the trailing pill propagates taps to the NavigationLink
  (i.e. tapping `Mark done` also pushes Detail), the fallback is
  to lift navigation to a programmatic `NavigationStack(path:)`
  with manual selection on row body tap. That's a 30-line
  refactor in `TodayView` and counts as scope expansion — flag
  before proceeding.
- **Dynamic Type XXXL row width**: stepper + name + ring + caption
  may exceed any phone width. `ViewThatFits` collapse to `+1`
  only is the planned mitigation; if even that's too wide,
  collapse the streak/score line to score-only (drop the streak)
  at XXXL.
- **Swipe + context menu coexistence**: SwiftUI handles both, but
  on certain devices (older simulators especially) the long-press
  to start a swipe can pre-empt the contextMenu. Verify in Task 7
  on iPhone 17 Pro at minimum; if broken, the contextMenu is the
  primary affordance and swipe-Undo can be moved to the menu too.
- **Score recomputation cost**: every Today render computes
  `currentScore` for every due row. With ~50 habits × ~hundreds
  of completions each, this could be measurable. Mitigation
  (only if measured): memoize per `(habit.id, completions.count)`
  in a small `@State` cache. Not included in the plan; would be a
  follow-up if the row appears janky during scroll.
- **Localization sync timing**: per CLAUDE.md, `xcodebuild` doesn't
  auto-sync the `.xcstrings`. Hand-author every new entry with
  EN + FR + comment. Includes cleanup of the Xcode auto-generated
  noise currently sitting in the working copy.
- **`+5m` overshoot on timer**: a 30-min target with current 28-min
  becomes 33-min on tap. Decision: allow overshoot (truthful), ring
  clamps to full. Same policy as counter overshoot. Document via
  test in Task 5 if a wrapper is added.

## Open questions

None for the user. Both internal questions resolved during build:

- [x] **Logger wrapper** — passed `delta: 300` directly through
  `incrementCounter`. The call site comment explains the seconds
  convention; the thin wrapper would have added 8 lines and a
  test for nothing.
- [x] **Counter "Log specific value…" sheet** — went minimal: a
  `Form` + `Stepper` matching `TimerLogSheet`'s shape. No richer
  numeric pad needed; the row's `+`/`−` covers fine adjustments,
  the sheet covers "set to N" jumps.

## Notes during build

- **Task 3 — Negative pill state**: first cut made the `Slipped` pill
  always `.borderedProminent` red, which gave no visual difference
  between "not slipped today" and "slipped today." Fixed before
  commit by introducing a `NegativePillStyleModifier` that swaps
  `.bordered` (outlined, calm) for not-slipped and
  `.borderedProminent` (filled red + checkmark) for slipped.
  Mirrors the binary "filled vs not" pattern but with red instead
  of habit color.
- **Task 5 — No new logger wrapper**: skipped the
  `incrementTimerSeconds(by:)` thin wrapper — `incrementCounter`'s
  existing `delta` parameter handles the seconds delta directly,
  with a comment at the call site explaining the
  units-per-habit-type convention. Saved 8 lines and one extra
  test.
- **Task 6 — `setCounter` over `incrementCounter`**: the
  "Log specific value…" sheet for counters genuinely needs
  *replace*, not *increment*. Added `CompletionLogger.setCounter`
  (with four new tests) that overwrites today's value and deletes
  the record when set to 0 (preserves the
  no-completion ↔ not-started bijection).
- **Task 6 — `NavigationStack` path**: switched
  `NavigationStack { ... }` to `NavigationStack(path: $path)` so
  the context-menu *Open detail* item could push programmatically.
  No regression on tap-to-navigate; both compose cleanly.
- **Task 8 — `.combine` + multiple actions**: the row keeps
  `.accessibilityElement(children: .combine)` (one VoiceOver entry
  per habit), but the trailing pill / stepper / chip actions get
  buried in that mode. Added an `.accessibilityActions` block that
  re-exposes them via the VoiceOver Actions rotor. The default
  activate stays "push detail" via the `NavigationLink`.
- **Button-in-NavigationLink tap region**: the locked-decision risk
  from the plan didn't materialize. Tapping `Mark done` /
  `Slipped` / stepper buttons / `+5m` fires the action and does
  not push Detail; tapping anywhere else on the row pushes Detail.
  Verified manually in the simulator on iPhone 17 Pro with the
  `screenshot` tool confirming the layout.
- **iPad layout**: `build_sim` against iPad Air 11-inch (M4)
  succeeded. Visual verification deferred (the default
  XcodeBuildMCP install can't reach more than the launched
  surface).
- **xcstrings auto-noise**: the previously-stashed Xcode-generated
  entries (`%lld`, `%@. %@`, `Checking iCloud…`, etc.) were
  brought to this branch but **not cleaned up** — they ride
  along as inert auto-extracted entries. They're real strings the
  app uses; full hand-authoring (comments + FR translations) is a
  catalog-cleanup follow-up.

## Out of scope

- **Skip today** in the context menu — needs SchemaV2 (a
  `CompletionKind` discriminator on `CompletionRecord`). Defer to
  a dedicated PR that includes the migration, the Detail-history
  rendering of skipped days, and the score-calculator policy for
  skips (probably "neutral", neither completion nor miss).
- **Score trend arrow** (↑/↓/→ next to the percentage). Needs a
  prior-week-score derivation; small but additive. Defer.
- **Per-habit haptic profiles** (e.g. soft for negative, success
  for positive). Today's flat `.success` is fine for v1.
- **Watch / Widget parity** with the new row design. Out of scope
  by definition; today's redesign affects iOS only.
- **Score memoization / perf optimization** — only worth doing
  with a measurement.
