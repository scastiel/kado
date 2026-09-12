# Plan — Counter tap feedback

**Date**: 2026-09-11
**Status**: done
**Compound**: [compound.md](./compound.md)
**Research**: none — planned directly from
[#81](https://github.com/scastiel/kado/issues/81), which already names the
code sites and the cause. Assumptions are called out inline.

## Summary

On Today, tapping `+` on a counter row past its target gives nothing back:
the ring is already full, the `.success` haptic only fires on the
not-complete → complete edge, and the row shows no number. After tap 11 the
user can't tell whether the tap registered or what the count is. This plan
gives every quick-log tap a haptic tick (`.selection`, with `.success` kept
for the moment the target is met) across the four controls that share the
edge-only pattern, and brings a count back into the Today row's stepper —
`− 3 +` at every value, not only past the target — for counter and timer
habits alike.

One finding worth its own line: the `.increase` / `.decrease` feedback the
issue suggests **compiles on iOS and never plays** — Apple's docs for both:
*"Only plays feedback on watchOS and visionOS."* `.selection` is the iOS
kind for movement through discrete values (*"Only plays feedback on iOS and
watchOS"*), so that's what every tap uses.

## Decisions locked in

- **Haptic rule, one place**: `.success` when a change crosses from below
  the target to at-or-above it; `.selection` for every other change of the
  recorded value (increments past the target, every decrement); nothing
  when the value doesn't change. Exactly one feedback per tap — the two
  never stack on the edge.
- The rule is a pure `nonisolated enum QuickLogFeedback` in the app target
  (`SensoryFeedback` is `Equatable`, so it's unit-testable), applied through
  the `sensoryFeedback(trigger:) { old, new in … }` overload, which
  replaces the existing `.sensoryFeedback(.success, trigger:) { !old && new }`
  chains rather than sitting beside them.
- **All four quick-log controls** get the rule: `HabitRowView.counterStepper`
  and `timerAddFiveChip` (Today), `CounterQuickLogView` (Detail),
  `DayEditPopover`'s counter and timer steppers (calendar). Binary /
  negative toggles are untouched — a toggle has no "every tap" case.
- **The count is always visible in the row**: `− 3 +` for counters, `12m +5m`
  for timers, at every value including `0`. This reverts the
  *"drop value/target text; the ring is sufficient"* decision in
  `docs/plans/2026-04/today-row-actions/compound.md` — the ring
  structurally can't express past-target, and the classic stepper idiom
  answers "what's the count now" without explanation. Value only, no
  `/target`: the ring carries the target relation under target, and the
  filled disc says "met" past it.
- The count is **presentation only** — `state.valueToday` formatted in the
  view; `HabitRowState` doesn't change. Timer minutes floor to the minute
  (`Int(value / 60)`), the same rounding `accessibilityProgressText`
  already uses.
- ~~Haptics trigger on the **recorded value**, not on the tap — same as
  the existing `.success` today. A value that changes under the row from
  a CloudKit sync or the midnight rollover will tick once; that's the
  precedent the `.success` edge already set.~~ **Reversed after review**
  (see Notes during build): the haptic is recorded at the **mutation
  site** as a `QuickLogEvent` and played by one `.quickLogFeedback(_:)`
  on a stable ancestor. The controls carry no haptic of their own.
- The count animates with `.contentTransition(.numericText(value:))` under
  `KadoMotion.fast`, disabled when `accessibilityReduceMotion` is on.
- VoiceOver output is unchanged: the row is `.accessibilityElement(children:
  .combine)` with an explicit label / value, so the new `Text` never reaches
  the screen reader twice; the `N of target` phrase stays in
  `accessibilityValue` because the visual drops the target.

## Task list

### Task 1: `QuickLogFeedback` rule (tests first) ✅

**Goal**: one tested function that says which haptic a change of the day's
recorded value plays.

**Changes**:
- `KadoTests/QuickLogFeedbackTests.swift` (write first, `test_sim` red):
  - unchanged value → `nil`
  - below → below (3 → 4, target 8) → `.selection`
  - below → at (7 → 8) → `.success`
  - below → past in one step (7 → 12) → `.success`
  - at → above (8 → 9) → `.selection` — **the reported silence**
  - above → above (11 → 12) → `.selection`
  - decrement below (4 → 3) → `.selection`
  - decrement off the target (8 → 7) → `.selection`, never `.success`
  - target 0 (a legacy or degenerate habit): 0 → 1 → `.selection`
- `Kado/UIComponents/QuickLogFeedback.swift`:
  ```swift
  nonisolated enum QuickLogFeedback {
      static func feedback(oldValue: Double, newValue: Double, target: Double) -> SensoryFeedback?
  }
  ```
  Doc comment names the `.increase` / `.decrease` trap so nobody
  "simplifies" it back.

**Tests / verification**:
- `test_sim` green; nine cases above.

**Commit message (suggested)**: `feat(today): add the quick-log haptic rule`

---

### Task 2: Wire the Today row — counter stepper and timer chip ✅

**Goal**: every `+` / `−` / `+5m` tap on Today ticks; the target edge still
plays `.success`.

**Changes**:
- `Kado/UIComponents/HabitRowView.swift`:
  - `counterStepper(target:)`: replace `.sensoryFeedback(.success, trigger:
    isComplete) { !old && new }` with
    `.sensoryFeedback(trigger: state.valueToday ?? 0) { old, new in
    QuickLogFeedback.feedback(oldValue: old, newValue: new, target: target) }`.
  - `timerAddFiveChip(target:)`: same, with `targetSeconds`.
  - The modifier stays on the `ViewThatFits` / chip, outside the buttons,
    so the VoiceOver rotor actions (`rowAccessibilityActions`) tick too —
    they drive the same callbacks and the same state.

**Tests / verification**:
- `build_run_sim` (iPhone 17 Pro): tap `+` on a counter row 12 times on a
  target of 10 — haptics can't be felt in the simulator, so the check is
  that the build compiles and the row still fills / completes; the rule
  itself is Task 1's tests. On device: a tick per tap, `.success` once at
  10, ticks again at 11 and 12, a tick per `−`.
- `test_sim` still green (`TodayRowTests`, `HabitRowStateTests`).

**Commit message (suggested)**: `fix(today): tick on every counter and timer tap, not only at the target`

---

### Task 3: Wire the Detail screen — quick-log control and calendar popover ✅

**Goal**: the detail quick-log and the calendar day popover feel the same as
the row.

**Changes**:
- `Kado/UIComponents/CounterQuickLogView.swift`: replace the
  `targetReached`-edge `.sensoryFeedback` with the rule, trigger
  `todayValue`.
- `Kado/Views/HabitDetail/DayEditPopover.swift`:
  - `counterControl(target:)`: `.sensoryFeedback(trigger: counterValue) {
    old, new in QuickLogFeedback.feedback(oldValue: Double(old), newValue:
    Double(new), target: Double(target)) }` on the `Stepper`.
  - `timerControl(targetMinutes:)`: same on `timerMinutes` against
    `targetMinutes`.
  - **#80 lands in this file.** Trigger on whichever value the popover's
    label reads — today that's the local `@State`; if #80's fix makes
    `currentValue` the source of truth, the trigger moves with it. Either
    order works; whichever PR merges second rebases a two-line hunk.
- Update `CounterQuickLogView`'s docstring ("A success haptic fires once
  when …") to describe the rule.

**Tests / verification**:
- `build_sim` clean. Previews for both files still render.
- On device: `Stepper` taps in the popover tick; the system `Stepper` has
  no haptic of its own, so no double-tick to check for.

**Commit message (suggested)**: `fix(habit-detail): tick on every quick-log and popover stepper tap`

---

### Task 4: Show the count in the Today row ✅

**Goal**: `− 3 +` on counter rows and `12m +5m` on timer rows, at every
value, so the number past the target — and every tap's effect — is visible.

**Changes**:
- `Kado/UIComponents/HabitRowView.swift`:
  - New `countLabel` subview: `Text(Int(state.valueToday ?? 0), format:
    .number)` for counters (no catalog key — a bare number), `Text("\(minutes)m")`
    for timers. `.font(.callout.weight(.semibold).monospacedDigit())`,
    `habit.color.color` when `isComplete`, `Color.kadoForeground` otherwise
    — the same colour rule as `CounterQuickLogView`'s big number.
    `.contentTransition(.numericText(value:))` + `.animation(reduceMotion ?
    nil : KadoMotion.fast, value: state.valueToday)`; add
    `@Environment(\.accessibilityReduceMotion)` to the row.
  - `counterStepperFull`: `− count +`. `counterStepperPlusOnly` (the
    Dynamic Type XXL+ fallback): `count +` — the count is the point of the
    change, so it survives the collapse; the `−` is what gives way.
  - `timerAddFiveChip`: `HStack(spacing: 8) { countLabel; chip }`.
  - Stale comments: the type docstring's **Trailing** bullet, the
    `counterStepper` doc (still says `− value/target +` from before the
    ring), and `accessibilityProgressText`'s "surfaced here because the
    visual text was removed" — now "the visual shows the value; VoiceOver
    also needs the target".
  - Previews: extend `"Counter — partial / overshoot"` with a `0` counter
    row and an over-target timer row (`2100s` on `1800s`); `"Dynamic Type
    XXXL"` and `"Dark"` already hold counter rows and pick the change up.
- `Kado/Resources/Localizable.xcstrings`: one new key, `%lldm` — FR
  `%lld min`, mirroring `+5m` → `+5 min`. Comment: "Minutes logged today,
  before the +5m chip on a timer Today row. Argument is whole minutes."
  Hand-authored; the catalog is source.

**Tests / verification**:
- `test_sim`: `LocalizationCoverageTests` passes with the new key.
- `screenshot` after `build_run_sim` on iPhone 17 Pro: a `0`, a partial, a
  complete and an over-target counter row, and a timer row. Check the `−`
  doesn't jump when the count crosses 9 → 10 (monospaced digits keep same-
  length counts steady; if the one-digit → two-digit step looks jumpy, give
  the label a `@ScaledMetric` `minWidth` — build-time polish, not a
  decision).
- Dynamic Type XXXL preview: the row collapses to `count +` and the name
  still gets its line. Increase Contrast: `kadoForeground` on `kadoPaper50`
  is the row's own text colour, nothing new to check.
- iPad Air (M4) `build_sim`: compiles; the row is width-independent.
- VoiceOver on the row: label / value unchanged (`Drink water, counter,
  target 8` / `3 of 8, streak 2, score 55 percent`).

**Commit message (suggested)**: `feat(today): show the day's count in the counter stepper and timer chip`

---

### Task 5: Visual and accessibility pass, then compound ✅

**Goal**: the definition of done, on the two surfaces that changed.

**Changes**:
- Fixups from the screenshot pass, if any, squashed into Task 4.
- `docs/plans/2026-09/counter-tap-feedback/compound.md`: the `.increase`
  trap, the reversal of the ring-only row decision and why, anything the
  visual pass caught.
- Mark the PR ready; link #81 with `Closes #81`.

**Tests / verification**:
- `build_sim` iPhone + iPad, no new warnings; `test_sim` green;
  `make e2e` green (the UI suite doesn't read the count today, but the row
  identifier and combined element must still resolve).

**Commit message (suggested)**: `docs(plans): compound the counter tap feedback`

## Integration checkpoints

- **SwiftData / CloudKit / HealthKit / widgets**: none. No schema, no
  snapshot-shape change; the widget snapshot builder is untouched.
- **Issue #80** shares `DayEditPopover` — see Task 3 for the trigger note.
- **Localization**: one new key (`%lldm`), pinned by
  `LocalizationCoverageTests`.
- **App Store screenshots**: the Today captures under
  `docs/app-store/screenshots/` show counter rows without a count. They
  drift after Task 4; re-run `make screenshots` with the next listing
  refresh rather than in this PR (a simulator per language per device, half
  an hour — see `docs/app-store/README.md`).

## Risks and mitigation

- **Haptics can't be verified in the simulator.** The rule is pinned by
  unit tests; the wiring is a one-line modifier per control. Budget one
  on-device check (TestFlight or a cable) before marking the PR ready —
  it's the reporter's complaint, and `test_sim` can't hear it.
- **A tick for a change the user didn't make** (sync, midnight). ~~Same
  exposure the `.success` edge already has.~~ Wrong — the old edge fired
  on `false → true` only and never on a value → 0 path, so a value-keyed
  `.selection` was *new* exposure: every counter and timer row would
  tick at once on the first foreground of a new day. Materialised in
  review and fixed by the tap-keyed swap this bullet sketched; see Notes
  during build.
- **Row width at large Dynamic Type.** `ViewThatFits` already drops the
  `−`; the count adds one to two digits to both variants. If the XXXL
  preview clips the name, the plus-only variant can drop the count last —
  `accessibilityValue` still carries the number, so nothing is lost for
  the users most likely to be at that size.
- **`.numericText` and Reduce Motion.** The transition only animates under
  an explicit animation; gating `.animation(value:)` on `reduceMotion` is
  the whole fix. The ring's `KadoMotion.base` animation isn't gated today
  — 200 ms ease-out is below the threshold where Reduce Motion matters —
  but the count's transition is gated because it's a new, more visible
  motion.

## Notes during build

- **Task 3**: `DayEditPopover` can't key its haptic on the value the
  label reads, as the plan said. The popover seeds `counterValue` /
  `timerMinutes` in `.onAppear` (0 → today's value), so a value-keyed
  trigger would tick — or play `.success` on a done day — every time the
  popover *opens*. The popover keys on the tap instead: the `Binding`
  setter (the only user-driven path) computes the feedback from old → new
  and bumps a `stepTick`; one `.sensoryFeedback(trigger: stepTick)` on the
  body covers both steppers. That's the "tap-keyed" alternative the Risks
  section describes for the row, needed here for a different reason. If
  #80 moves the popover off local state, the trigger stays where it is —
  it never depended on the state. *Superseded by the review fix below:
  the popover's `stepTick` is gone; `HabitDetailView` records the event
  where it writes the value.*
- **Task 4**: the Dynamic Type pass caught a real regression the XXXL
  preview couldn't (it holds no timer row): at AX3 the timer row's `35m`
  and its `+5m` chip both wrapped mid-token — `35 / m`, `+5 / m` — because
  the count now shares the trailing space with the chip. Fixed with the
  same `ViewThatFits` fallback the counter already had (`35m +5m`, then
  the chip alone) and `.fixedSize(horizontal:)` on the count so it can
  never split. Verified at AX3 and AX5 on the simulator via
  `simctl ui <udid> content_size`, which the run tools can't set. Seen
  alongside, **pre-existing** and untouched: the binary checkmark glyph
  overflows its 28pt circle at AX sizes, the "Slipped" pill breaks into
  three lines at AX5, and the habit name is a fixed 15pt system font.
- **Task 4**: to see the complete and over-target rows without tap
  primitives, the screenshot seed's today values were bumped locally
  (water 5 → 12, read nil → 2100s), photographed, and `git checkout`-ed
  back. Nothing of it is committed.
- **Review (`/code-review` on the finished branch)**: keying the row's
  haptic on `state.valueToday` was the wrong seam, for four reasons the
  review made concrete. (1) A new day zeroes every row's value on the
  first foreground → N simultaneous ticks on launch; the old `.success`
  edge never fired on value → 0, so this was a regression, not the
  "same exposure" the plan claimed. (2) A not-scheduled row that gets
  logged moves from the *other* `ForEach` to the *due* one — a new
  identity that never sees old → new — so the first tap on it was
  silent: the #81 class, still open for that case. (3) On Detail, a
  popover step on today also moved `CounterQuickLogView`'s value → two
  haptics per tap; and the "Log specific value…" sheets stacked their
  own save `.success` on the row's tick. (4) `target ≤ 0` never played
  `.success` while `HabitRowState` filled the badge. **Fix**: the
  mutation sites — `TodayView.incrementCounter / decrementCounter /
  addFiveMinutes`, `HabitDetailView`'s counterparts plus `setCounter /
  setTimerSeconds / clear` — read the value before, derive the value
  after from the step they apply (fixed `+1`, `−1` floored, `+300`, or
  the explicit value), and record a sequenced `QuickLogEvent`; one
  `.quickLogFeedback(quickLog)` sits on the Today `List` and the detail
  `ScrollView`. `HabitRowView`, `CounterQuickLogView` and
  `DayEditPopover` carry no haptic (the popover is byte-identical to
  `main` again — nothing for #80 to rebase). The sheets keep their
  `.success` because they save through their own logger call, not
  through these functions. `Clear` ticks like any step to 0. The
  zero-target rule now mirrors `HabitRowState`. `QuickLogFeedback`'s
  nine cases are unchanged; three `QuickLogEvent` cases join them.

## Open questions

- [ ] `0` at rest, or hide the count until something is logged? The plan
  shows `0` (the classic stepper; a disabled `−` beside it reads as
  "nothing yet"). Shipped as `0` / `0m` — on the seeded Today the timer
  row reads `0m +5m`, which scans as "0 minutes, add 5". Hiding it is a
  one-line `if` in `countLabel` if it grates.

## Out of scope

- **#80** — the popover's stuck display. Separate bug, separate PR; the
  two touch different lines of `DayEditPopover`.
- **`MonthlyCalendarView` treating any counter value as `.completed`**
  (noted in #80). Grid styling, not row feedback.
- **Per-habit haptic profiles** (the deferred idea in
  `today-row-actions/plan.md`). One rule for every control first.
- **Watch app** quick-log haptics — `.increase` / `.decrease` do play
  there, which is a different design.
- **Re-shooting the App Store listing** — with the next listing change.
