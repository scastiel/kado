# Plan — Day-edit popover stepper freezes after the first tap

**Date**: 2026-09-11
**Status**: in progress
**Research**: none — [issue #80](https://github.com/scastiel/kado/issues/80)
carries the code-level analysis, and a read of the code (below)
supports it. Planned directly from the issue by decision.

## Summary

For a counter habit, opening a past day from the detail screen's
monthly calendar and tapping `+` in the popover updates the display
once, then freezes it at **1** while every later tap still lands in
the store (5 after five taps, visible only after leaving and coming
back). `DayEditPopover` keeps its own `@State` copy of the value,
seeded once in `.onAppear`, and drives it through a SwiftUI `Stepper`
over a hand-rolled `Binding` — while the same value is also persisted
and re-derived upstream as `currentValue`. Two sources of truth; the
first tap's *insert* is what separates them. The fix makes the
popover's value controls stateless — render `currentValue`, step via
the existing callbacks — which is already how the two counter
surfaces that *don't* have the bug work (`HabitRowView.counterStepper`
and `CounterQuickLogView`). The timer control has the identical shape
and is fixed in the same pass. A UI test reproduces the five-tap
scenario, because this bug lives inside a SwiftUI update pass where a
unit test has no seam.

## What the code says

- `Kado/Views/HabitDetail/DayEditPopover.swift` — `counterValue` /
  `timerMinutes` are `@State`, seeded in `seedLocalState()` from
  `.onAppear`. `counterControl` / `timerControl` each build a
  `Stepper(value: Binding(get: { counterValue }, set: { counterValue = $0; onSetCounter(…) }))`.
  The displayed `Text` reads the `@State`, not the prop.
- `Kado/Views/HabitDetail/HabitDetailView.swift` — `currentValue(on:)`
  is derived from `completions`, a value-type snapshot rebuilt by
  `HabitDetailLoader`'s `@Query` on every mutation. `setCounter(_:on:)`
  runs `CompletionLogger.setCounter` → `save()` →
  `WidgetReloader.reloadAll` synchronously inside the binding setter.
- `Kado/UIComponents/MonthlyCalendarView.swift` — the popover is
  attached per cell via `.popover(isPresented: popoverBinding(for: day))`
  and `popoverContent(day)` is re-evaluated on every parent render.
- `Kado/UIComponents/HabitRowView.swift` (`counterStepper`) and
  `Kado/Views/HabitDetail/CounterQuickLogView.swift` — the working
  pattern: **no local state**, plain `−` / `+` `Button`s, value
  rendered from the query-derived prop, mutation through a callback.
- `Kado/Services/CompletionLogger.swift` — tap 1 *inserts* a
  `CompletionRecord`; taps 2…n only *update* `value` on it.

The symptom set — display frozen at 1, writes landing as 2, 3, 4, 5 —
is what you get when the popover's view identity is recycled around
that first insert: a fresh `@State` box is seeded to 1 by `.onAppear`
and never written again, while the stepper's captured binding keeps
counting the *old* box up. Whether the recycle is a popover
re-presentation or something inside the hosting controller is not
settled by reading; Task 2 records what actually happens. The fix
doesn't depend on the answer: with no local copy there is nothing to
go stale.

## Decisions locked in

- Plan directly from issue #80; no separate `research.md`.
- **Stateless popover.** Drop `@State counterValue` / `timerMinutes`
  and `seedLocalState()`'s value half. Render `currentValue`; step via
  `onSetCounter(currentValue ± 1)` / `onSetTimerSeconds(…)`.
- **Plain `Button`s, not a pass-through `Binding` into `Stepper`.**
  A `Stepper` is UIKit-backed and its coordinator holds the binding it
  was made with; if the surviving control is what keeps counting the
  old box, a binding whose getter reads a captured `currentValue`
  would freeze the *writes* too. `Button` actions are re-read from the
  current view value on every render. It also matches
  `CounterQuickLogView`, at popover scale.
- **Fix counter and timer together.** Same file, same bug class.
- **Verify with a UI test + a manual visual pass.** New
  `KadoUITests/DayEditPopoverTests.swift`, run by `make e2e`.
