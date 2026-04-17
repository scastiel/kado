# Compound — Dark mode (v0.1)

**Date**: 2026-04-17
**Status**: complete
**Research**: [research.md](./research.md)
**Plan**: [plan.md](./plan.md)
**Branch / PR**: [kado#8](https://github.com/scastiel/kado/pull/8)

## Summary

Delivered the v0.1 "Full dark mode" roadmap item as a
validation-and-fix pass: 11 dark-scheme previews added, simulator
audit on iPhone 17 Pro + iPad Air 11" completed, zero production-code
fixes required. The headline lesson is that v0.1's disciplined use of
semantic colors from day one let us "ship" dark mode without writing
a single adaptive line — the feature was already done, we just had to
prove it.

## Decisions made

- **Validation-and-fix scope, not redesign**: the roadmap's "Full dark
  mode" line was intentionally read as the minimal-honest
  interpretation. Anything bigger (themes, toggle, accent redesign)
  got explicitly pushed to v1.0.
- **No user-facing theme toggle**: deferred to v1.0, matching the
  existing `SettingsView` placeholder comment.
- **Stay on system blue accent**: `AccentColor.colorset` stays empty;
  system blue already has light/dark variants. Brand accent is a
  separate visual-identity task.
- **One dark preview per view file** (not per existing named preview):
  keeps the Xcode canvas skimmable while still giving regression
  surface.
- **Demanding states over representative states**: after review
  pushback, `CounterQuickLogView` dark shows at-target (accent numeral
  on dark), and `HabitDetailView` dark uses the counter variant (so
  the quick-log renders inside the detail layout).
- **The two `Color.white` sites are not bugs**: white-on-accent is
  legitimate; research correctly reframed the survey's false-positive
  flag.
- **Screenshots live in the PR, not the repo**: avoids binary bloat;
  PR attachments fill the visual-record role.

## Surprises and how we handled them

### XcodeBuildMCP has no tap/type primitives in this config

- **What happened**: the build plan assumed a full-navigation sim
  audit (Today → Detail → New Habit → Timer sheet → Settings). When
  `build_run_sim` succeeded and Today showed, there was no tool to
  tap the habit row and push into Detail.
- **What we did**: pivoted the audit to "single-screen sim + dark
  previews + code inspection." Validated everything reachable on
  Today (populated, empty, XXXL, Increase Contrast, iPad width) and
  relied on the dark previews for the rest. Documented the gap in
  the audit findings so the reviewer could decide whether coverage
  was sufficient.
- **Lesson**: don't assume navigation primitives are wired just
  because the build/run tools are. Same limitation was flagged in
  [kado#5](https://github.com/scastiel/kado/pull/5) compound — this
  is now the second session where it bit. Worth promoting to CLAUDE.md.

### Device substitution

- **What happened**: iPhone 16 Pro and iPad Air (M2) — the project's
  default sim targets from CLAUDE.md — weren't installed on the
  audit machine. Only iPhone 17 Pro and iPad Air 11" (M4) were.
- **What we did**: substituted directly; the substitution doesn't
  affect dark-mode behavior (same layout class, same system color
  surface). Flagged the substitution in audit findings and plan body.
- **Lesson**: CLAUDE.md's "boot and use iPhone 16 Pro as default"
  assumes the author's machine — Claude sessions running on a fresh
  machine or a different developer's machine can hit this. The
  substitution is cheap and low-risk; worth a CLAUDE.md note that
  substituting a +1 generation is acceptable.

### Subagent falsely flagged `Color.white` as bugs

- **What happened**: the initial codebase survey agent reported both
  `Color.white` literals as "BREAKS in dark mode." Reading the
  sites in context showed they were white-on-accent, a fine pattern.
- **What we did**: re-read both sites in-context before drafting
  research, corrected the framing in the research doc, and saved the
  time that would've been spent "fixing" non-bugs.
- **Lesson**: subagents report mechanical findings (text matches),
  not contextual findings (does this break?). Always read the flagged
  lines before taking them as gospel.

## What worked well

- **Conductor skill structure**: research → plan → build → compound
  gave four visible checkpoints for a small feature. The two open
  questions carried from research to plan to build got closed
  naturally (depth treatment wasn't needed; screenshot storage
  decided). Worth the ceremony even for a "trivial" validation pass.
- **Dark preview per file, not per preview**: 11 new previews total.
  Doubling the canvas (one dark per every existing named preview)
  would've added no regression signal — the dark version of "Empty"
  and "Populated" both tell you the same thing.
- **Explicit scope conversation up front**: asking three scoping
  questions before drafting research ("what does 'full dark mode'
  mean? toggle? custom accent?") let the user redirect in one
  exchange instead of after a 300-line draft.
- **Honest findings note over papered-over gaps**: the "reachable
  surface vs unreachable surface" table in the audit findings is
  uncomfortable but accurate. Better than claiming full coverage.

## For the next person

- **Unreachable surface is still unverified end-to-end in dark**.
  Habit Detail, New Habit, Timer log, Monthly calendar at mixed
  states, History list, and Settings were validated only via dark
  previews + code inspection + author dogfooding. If something breaks
  visually on one of these, it landed here.
- **`#Preview("Dark")` is the last preview in each view file**.
  Convention established in this PR. Keep the naming: `"Dark"`,
  nothing longer.
- **Dark previews use demanding states**, not neutral ones. When
  adding new views, pick a state that actually stresses
  accent-on-dark contrast or cell-state opacity — not a placeholder.
- **`AccentColor.colorset` is intentionally empty**. System blue is
  in play. When you fill it (v1.0 visual-identity pass), contrast-
  check `Color.white`-on-`accent` in `WeekdayPicker:33` and
  `MonthlyCalendarView:171` before shipping — those are the only two
  hardcoded-white sites and they assume a dark enough accent.

## Generalizable lessons

- **[→ CLAUDE.md]** Prefer semantic colors from day one. Kadō hit
  ~95% auto-adaptive without writing a line of dark-mode code because
  the convention was in place before the screens existed. Candidate
  addition to the "SwiftUI" section: *"Prefer semantic system colors
  (`Color.primary`, `Color(.secondarySystemBackground)`, …) over
  hardcoded literals. `Color.white` is acceptable only as text on an
  accent-tinted fill; anything else should adapt."*
- **[→ CLAUDE.md]** XcodeBuildMCP's tap/type/gesture primitives are
  **not enabled in the default install**. Sessions that need
  navigation-driven sim audits hit this wall. Candidate addition to
  the Tooling/XcodeBuildMCP section: *"Only simulator build/run and
  screenshot are enabled by default. Multi-screen sim audits need
  `idb`, Simulator.app hands-on, or an explicit MCP reconfigure."*
- **[→ CLAUDE.md]** Subagent codebase surveys report mechanical
  findings, not contextual ones. Always read flagged lines in-context
  before committing to a fix. Candidate note, but may be too
  meta-workflow-y for CLAUDE.md — keep as a compound-only lesson
  unless this pattern recurs.
- **[local]** If/when a non-blue brand accent ships, re-verify
  `WeekdayPicker:33` and `MonthlyCalendarView:171` contrast.

## Metrics

- Tasks completed: 5 of 6 (Task 6 skipped — no fixes surfaced)
- Tests added: 0 (dark mode is visual; 11 SwiftUI previews instead)
- Commits: 5
- Files touched: 11 Swift + 3 docs
- Lines changed: ~110 Swift + ~450 docs

## References

- [Apple HIG — Dark Mode](https://developer.apple.com/design/human-interface-guidelines/dark-mode)
- [kado#5 compound](https://github.com/scastiel/kado/pull/5) — prior
  session that first flagged the XcodeBuildMCP tap-primitive gap
- [ROADMAP.md v0.1 + v1.0 theming entries](../../../ROADMAP.md)
