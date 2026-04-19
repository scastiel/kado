# Plan — Score info popover

**Date**: 2026-04-19
**Status**: in progress
**Research**: _(skipped — feature is small, single UI surface)_

## Summary

The habit detail view shows a **Score %** that users read without
understanding what it represents or how it's computed. Add a small
explanation popover triggered by tapping the Score card in the
`metricsRow`, explaining in plain English that the score is a
recency-weighted strength indicator, not a streak. No algorithm
changes, no new tests needed — it's a pure explanatory UI affordance.

## Decisions locked in

- **Presentation**: `.popover(isPresented:)` with
  `.presentationCompactAdaptation(.popover)`, matching
  `CellPopoverContent.swift`.
- **Trigger**: whole Score card is a `Button`. Add an `info.circle`
  hint next to the "Score" label as an affordance cue.
- **Content**: 4 short bullets distilled from `docs/habit-score.md`
  — what it means, how it moves, scheduled-days-only, starts at 0.
  No Weak/Building/Strong ladder (thresholds not yet defined in spec).
- **Scope**: Score card only — Streak card stays non-interactive
  (self-evident from "current / best" formatting).
- **Localization**: EN + FR added by hand to
  `Kado/Resources/Localizable.xcstrings`. FR is native, not machine
  translation.

## Task list

### Task 1: Add `ScoreExplanationPopover` view

**Goal**: Create the popover content as its own file so it's testable
with SwiftUI previews and not entangled with `HabitDetailView`.

**Changes**:
- New `Kado/Views/HabitDetail/ScoreExplanationPopover.swift`
- Structure: `VStack(alignment: .leading, spacing: 12)` with a header
  (`Label("About this score", systemImage: "chart.line.uptrend.xyaxis")`)
  and 4 `Text` bullets, each a short paragraph.
- Width constraint: `frame(minWidth: 260, maxWidth: 320)`, like
  `CellPopoverContent`.
- Two `#Preview` blocks: light, dark.

**Tests / verification**: SwiftUI previews render at expected width
in both color schemes; Dynamic Type XXXL doesn't truncate.

**Commit message (suggested)**: `feat(habit-detail): add score explanation popover view`

---

### Task 2: Wire the popover into `HabitDetailView`

**Goal**: Make the Score card tappable and present the popover.

**Changes**:
- `Kado/Views/HabitDetail/HabitDetailView.swift`:
  - Change `metricCard(...)` signature to optionally accept a
    trailing "accessory" (the `info.circle` hint) — or extract a
    new `scoreCard` computed property so `metricCard` stays generic.
  - Wrap the Score card in a `Button { showingScoreInfo = true }`
    with `.buttonStyle(.plain)` to preserve the card chrome.
  - Add `@State private var showingScoreInfo = false`.
  - Attach `.popover(isPresented: $showingScoreInfo) { ScoreExplanationPopover().presentationCompactAdaptation(.popover) }`.
  - Add `.accessibilityHint(String(localized: "Shows how the score is calculated."))` to the button.

**Tests / verification**:
- `build_sim` on iPhone 17 Pro.
- `screenshot` confirming: (1) info hint visible next to "Score"
  label, (2) popover renders with readable content, (3) card still
  looks like the Streak card (same visual weight).
- VoiceOver: tapping the card reads "Score, <%>, button. Shows how
  the score is calculated."

**Commit message (suggested)**: `feat(habit-detail): tap score card to show explanation`

---

### Task 3: Localize strings

**Goal**: Add EN + FR entries for all new user-facing strings.

**Changes**:
- `Kado/Resources/Localizable.xcstrings`:
  - `"About this score"` — header of the popover.
  - The 4 body bullets (approximate, wordsmith in the build):
    - `"It reflects your habit's strength over time, not a streak."`
    - `"Recent days weigh more than older ones. A missed day loses about half its impact after two weeks."`
    - `"Only scheduled days count. If your habit is Mon/Wed/Fri, other days are skipped."`
    - `"It starts at 0% and climbs slowly. A young habit can read low even when you're perfect — that's intentional."`
  - Accessibility hint: `"Shows how the score is calculated."`
- Each entry gets a `comment` describing on-screen context.
- FR: native phrasing (no machine translation).

**Tests / verification**:
- Run app with device language set to French, confirm FR strings
  render.
- Dynamic Type XXXL in both languages: no truncation.

**Commit message (suggested)**: `feat(habit-detail): localize score explanation popover (en, fr)`

---

## Risks and mitigation

- **Popover adaptation on iPhone**: `.presentationCompactAdaptation(.popover)`
  is what `CellPopoverContent` uses. If rendering degrades (e.g.
  clipping), fall back to the default adaptation — which on iPhone
  becomes a sheet, acceptable.
- **Dynamic Type overflow**: 4 paragraphs at XXXL is the worst case.
  Mitigation: no fixed heights, use `.fixedSize(horizontal: false, vertical: true)` on each `Text`, rely on vertical scroll if needed.
  Quick check during Task 2's screenshot pass.
- **Button chrome swallows card look**: `.buttonStyle(.plain)` should
  preserve the background; if tap-feedback is missing, add a light
  `.opacity` on press via `ButtonStyle`. Low probability.

## Open questions

- [ ] Should the popover also open by long-press, or tap-only? Plan
  assumes tap-only (simpler, more discoverable).

## Notes during build

- **Task 3**: the project's `Localizable.xcstrings` is currently EN-only
  — FR isn't set up at the project level yet (`knownRegions` in
  `project.pbxproj` lists only `en` and `Base`, and no existing entry
  has an `fr` localization). Scoped Task 3 to EN entries. FR will be
  added as part of the separate `translations-catalog` feature when
  project-level FR support lands — new entries will be picked up then.

## Out of scope

- No changes to the score algorithm or the Streak card.
- No Weak/Building/Strong qualitative labels (spec hasn't committed
  to thresholds yet).
- No visual aid (sparkline, history curve) inside the popover — that
  would be a separate feature.
- No similar popover on the Today row's score display (if desired,
  follow-up feature).
