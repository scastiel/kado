# Compound — Today Row Actions

**Date**: 2026-04-18
**Status**: complete
**Research**: [research.md](./research.md)
**Plan**: [plan.md](./plan.md)
**Branch / PR**: [feature/today-row-actions](https://github.com/scastiel/kado/pull/13)

## Summary

Redesigned the Today tab's habit row from a single-affordance split-target
(invisible icon-toggle + body-navigates) into a four-region layout:
progress-ring badge, name + streak/score caption, type-aware trailing
control (icon check / text pill / stepper / chip), context menu, and
swipe-to-undo. Plan was 8 tasks; build delivered all 8 as planned, then
**7 follow-on iterations** driven by visual review reshaped the surface
materially. Headline lesson: the formal plan finished a *correct*
feature; the iterative loop made it a *good* one. Plan completion is
not feature completion.

## Decisions made

- **Trailing affordance is type-aware, not unified.** Binary check icon, negative text pill, counter `−/+`, timer `+5m` chip — each picked for the action's nature, not for visual symmetry.
- **`HabitRowState` as a free struct.** Pure value type, calendar-injected, returns `(status, progress, valueToday)` from `(Habit, [Completion])`. Tests target the struct, not the SwiftUI view. Same pattern as `CompletionToggler` per CLAUDE.md.
- **Streak + score on the row.** Reverses the v0.1 minimalism call ("Today's row is about today's state only"). The Today tab is now situationally aware; Detail is no longer the only place to read "how am I doing."
- **Row body still navigates to Detail.** Detail discovery preserved; the trailing control is the only thing that absorbs taps inside the row. Locked early, never relitigated.
- **No SwiftData schema change.** *Skip today* would have needed a `CompletionKind` discriminator and a SchemaV2 migration; deferred to its own PR.
- **`NavigationStack(path:)` introduced.** Required for the context-menu *Open detail* action to push programmatically without a row tap.
- **`TodaySheet` enum for sheet routing.** Replaces what would have been 4+ `@State` booleans (new / edit / log-counter / log-timer). One source of truth.
- **`setCounter` over `incrementCounter` for "Log specific value…".** Counter sheet genuinely needs *replace*, not *add*. Four new tests cover the contract; `value <= 0 → delete` preserves the no-completion ↔ not-started bijection.
- **Asymmetric trailing for binary vs negative.** Binary = icon (a check is unambiguously a check). Negative = text "Slipped" pill (a slip shouldn't read as "done at a glance"). Documented in the row docstring as a deliberate exception.
- **Drop value/target text on counter and timer.** The leading progress ring is sufficient; the numbers move into `accessibilityValue`. Saves visual density without losing info for screen-reader users.
- **VoiceOver via `.accessibilityActions`, not a full a11y rewrite.** Pragmatic surfacing of trailing actions through the rotor. Full `.accessibilityElement(children: .ignore)` + named-action refactor is a follow-up.

## Surprises and how we handled them

### Negative pill rendered identically in both states

- **What happened**: First cut made the `Slipped` pill `.borderedProminent` red in both states. Visually no difference between "you slipped today" and "you have not slipped today" — the second of which is the *good* outcome and should look calm.
- **What we did**: Caught from the first `screenshot` after the build-and-run, before commit. Introduced a tiny `NegativePillStyleModifier` that swaps `.bordered` (outlined, calm) for not-slipped and `.borderedProminent` (filled red + checkmark) for slipped.
- **Lesson**: The TDD loop catches *correctness* bugs but not *design* bugs. `screenshot` after each `build_run_sim` is cheap insurance — enforce it as a habit, not an afterthought.

### Icon-only check for negative was wrong

- **What happened**: Mid-iteration, switched both binary and negative to a 28pt circular icon button (✓ for binary, ✗ for negative) for visual consistency. User pushed back: "Let's keep [the text pill] for slipped." The reasoning landed retroactively — a slip is conceptually different from a positive completion, and an icon-only treatment makes the row read as "everything's a check at a glance."
- **What we did**: Reverted negative to the text pill in a single commit, kept the asymmetry, documented the *why* in the row docstring so future-me (or future contributor) doesn't re-unify them on aesthetics alone.
- **Lesson**: Visual symmetry isn't always semantic symmetry. When in doubt, let the meaning win and document the exception.

### Plan → "done" was actually halfway

- **What happened**: After Task 8's polish commit and the plan's "done" status, the user kept iterating: drop value text, swap to icons, revert negative, tighten spacing, truncate names, add the chip to Overview. Seven more meaningful commits before code review.
- **What we did**: Treated each iteration as its own micro-cycle (read context, edit, build, screenshot, commit, push). No replanning, no scope-creep alarm — these were design iterations on a shipped surface, not new tasks.
- **Lesson**: Build-stage "done" means *the plan is implemented*, not *the feature is finished*. Bake in time for a post-plan iteration loop driven by visual review. The cost is small per iteration; the upside is a noticeably better surface.

### Slider proposal — said no instead of yes

- **What happened**: User asked about a press-and-drag scrub slider for counter / timer. The mechanic is genuinely interesting, but the row already has tap → detail, long-press → menu, and swipe → Undo. A fourth gesture competes with long-press.
- **What we did**: Pushed back with two cheaper alternatives (long-press autorepeat on `+/−`, deferring the slider to a dedicated research cycle). User dropped it.
- **Lesson**: When a request would meaningfully expand the gesture surface or invalidate a flow we just shipped, naming the cost out loud is valuable. The user wasn't attached to the slider once they saw it would compete with the existing four gestures.

### Self-review surfaced real issues

- **What happened**: Ran `/review` after build; it caught the orphan catalog entries and the duplicated `MetricsChip` markup between Today and Overview — both shipped as a single follow-up commit.
- **What we did**: Applied both immediately as a `chore(today,overview):` commit, kept the perf and a11y concerns as documented follow-ups since they need their own measurement / refactor cycles.
- **Lesson**: Reviewing your own diff *before* asking for review catches the mechanical stuff that you'd otherwise burn a reviewer's attention on.

## What worked well

- **`HabitRowState` extraction.** Made the trichotomy testable in isolation — 14 tests including a Paris/DST boundary case landed before any UI existed. The view became a pure function of `(state, streak, score, callbacks)`.
- **Tight commit cadence.** Eighteen commits across the branch; every commit leaves the project compiling and tests green. Easy to bisect, easy to read, easy to skim in PR review.
- **`build_run_sim` + `screenshot` after every visual change.** Caught the negative-pill bug, validated the progress-ring rendering, confirmed the truncation behavior. Free verification.
- **Sheet enum over booleans.** `TodaySheet: Identifiable` reads far better than the alternative bool soup, and `.sheet(item:)` switches cleanly per case.
- **Asking before scope creep.** "Skip today" surfaced as an open question early, got deferred deliberately, and we never got tempted to sneak it in mid-build.

## For the next person

- **The trailing region's vocabulary is intentional**. Three icon-circle controls (binary check, counter `−/+`, timer `+5m`) plus one text pill (negative "Slipped"). The text pill is the *deliberate exception* — see the row docstring at `HabitRowView.swift:1`. Don't unify it for aesthetics.
- **`HabitRowState.resolve(...)` is the single source of truth** for "what state is this row in?" Counter `complete` means `value >= target`, not just `value > 0`. Re-use it anywhere a row's state matters; don't recompute inline.
- **Score and streak are recomputed per-row, per-render.** Inline in `TodayView.swift` and via a small `[UUID: (Int, Int)]` map in `OverviewView.swift`. With ~50 habits and growing completion histories this could measure as scroll jank. Memoize on `(habit.id, completions.count)` if it shows up.
- **`.accessibilityActions` is a workaround**, not a full a11y model. The row uses `.combine` so screen readers hear one entry per habit, then the trailing pill / stepper / chip actions get re-exposed via the Actions rotor. Apple's documented pattern for "list row with one primary + N secondary actions" is `.accessibilityElement(children: .ignore)` + `.accessibilityAction(named:)` modifiers. Worth a dedicated a11y pass.
- **`MetricsChip` is the one shared visual** between Today and Overview. If the metrics line gets a third surface (Watch, Widget), reuse it.
- **The `setCounter` "value <= 0 → delete" rule is load-bearing.** It preserves "no completion ↔ not started" as a bijection. The counter stepper's `−` is disabled at zero for the same reason. Don't add a "negative counter" without thinking through what it means for streaks and scores.
- **`+5m` for timer uses `incrementCounter(by: 300)`** because `CompletionRecord.value` carries seconds for timer habits. There's no `incrementTimerSeconds` wrapper — the call-site comment explains. Don't add the wrapper unless multiple call sites need it.

## Generalizable lessons

- **[→ CLAUDE.md]** *"Screenshot after every visual change."* Build-and-run + `screenshot` is cheap; design bugs are invisible to test_sim. Already practiced; worth codifying as a "Definition of done" addition for UI tasks.
- **[→ CLAUDE.md]** *Plan-stage "done" ≠ feature done.* Bake in a post-plan iteration loop driven by visual review. Either as a new conductor stage or as a paragraph in the build / compound docs.
- **[→ CLAUDE.md]** *Visual symmetry ≠ semantic symmetry.* When two UI elements look the same but mean different things (e.g. binary completion vs negative slip), the asymmetric treatment is correct. Document the *why* in the file docstring so future contributors don't unify them on aesthetics.
- **[→ CLAUDE.md]** *Use `.borderless` button style for tappable controls inside a `NavigationLink` row.* iOS 18+ correctly disambiguates the tap regions: button absorbs button taps, the rest of the row pushes the link. Confirmed working with multiple buttons per row across `Mark done` + stepper + chip.
- **[local]** Counter `complete` means `value >= target`, not `value > 0`. The previous semantic ("any completion = done") was wrong for partial-progress UX; HabitRowState corrects it.
- **[local]** xcstrings auto-noise (entries with `isCommentAutoGenerated`) can be carried across branches harmlessly, but should be cleaned up at the next polish pass — they accumulate.

## Metrics

- Tasks completed: 8 of 8 (plan), + 7 post-plan iterations + 1 cleanup
- Tests added: 18 (14 `HabitRowState` + 4 `setCounter`)
- Test suite: 154 → 158 (all green throughout)
- Commits: 18
- Files touched: 11 (5 new, 6 modified)
- Production lines: ~880 added, ~85 removed
- Catalog entries: +12 hand-authored, −2 orphan

## References

- iOS 18 [`Button` inside `NavigationLink`](https://developer.apple.com/documentation/swiftui/navigationlink) — confirmed disambiguation works as designed
- [`.accessibilityActions` (rotor)](https://developer.apple.com/documentation/swiftui/view/accessibilityactions(_:))
- [`Circle().trim(from:to:)`](https://developer.apple.com/documentation/swiftui/circle) — the progress-ring pattern
- Prior compound: [today-view](../today-view/compound.md) — the v0.1 row this PR redesigns; useful to see what changed and why
