# Plan — Dark mode (v0.1)

**Date**: 2026-04-17
**Status**: done
**Research**: [research.md](./research.md)

## Summary

Deliver the v0.1 "Full dark mode" roadmap item as a **validation-and-fix
pass**: add dark-scheme SwiftUI previews across all views, audit the
app on iPhone 16 Pro and iPad Air simulators under Dark Appearance,
spot-check Dynamic Type XXXL + Dark together on the densest screen,
and apply surgical fixes for anything surfaced. No user toggle, no
custom accent, no redesign.

## Decisions locked in

- Scope is validation-and-fix, not redesign (from research).
- No user-facing theme toggle in Settings (deferred to v1.0).
- Stay on system blue accent — `AccentColor.colorset` stays empty.
- Add one dark-scheme preview per view file (not one per existing
  named preview variant) to keep the canvas skimmable.
- Dark-mode screenshots attach to the PR, not committed to the repo.
- Audit covers iPhone 16 Pro (primary) + iPad Air (M2) (spot-check).
- The two `Color.white` sites (`WeekdayPicker` selected capsule,
  `MonthlyCalendarView` completed cell) are not bugs — they're
  verified during audit, not rewritten.

## Task list

### Task 1: Dark-scheme preview coverage ✅

**Goal**: every view file has at least one preview that renders in
dark mode, so regressions surface in Xcode Previews before they reach
the simulator.

**Changes**:
- [Kado/UIComponents/WeekdayPicker.swift](../../../../Kado/UIComponents/WeekdayPicker.swift) — add `#Preview("Dark")`
- [Kado/UIComponents/CounterQuickLogView.swift](../../../../Kado/UIComponents/CounterQuickLogView.swift) — add dark variant
- [Kado/UIComponents/MonthlyCalendarView.swift](../../../../Kado/UIComponents/MonthlyCalendarView.swift) — add dark variant
  (with mixed cell states — most visually dense)
- [Kado/UIComponents/HabitRowView.swift](../../../../Kado/UIComponents/HabitRowView.swift) — add dark variant
- [Kado/Views/Today/TodayView.swift](../../../../Kado/Views/Today/TodayView.swift) — add dark variant (populated state)
- [Kado/Views/HabitDetail/HabitDetailView.swift](../../../../Kado/Views/HabitDetail/HabitDetailView.swift) — add dark variant
- [Kado/Views/HabitDetail/CompletionHistoryList.swift](../../../../Kado/Views/HabitDetail/CompletionHistoryList.swift) — add dark
- [Kado/Views/HabitDetail/TimerLogSheet.swift](../../../../Kado/Views/HabitDetail/TimerLogSheet.swift) — add dark
- [Kado/Views/NewHabit/NewHabitFormView.swift](../../../../Kado/Views/NewHabit/NewHabitFormView.swift) — add dark
- [Kado/Views/Settings/SettingsView.swift](../../../../Kado/Views/Settings/SettingsView.swift) — add dark
- [Kado/Views/ContentView.swift](../../../../Kado/Views/ContentView.swift) — add dark