- Accessibility identifiers land in the same commit as the controls
  they identify (`CLAUDE.md` rule); the ones for leaves that already
  exist land first so the red test can be written against them.
- Bounds stay what the `Stepper` enforced: counter `0…max(target×3, 99)`,
  timer `0…480` minutes. `−` disabled at 0, `+` disabled at the cap.
- Reuse the existing `Increment` / `Decrement` catalog keys for the
  new buttons' `accessibilityLabel` (already shipped for
  `CounterQuickLogView`), so `LocalizationCoverageTests` stays green
  with no new FR entries.

## Task list

### Task 1: Identifiers on the leaves that already exist ✅

**Goal**: give the UI test locale-independent handles on the calendar
day cells, the counter quick-log's `+`, and the popover's value text —
without touching the controls the fix replaces.

**Changes**:
- `Shared/AccessibilityID.swift` — under `HabitDetail`:
  - `static func calendarDay(_ day: Int) -> String` →
    `"habitDetail.calendar.day.\(day)"` (unique within the displayed
    month; the test only ever addresses the month on screen).
  - `static let quickLogIncrement = "habitDetail.quickLog.increment"`
    — how the test recognises the counter habit's detail while walking
    the seeded Today rows (row identifiers are keyed by a `UUID` the
    seed generates fresh each run).
  - `enum DayEdit` with `value`, `increment`, `decrement`, `clear`
    (`"habitDetail.dayEdit.<name>"`). Only `value` is applied in this
    task; the other three are applied in Task 3 with the controls
    they name. Say so in their doc comments.
- `Kado/UIComponents/MonthlyCalendarView.swift` — `cell(for:)` already
  collapses to one element with `.accessibilityElement()`; add
  `.accessibilityIdentifier(AccessibilityID.HabitDetail.calendarDay(dayNumber))`
  on that leaf.
- `Kado/Views/HabitDetail/CounterQuickLogView.swift` — identifier on
  the `+` `Button` (a leaf).
- `Kado/Views/HabitDetail/DayEditPopover.swift` — on the counter and
  timer value `Text`s: `.accessibilityIdentifier(…DayEdit.value)` and
  `.accessibilityValue("\(n)")` carrying the bare number, so the test
  asserts on `.value` and never parses "3 of 8" / "3 sur 8".

**Tests / verification**:
- `make test` green (nothing behavioural changed).
- `build_sim` iPhone, no new warnings.

**Commit message (suggested)**:
`feat(a11y): identify the calendar days and the day-edit popover value`

---

### Task 2: Reproduce #80 with a UI test — red

**Goal**: a test that fails on `main` the way the reporter's phone
does, and that stays in the suite as the regression guard. This is
also the reproduction the issue says hasn't happened yet.

