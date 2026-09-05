# Today & Overview redesign

Implements the external design handoff in [`handoff.md`](handoff.md). Mockups: [`mock-today.png`](mock-today.png), [`mock-overview.png`](mock-overview.png). Before/after: [`before-today.png`](before-today.png) → [`after-today.png`](after-today.png), [`before-overview.png`](before-overview.png) → [`after-overview.png`](after-overview.png).

## What the handoff was fixing

Four defects in the shipping build, all of them things that compile fine and pass the unit suite:

- Today rows carried four control vocabularies at three heights, plus a chevron duplicating the row's own tap target. No two rows lined up.
- `Slipped` occupied the action slot, so a slipped habit had no way to be logged.
- An unexplained `43%` on every row read as "43% done today" when it is the habit's strength.
- The Overview grid alternated light and full-saturation tiles with no key, and sized its date header separately from its tiles so the two drifted out of alignment.

## Approach

### Palette

Habit hues are now declared in OKLCH (`OKLCH.swift`) instead of mapped onto Apple's system colors, and resolved at three lightnesses: the base, a darker `ink` for anything drawn *on* a tint, and a dark-mode lift. System hues share neither lightness nor chroma — system yellow is far lighter than system purple — so a card of habit marks drawn from them reads as unrelated intensities fighting the cream ground. Holding L and C fixed and varying only hue is what makes the two screens read as one palette.

Derivations are arithmetic rather than a second table of hand-picked hexes: "icon color is the habit hue at L 0.46" is `base.lightness(0.46)`. Tint opacities live in `KadoTint` so the same fill can't drift between the Today mark and the Overview ramp.

### Tokens

The handoff's neutrals were within ~1% of the existing `kadoPaper*` / `kadoInk*` values, so those are reused per its own instruction to prefer an existing token and note the discrepancy. Genuinely new:

- `kadoBrandSolid` / `kadoOnBrandSolid` — the progress bar and add button. Deliberately not `kadoAccent`, which lightens in dark mode and would fail contrast under a white glyph.
- `kadoTileMissed` / `kadoTileOffSchedule` / `kadoTileOffScheduleRing`.

### Today

`List` → `ScrollView` of `HabitCard`s. The design's grouped card (22pt corners, a hairline inset to the text column, 13pt row padding) is not reachable through `List`'s row and separator insets, and every approximation fought the platform.

What `List` was giving us in return was drag-to-reorder and swipe-to-undo. Reordering moved to the row context menu (`Move up` / `Move down`, confined to the row's own section since the sections are derived from the schedule, not from `sortOrder`). Swipe-to-undo was already redundant with the row control, which toggles in both directions.

The row caption (`TodayRowMeta`) is a strict priority, not a concatenation: next-due date → slip → today's counter/timer progress → streak, then always the score. It truncates rather than wraps, because equal row heights are the whole point of the row system.

### Overview

Ten columns fill the width; `columnWidth` is derived once from the viewport and used by the header *and* the tiles, in the same container with the same spacing, so alignment is structural rather than maintained by hand. Thirty days of history remain, a horizontal drag away.

The left-edge clipping needed a specific fix: padding applied *inside* the scroll view (or via `safeAreaPadding`) leaves the viewport full-width, so content keeps drawing to the screen edge and a half-column bleeds past the margin. Padding the scroll view itself narrows the viewport to exactly ten columns and nine gaps, so the grid lands on whole columns at rest.

The tile ramp went from a continuous `0.2...1.0` opacity to four discrete states. The old ramp's 0.2 floor forced missed days to be drawn in the habit's own hue, which made "scheduled and skipped" and "barely started" the same picture — the two states a grid most needs to separate.

## Deviations from the handoff

| Handoff | What shipped | Why |
|---|---|---|
| Custom floating pill tab bar with an `#E7E1D4` selection chip | Native `TabView`, untouched | iOS 26 already renders the tab bar as a floating pill. A hand-rolled one loses tab minimize-on-scroll, the accessibility tree, and iPad adaptation. **The light/dark selection mismatch the handoff flags is a system treatment, not ours** — worth a separate look. |
| Playfair Display 500 | Fraunces (bundled) | The handoff sanctions substituting the app's existing display serif. |
| Slipped row keeps the empty circle | Same | Follows the mock literally. Note the consequence: tapping it when already slipped un-slips, with no visual difference in the control. The tag is the only state indicator. Worth watching. |
| 5 habit hues | All 8 `HabitColor` cases | The palette is persistence surface; every case needs a value. Yellow/green/mint/teal interpolate the handoff's five on the same L/C. |
| Tile ramp has no off-schedule state | Off-schedule kept as pale fill + full-hue ring | The handoff's vocabulary has no way to say "logged on a day nothing was asked" — dropping it would regress issue #57. |

## Verification

- `make build` — clean, zero warnings.
- `make test` — 545 tests in 56 suites pass.
- Screenshots in this directory, both screens in both appearances, from the seeded demo dataset.

New tests: `OKLCHTests` (conversion, gamut clamping, lightness derivation), `HabitColorTests` palette invariants (matched lightness, muted chroma, distinct hues, in-gamut), `NextDueDateTests` (per frequency, archived, horizon, a DST-at-midnight sweep), `TodayRowMetaTests` (caption priority), `OverviewMatrixTests` (discrete ramp, monotonicity, summary counts).

## Next steps

- **The Overview cell popover and the widget grid still use the old continuous ramp.** The widget mirrors `DayCell` through `WidgetDayCell`, which kept its own opacity accessors — so the widget's hues changed with the palette but its intensity encoding did not. Worth aligning.
- The `SLIPPED` tag is covered by a SwiftUI preview but not by a simulator screenshot: the seeded dataset has no slip today, and this project has no tap primitives to create one (CLAUDE.md, XcodeBuildMCP limitations).
- No schema change, so no CloudKit console deploy is needed.
