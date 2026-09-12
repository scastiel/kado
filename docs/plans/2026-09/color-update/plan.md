# Plan — Colour update (design handoff)

**Date**: 2026-09-12
**Status**: in progress
**Research**: [research.md](./research.md) ·
**Spec**: [handoff/README.md](./handoff/README.md)

## Summary

Re-author the eight habit hues in OKLCH at matched lightness and
chroma, derive every habit-coloured surface from that base by mixing
in Oklab over the page ground (light and dark), and move every
secondary-text role off the system grey and the tertiary ink onto
`kadoForegroundSecondary`, which already clears 4.5:1. Colours only:
no view gains, loses, moves, or resizes anything. The mockups' layout
additions and the system tab bar's selected chip are flagged, not
built.

## Decisions locked in

- The README is the spec; the mockups' layout additions (progress bar,
  summary line, legend, monograms, dot, dashed ring, FAB) are out.
- Hues are authored as `OKLCH` in `HabitColor`; tints are mixed in
  Oklab against `kadoPaper50` per scheme and handed to SwiftUI as
  opaque dynamic colours. No `.opacity()` on a habit hue anywhere.
- The three cases the README doesn't cover use the same C at spaced
  hues: yellow `0.70 0.12 95` (lifted, like orange), green
  `0.60 0.12 145`, mint `0.60 0.11 165`.
- Dark bases raise L to 0.70 (same C, H); ink-on-tint is L 0.46 light /
  L 0.78 dark.
- Glyphs on a *filled* control are `kadoBackground`, not `Color.white`
  — white is 2.5–2.8:1 on the dark bases.
- Named derivations, so views don't carry numbers: mark 16%, timer pill
  18%, counter pill and check circle 14%, slipped tag 20%, outline
  36%, tile partial 45%, tile light 20%. The Overview ramp stays
  continuous (`0.2 + 0.8·value`) — "light" and "partial" are points on
  it.
- Dark neutrals stay as they are (already within two units of the
  spec). The selected tab chip is system-drawn; flagged.
- Text: system `.secondary` → `kadoForegroundSecondary` on Today and
  Overview; `kadoEyebrow()` follows; the Overview weekday initials move
  from system `.secondary` to the warm `kadoInk300` at the same
  lightness; the Overview row name moves from `.primary` to
  `kadoForeground`.
- `.notDue` matrix tile: `.tertiarySystemFill` → `kadoHairline`, which
  the widget already uses.
- Slipped pill keeps `.bordered` / `.borderedProminent` (no resize) and
  takes the habit's hue via `.tint`; its outlined label is ink-on-tint.
  The bordered fill's alpha is the system's, so this one surface is
  "about 20%" rather than exactly 20% — flagged.
- Widgets: only `WidgetPalette`'s `.fullColor` branch changes;
  `.accented` / `.vibrant` are alpha-only and untouched.

## Task list

### Task 1: OKLCH colour math

**Goal**: `OKLCH` → `Oklab` → sRGB with gamut clipping, and an Oklab
mix, as a `nonisolated` value type in `KadoCore/Design`, tests first.

**Changes**:
- `KadoTests/OKLCHTests.swift` — known conversions (the eight bases and
  their 16 / 45% mixes, values pasted from a reference implementation,
  not hand-computed), round-trip sRGB → Oklab → sRGB within 1/255,
  clipping of an out-of-gamut input, `mix(0)` / `mix(1)` identity.
- `Packages/KadoCore/Sources/KadoCore/Design/OKLCH.swift` — `OKLCH`,
  `Oklab`, `Oklab.mixed(with:amount:)`, `Oklab.rgb` (linear → sRGB,
  clipped), a `UIColor` / `Color` bridge.

**Tests / verification**: `test_sim` green.

**Commit**: `feat(design): add OKLCH colour math for the habit palette`

---

### Task 2: Habit hues on OKLCH bases