**Changes**:
- `KadoUITests/DayEditPopoverTests.swift`, a `KadoUITestCase`:
  1. `launchApp(devMode: true)` — `DevModeSeed` has a counter habit
     (target 8, created 30 days ago) with completions on **odd**
     days-ago only, so any even day-ago is empty: the insert-then-update
     path the bug needs.
  2. `tapTab(.today)`, `waitForTodayRows`, then push rows by index
     until `app.buttons[quickLogIncrement]` exists on the detail;
     pop with `app.navigationBars.buttons.firstMatch` otherwise. Three
     pushes at most.
  3. Pick the target day: the first of `[2, 4, 6]` days ago that falls
     in the current month per `Calendar.current` (the simulator's
     calendar is what the app's `\.today` follows in a test run). If
     none does — the 1st or 2nd of the month — tap
     `previousMonthButton` first and use the last even day of that
     month. Tap `app.otherElements[calendarDay(n)]` (fall back to
     `descendants(matching: .any)` if the cell's element type differs
     — check the hierarchy dump once).
  4. Wait for `DayEdit.value`; tap `+` **three** times. In this task
     the `+` is the existing `Stepper`'s increment half —
     `app.steppers.firstMatch.buttons["Increment"]` under the pinned
     `language: "en"` — marked with a one-line comment that Task 3
     replaces it with `DayEdit.increment`. Re-query the element on
     every tap rather than holding a reference: if the popover *is*
     re-presented after tap 1, a held `XCUIElement` goes stale.
  5. `capture(app, "day-edit-after-three-taps")`, then assert
     `app.staticTexts[DayEdit.value].value as? String == "3"`.
- Temporarily (not committed) add
  `print("DayEditPopover.onAppear currentValue=\(currentValue)")` to
  the popover and read the count of appearances in the test log. Record
  the answer under **Build notes** below — it decides whether a
  follow-up issue about a re-presentation flicker is warranted.
- Same temporary run answers the plan's load-bearing assumption:
  print `currentValue` from `body` too, and confirm it follows
  1 → 2 → 3 while the display stays at 1. If it does *not* follow,
  stop — see Risks.

**Tests / verification**:
- `make e2e` (creates the per-worktree simulator on first run — slow
  once). The new test fails at step 5 reading `"1"`; the attached
  screenshot shows the popover on "1 of 8" with the cell already
  filled. Everything else in the suite still passes.

**Commit**: none — the test lands with the fix in Task 3 so every
commit on the branch keeps `make e2e` green.

---

### Task 3: Render the popover from the store, not a local copy

**Goal**: replace the `Stepper` + `@State` pair with stateless
`−` / `+` controls for counter and timer, apply the remaining
identifiers, and turn Task 2's test green.

**Changes** — `Kado/Views/HabitDetail/DayEditPopover.swift`:
- Delete `@State private var counterValue` and `timerMinutes`; drop
  the `.counter` / `.timer` arms of `seedLocalState()` (the note half
  stays — `noteText` is a genuine draft the user is typing).
- `counterControl(target:)` renders from
  `let value = Int(currentValue.rounded())`; a small private
  `stepRow(value:label:canDecrement:canIncrement:onDecrement:onIncrement:)`
  view draws the value `Text` between a `−` and a `+` `Button` in the
  visual language of `CounterQuickLogView` (circle fills, `.plain`
  style, `.monospacedDigit()`), sized for the popover.
  - `−` → `onSetCounter(Double(value - 1))`, disabled at 0.
    `setCounter(0)` already deletes the record, matching what
    `Clear` does — fine either way, but keep `−` disabled at 0 so the
    control reads the same as the quick-log.
  - `+` → `onSetCounter(Double(value + 1))`, disabled at
    `max(target * 3, 99)`.
  - `clearButton(shown: value > 0)`.
- `timerControl(targetMinutes:)` the same way, with
  `minutes = currentValue > 0 ? max(1, Int((currentValue / 60).rounded())) : 0`,
  `−` / `+` calling `onSetTimerSeconds(TimeInterval(minutes ∓ 1) * 60)`
  (the parent already routes `<= 0` seconds through `clear`), cap 480.
- Apply `DayEdit.increment` / `.decrement` on the buttons and
  `DayEdit.clear` on the clear button. `accessibilityLabel` reuses
  `String(localized: "Increment")` / `"Decrement"`.
- Update the type doc comment ("stepper for counter, minute stepper
  for timer" → "−/+ controls…") and add a short note on *why* there is
  no local state, pointing at #80.
- `KadoUITests/DayEditPopoverTests.swift` — swap the `Stepper` tap for
  `app.buttons[DayEdit.increment]`; remove the Task 2 comment.
- Previews are unchanged in shape (they already pass `currentValue`);
  confirm all eight still render, including the Dark one.

**Tests / verification**:
- `make e2e` green — `DayEditPopoverTests` reads `"3"`.
- `make test` green (`LocalizationCoverageTests` in particular — no
  new keys expected).
- `build_sim` iPhone **and** iPad, no new warnings.

**Commit message (suggested)**:
`fix(habit-detail): render the day-edit popover from the store, not a local copy (#80)`
— body cites the two-boxes mechanism and the Task 2 findings.

---

### Task 4: Visual and accessibility pass

**Goal**: satisfy the definition of done for a visual change on a
surface `test_sim` cannot see.

**Changes**: none expected; fixes fold into Task 3's commit or a
`fix(habit-detail): …` follow-up if they're separable.

**Tests / verification**:
- XcodeBuildMCP has no tap primitive, so the popover is reached by
  hand in Simulator.app (or its screenshot is taken from the UI test's
  `capture` attachment in the result bundle). Check, light and dark:
  - counter popover on an empty day → `+` ×3 → reads 3 of 8, cell
    filled, history list gained a row;
  - `−` back to 0 → cell clears, Clear button disappears;
  - timer popover → `+` ×2 → 2 of 30 min; `−` ×2 → 0, record gone;
  - the note field still seeds from `currentNote` and still commits.
- Dynamic Type XXXL: the value row wraps or shrinks without clipping
  in the `260…340` popover width.
- VoiceOver: `−` / `+` announce as Decrement / Increment; the value
  text announces its number.
- iPad: `.presentationCompactAdaptation(.popover)` is a no-op there;
  confirm the anchored popover still lays out.

---

### Task 5: Compound and PR

**Goal**: capture what Task 2 revealed about the popover's identity,
mark the PR ready.

**Changes**:
- `docs/plans/2026-09/day-edit-popover-stepper/compound.md` via the
  conductor `compound` stage — especially the re-mount finding and the
  "two boxes" reasoning, which is the reusable lesson: *a presented
  view that mirrors persisted state into `@State` is one identity
  recycle away from this bug; render from the prop.* Consider a
  `CLAUDE.md` SwiftUI bullet if the finding generalises.
- PR title `fix(habit-detail): keep the day-edit popover stepping after the first tap (#80)`,
  body in the Why / What / How / Next steps shape, linking here.
- Reply on #80 with the mechanism once known.

## Integration checkpoints

- **SwiftData**: none. No schema change; `CompletionLogger` is
  untouched.
- **CloudKit**: none.
- **Widgets**: `WidgetReloader.reloadAll` still runs once per tap, as
  before. Unchanged cost, noted under Out of scope.
- **Localization**: no new keys if `Increment` / `Decrement` are
  reused. `LocalizationCoverageTests` confirms.

## Risks and mitigation

- **The popover content might not re-evaluate from the parent's props
  after a mutation.** This is the assumption the whole fix rests on.
  Task 2's temporary `print` proves it in one run before Task 3 is
  written. If it fails: the fallback is the band-aid — keep a local
  mirror but re-seed it with `.onChange(of: currentValue)` — and the
  identity question gets its own investigation, because it would then
  also mean the binary toggle's label never flips while a note is
  expanded.
- **XCUITest and popovers.** On iPhone the popover is a separate
  window; `app.descendants(matching: .any)` queries span windows, and
  `app.popovers` exists if it doesn't. Check the hierarchy dump once
  rather than guessing element types (`capture` + `app.debugDescription`
  attachment, as `DevModeSwapTests` does).
- **Row walk to find the counter habit** costs up to three pushes.
  Acceptable; the alternative (a stable seed id or a type-tagged row
  identifier) is a wider change than the fix.
- **Day-number identifier is only unique within a month.** The test
  addresses the displayed month only, and navigates explicitly when
  it has to.
- **A first `make e2e` in a fresh worktree creates a simulator** and
  takes minutes. Budget for it; don't read the wait as a hang.
- **Rapid double-taps.** The old `Stepper` coalesced; two `Button`
  taps in one runloop tick each call `onSetCounter(value + 1)` with
  the *same* `value` → second tap is a no-op write. Harmless (the
  quick-log has the same property), but note it if it shows up in
  Task 4.

## Open questions

- [ ] Does the popover actually re-present after the first insert
      (Task 2 answers)? If yes, is the flicker worth its own issue?
- [ ] Should the Today row's `HabitRowView` counter chip and this
      popover share one `StepControl` view now that they draw the same
      thing? Defer unless Task 3's `stepRow` turns out identical.

## Out of scope

- The calendar cell showing partial progress (a 1-of-10 day looks like
  a 10-of-10 day) — noted in #80 as unrelated; worth its own issue.
- Haptic / above-target feedback in the popover — #81.
- Debouncing `WidgetReloader.reloadAll` across a burst of taps — a
  perf nicety, not part of this bug.
- Changing `CompletionLogger` semantics (`−` at 0, `Clear` vs delete).

## Notes during build

- **Task 1**: no surprises. A fresh worktree simulator logs a wall of `CoreData: error: Failed to stat path …/Kado.sqlite` on the first unit run — that is the App Group directory being created under the store, ends in "Recovery attempt … was successful!", and is not a failure.