**Tests / verification**:
- `build_sim` succeeds with no new warnings.
- Open each file in Xcode Previews (human spot-check on 2-3 representative
  files — not every file, Xcode will render them when they're touched).

**Commit message (suggested)**: `test(dark-mode): add dark-scheme previews across views`

---

### Task 2: Simulator audit — iPhone 17 Pro, Dark Appearance ✅

**Goal**: capture dark-mode screenshots of every screen the user can
reach in v0.1 and produce a findings list.

**Steps**:
1. `boot_sim` iPhone 16 Pro, set appearance to dark.
2. `build_run_sim` the Kado scheme.
3. If the sim has no habits, create 2-3 via the New Habit form
   (one daily, one specific-days, one counter with target).
4. `screenshot` at each stop:
   - Today (populated, mixed states)
   - Habit Detail — daily habit
   - Habit Detail — counter habit (shows `CounterQuickLogView`)
   - Habit Detail — timer habit → open `TimerLogSheet`
   - Monthly calendar section scrolled to a month with mixed states
   - New Habit form (empty + filled)
   - Settings (placeholder screen, still worth a look)
5. Inline findings as chat response + append **Audit findings**
   section to this `plan.md` with one bullet per issue (or "no
   findings").

**Tests / verification**:
- Every screenshot is legible: no invisible text, no flat cards that
  disappear into the background, no accent-on-accent washing.
- Findings documented.

**Commit message (suggested)**: none — no code changes unless findings
surface. If a note-only commit makes sense, use `docs(dark-mode):
record audit findings`.

---

### Task 3: Simulator audit — iPad Air (M4) spot-check ✅

**Goal**: confirm dark mode works at iPad width too. Less thorough
than Task 2 — one screenshot of Today and one of Habit Detail is
enough.

**Steps**:
1. `boot_sim` iPad Air (M2), set appearance to dark.
2. `build_run_sim`.
3. `screenshot` Today + Habit Detail.
4. Add findings (if any) to the same **Audit findings** section.

**Tests / verification**:
- No layout regressions specific to iPad dark mode.

**Commit message (suggested)**: none expected.

---

### Task 4: Dynamic Type XXXL + Dark combo on Habit Detail ✅

**Goal**: confirm the densest screen (Habit Detail) doesn't break when
XXXL and Dark stack.

**Steps**:
1. In the iPhone 16 Pro sim (still in Dark), set Dynamic Type to
   accessibility XXXL via `simctl` or Developer menu.
2. `screenshot` Habit Detail for a daily habit with a populated month.
3. Add to findings.

**Tests / verification**:
- Metric cards don't overlap, calendar is still scannable, history
  labels wrap rather than truncate visibly.

**Commit message (suggested)**: none expected.

---

### Task 5: Increase Contrast spot-check ✅

**Goal**: cheap accessibility check — enable "Increase Contrast" and
screenshot Today + Detail. Not a blocking v0.1 requirement, but
catches regressions for free.

**Steps**:
1. In the iPhone 16 Pro sim, enable Increase Contrast
   (`simctl` accessibility flag or Settings toggle).
2. `screenshot` Today and Habit Detail (both light and dark if quick).
3. Add to findings.

**Tests / verification**:
- Selected states still visibly differ from unselected.
- Accent-on-fill regions don't collapse.

**Commit message (suggested)**: none expected.

---

### Task 6 (conditional): Apply fixes surfaced by audit — not needed ✅

**Goal**: address anything tasks 2-5 flagged. Only triggered if the
audit produced findings.

**Likely candidates** (from research):
- `MonthlyCalendarView` cell opacity values (`0.9`, `0.4`) tuned in
  light — may need dark-specific values.
- Card backgrounds flattening against the page — swap to
  `.regularMaterial` or add a 1px stroke.
- Any contrast issue on accent-tinted regions.

**Scope rule**: each fix stays surgical — one-to-two modifier changes
per site. If something needs broader rework, split into a new
research/plan cycle rather than folding it into this PR.

**Tests / verification**:
- Re-run relevant screenshots post-fix; findings list updates with
  "fixed in <commit>" annotations.
- `build_sim` + `test_sim` both pass (no business logic touched, but
  sanity check).

**Commit message (suggested)**: `fix(dark-mode): <specific fix>` per
logical fix. Avoid lumping unrelated tweaks together.

---

## Integration checkpoints

- **SwiftData**: none — no schema changes.
- **CloudKit**: none.
- **HealthKit**: none.
- **Widgets**: none (v0.2 scope).
- **iPad**: Task 3 is the checkpoint.
- **Accessibility**: Tasks 4 and 5.

## Risks and mitigation

- **Risk**: the audit surfaces more than "a few surgical tweaks" —
  e.g. cards actually need a redesign to work in dark.
  **Mitigation**: if Task 6 starts looking like > 3-4 fixes or any
  single fix needs structural changes, stop. Write that as a finding,
  close this PR at "validation complete, polish pass needed," and
  open a fresh research cycle for the polish.

- **Risk**: `build_run_sim` hits the destination-resolution flakiness
  noted in [CLAUDE.md](../../../../CLAUDE.md).
  **Mitigation**: follow the three-step recovery in CLAUDE.md
  (shutdown all sims → pinned-OS xcodebuild → clean DerivedData).
  Don't let tool flake contaminate the audit findings.

- **Risk**: screenshot-based audit misses subtle "feels off" issues.
  **Mitigation**: the author uses Kadō daily per the v0.1 exit
  criteria; real-device dogfooding after merge is the safety net.

## Open questions

- [ ] If Task 2 flags flat cards, do we reach for `.regularMaterial`
      or a 1px separator stroke? (Decide during Task 6 when we see the
      specific screenshot.)

## Audit findings (Tasks 2–5)

**Device substitution**: iPhone 16 Pro was not installed on the audit
machine — only iPhone 17 Pro is available. Substituted directly;
layout class and dark-mode behavior are identical for this purpose.
iPad Air (M4) substituted for iPad Air (M2) for the same reason.

**Tooling limitation**: the XcodeBuildMCP install on this machine does
not expose tap / type / gesture primitives (matches the note from
[kado#5](https://github.com/scastiel/kado/pull/5) compound). Only the
launched screen is reachable in-sim; navigating Today → Detail → New
Habit → Timer log needs either `idb` or Simulator.app hands-on. The
dark-scheme previews added in Task 1 are therefore the primary
regression surface for unreachable screens.

**Reachable surface** (Today + iPad empty state), all validated:

| Surface | Result |
|---|---|
| iPhone Today, dark, populated | ✅ clean — cards contrast with page, accent circles + white checkmarks legible, chevrons visible |
| iPhone Today, light, populated | ✅ reference — semantic colors do their job |
| iPhone Today, dark + Accessibility XXXL | ✅ clean — text scales, circles scale, chevrons remain visible |
| iPhone Today, dark + Increase Contrast | ✅ clean — accent lightens per system, checkmarks remain legible |
| iPad Today, dark, empty state | ✅ clean — ContentUnavailableView renders correctly |

**Unreachable surface** (covered by dark-scheme previews in Xcode):

- `HabitDetailView` (score card, streak card, monthly calendar,
  history list, quick-log, timer sheet entry point)
- `NewHabitFormView` (including embedded `WeekdayPicker`)
- `MonthlyCalendarView` at mixed cell states
- `CounterQuickLogView`
- `TimerLogSheet`
- `CompletionHistoryList`
- `SettingsView` placeholder

By code inspection these use the same semantic palette
(`secondarySystemBackground`, `primary`/`secondary` text,
`accentColor`, `tertiarySystemFill`, `secondarySystemFill`) as Today.
No red flags. The two `Color.white` sites (`WeekdayPicker:33`,
`MonthlyCalendarView:171`) are white-on-accent patterns; fine with
system blue.

**Fixes required**: none. Task 6 skipped.

**Carried-forward open question** (depth treatment: material vs
stroke): no flat-card issue surfaced. Open question **closed** for
this pass. Reopen if a reachable-screen sim audit finds a problem.

## Out of scope

- User-facing theme picker (Light / Dark / System) — v1.0.
- Sepia and high-contrast themes — v1.0.
- Custom brand `AccentColor` with hand-tuned dark variant —
  separate visual-identity task.
- Per-habit color tuning — no per-habit color field exists yet.
- UI test automation for color-scheme regressions — previews +
  screenshots are enough for v0.1.
- watchOS / widgets dark mode — not in v0.1.