**Goal**: `HabitColor` exposes `base`, `darkBase`, `color`, `onTint`,
`onFill`, `tint(_:)` and the `HabitTint` constants; every consumer
already renders the new base hue after this task, still with its old
`.opacity()` tints, and compiles unchanged.

**Changes**:
- `KadoTests/HabitColorTests.swift` — every case in gamut (no channel
  clipped by more than 1/255); lightness within 0.58…0.70 light and
  0.68…0.72 dark; `tint(0)` is the page, `tint(1)` is the base, and the
  ramp is monotonic in Oklab L; `onTint` ≥ 4.5:1 on `tint(.mark)` and
  `onFill` ≥ 3:1 on `color`, both schemes, all eight hues (resolve via
  `UIColor.resolvedColor(with:)`); hues pairwise ≥ 15° apart.
- `Packages/KadoCore/Sources/KadoCore/Models/HabitColor.swift`.
- `Packages/KadoCore/Sources/KadoCore/Design/HabitTint.swift` — the
  named amounts.

**Tests / verification**: `test_sim` green; `build_sim` green.

**Commit**: `feat(design): author the habit hues in OKLCH at matched lightness`

---

### Task 3: Today row through the derivations

**Goal**: the row's five habit-coloured surfaces come from `tint(_:)` /
`onTint` / `onFill`; nothing changes size.

**Changes** (`Kado/UIComponents/HabitRowView.swift`):
- Leading badge: `tint(.mark)` fill under the ring; ring
  `tint(.outline)`; icon `onTint` while open, `onFill` when complete.
- `+5m` chip: `tint(.timerPill)` / `onTint`.
- Check circle and counter `+`: `tint(.counterPill)` / `onTint`;
  filled → `color` / `onFill`.
- Count label: `color` (unchanged rule).
- Slipped pill: `.tint(habit.color.color)`; outlined label `onTint`.
- `HabitIconPicker`, `HabitColorPicker` checks: `.white` → `onFill`.

**Tests / verification**: previews (all four types, not-done /
complete, dark); `screenshot` on iPhone 17 Pro in light and dark.

**Commit**: `feat(today): derive the row's tints from the habit's OKLCH base`

---

### Task 4: Overview matrix and widgets

**Goal**: the scored ramp, off-schedule wash and border mix in Oklab;
the not-due tile is warm; the widget's full-colour branch matches.

**Changes**:
- `Packages/KadoCore/…/Views/MatrixCell.swift` — `tint(colorOpacity)`,
  `tint(offScheduleFillOpacity)`, border `tint(borderOpacity)`,
  `.notDue` → `kadoHairline`.
- `Packages/KadoCore/…/Widgets/Views/WeeklyGridLargeView.swift` — same
  three swaps.
- `Packages/KadoCore/…/Design/WidgetPalette.swift` — `.partial` →
  `tint(0.3 + 0.4p)`; complete glyph / label → `onFill`.
- `KadoTests/WidgetPaletteTests.swift` — `fullColourHabitFills` and
  `fullColourGlyphAndLabel` expect the new derivations.
- `Kado/Views/Overview/OverviewView.swift` — row name
  `kadoForeground`.
- `Kado/UIComponents/MonthlyCalendarView.swift` — `.completed` →
  `tint(0.9)`.

**Tests / verification**: `test_sim` green; `screenshot` Overview light
/ dark; widget previews in `.fullColor`; a hand check of the medium
widget under Tinted / Clear (should be unchanged — nothing in
`.accented` moved).

**Commit**: `feat(overview): mix the matrix tints in Oklab and warm the not-due tile`

---

### Task 5: Secondary-text contrast on Today and Overview

**Goal**: every body / meta / caption text on the two screens clears
4.5:1 on both grounds; only the weekday initials stay light.

**Changes**:
- `Kado/Views/Today/TodayView.swift` — section headers and footer
  `.foregroundStyle(Color.kadoForegroundSecondary)`.
- `Kado/Views/Today/TodayDayCaption.swift`,
  `Kado/Views/Overview/CellPopoverContent.swift` — `.secondary` →
  `kadoForegroundSecondary`.
- `Kado/UIComponents/DayColumnHeader.swift` — weekday letter
  `kadoForegroundTertiary`.
- `Packages/KadoCore/…/Design/KadoFont.swift` — `kadoEyebrow()` →
  `kadoForegroundSecondary`.

**Tests / verification**: sample the section header and footer cores
off a fresh `screenshot`: expect `#605B51` light / `#A9A093` dark.

**Commit**: `fix(theme): lift secondary text above 4.5:1 on paper`

---

### Task 6: the same rule on every other screen

**Goal**: the ~25 remaining `.foregroundStyle(.secondary)` /
`Color.secondary` sites (Detail, Settings, sheets, calendar) take
`kadoForegroundSecondary`, so the app has one secondary grey.

**Changes**: `HabitDetailView`, `CompletionHistoryList`,
`DayEditPopover`, `ScoreExplanationSheet`, `MonthlyCalendarView`,
`WeekdayPicker`, `CounterQuickLogView`, `DevModeSection`,
`NotificationsSection`, `BackupSection`, `SyncStatusSection`
(`.orange` warning glyph stays — it is a status colour, not a habit
hue).

**Tests / verification**: `build_sim`; spot-check Settings and Detail in
light and dark.

**Commit**: `fix(theme): use the paper secondary grey on every screen`

---

### Task 7: the streak flame

**Goal**: `MetricsChip`'s flame and the widget's `streakAccent` use the
palette's orange base instead of system `.orange`.

**Changes**: `Kado/UIComponents/MetricsChip.swift`,
`WidgetPalette.streakAccent`, `WidgetPaletteTests.streakAccentFoldsIntoSecondary`.

**Commit**: `feat(theme): draw the streak flame in the palette's orange`

---

### Task 8: Verify, compound, PR

- `build_sim` iPhone 17 Pro and iPad Air (M4); `test_sim`.
- `screenshot` Today and Overview, light and dark, iPhone; Dynamic Type
  XXXL once.
- Home Screen widget under Clear / Tinted by hand (no change expected).
- `compound.md`; PR `feat(theme): author the habit hues in OKLCH and lift secondary-text contrast`.

## Risks and mitigation

- **Colour identity in tests.** `WidgetPaletteTests` compare `Color`
  values by `==`; a dynamic `UIColor`-backed `Color` compares by
  provider identity, so the palette must vend the *same* `Color`
  instance for the same (hue, amount) — cache the derived colours in a
  static table rather than building them per call.
- **Perceived weight shift.** The new bases are noticeably calmer than
  system hues; the Overview reads lighter overall. That is the point of
  goal 1, but the "no habit dominates" check is by eye — take the
  screenshots.
- **Yellow.** Even lifted, it is the weakest hue under a cream glyph
  (2.7:1 in light). The state is also carried by fill-vs-outline; noted
  in compound, revisit if a user reports it.
- **Widget `.accented` regressions.** None expected — no alpha changes —
  but the CLAUDE.md rule stands: verify on the Home Screen, `test_sim`
  cannot see it.
- **Screenshots and the site.** Every listing capture changes colour.
  Not this PR: run `make screenshots` afterwards and push the listing
  as its own change.

## Open questions

Resolved 2026-09-12, all three the recommended way:

- [x] Streak flame → the palette's orange base (Task 7 is in).
- [x] Missed tile keeps the 20% hue per the README's derivation table.
- [x] `.secondary` is swept on every screen (Task 6 is in).

## Out of scope

- Everything the mockups add structurally: progress bar and "3 of 5
  done", Overview summary line, legend row, letter monograms, the 9pt
  dot, the dashed not-scheduled ring, the bottom-right FAB.
- The selected tab chip in dark — system Liquid Glass, not reachable
  from `UITabBarAppearance` on iOS 26.
- Dark neutrals (`#141210` / `#1E1B17`) — already there.
- Sage brand accent — "unchanged" in the README.
- Re-shooting the App Store listing and marketing site.
