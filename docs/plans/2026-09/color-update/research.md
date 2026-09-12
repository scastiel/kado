# Research — Colour update (design handoff)

**Date**: 2026-09-12
**Status**: complete
**Input**: [`handoff/README.md`](./handoff/README.md) — "Kado — color update
only", with two mockups and two before-captures.

## The ask

A colours-only pass with two goals: stop the warm paper / ink / sage
brand and the full-chroma system habit hues reading as two different
apps, and lift secondary text above 4.5:1. The handoff is explicit that
nothing moves, resizes, or restructures — "if a change appears to
require moving, resizing, or restructuring anything, it is out of
scope — leave it and flag it".

The mockups (`handoff/mockups/`) go further than the README: they add a
progress bar and "3 of 5 done" label, a summary line under Overview,
letter monograms in place of SF Symbols, a 9pt dot in place of the
Overview icon, a legend row, a dashed ring on not-scheduled rows, and a
bottom-right FAB. **The README is the spec; the mockups are the
designer's own rendition.** Everything in that list is a layout change
and stays out.

## What the handoff measured vs. what the code has

The README's "old" hex values were sampled from anti-aliased text in
the before-captures, so they don't match the tokens one-for-one.
Sampling the *cores* of the same glyphs (`magick … txt:`) tells the
real story:

| Surface (light) | Sampled | Token | Verdict |
|---|---|---|---|
| Page | `#FBF8F2` | `kadoPaper50` | matches "unchanged" |
| Card | `#F4EFE6` | `kadoPaper100` | matches "unchanged" |
| Title | `#1B1A17` | `kadoInk900` | matches "unchanged" |
| Row meta `43%` | `#605B51` | `kadoInk500` = `kadoForegroundSecondary` | **already the target** (6.4:1 page / 5.9:1 card) |
| "Scheduled" header, footer caption | `#888789` | system `.secondary` composited on cream | **the bug** — cool grey, 3.4:1 |
| Overview row name | `#000000` | SwiftUI `.primary` | should be `kadoForeground` |
| Overview weekday initial | — | system `.secondary` | README keeps it light; move to the warm `kadoInk300` |

So goal 2 is a *role remap*, not a ramp change — exactly what the
README says under "The neutral ramp itself is fine". Contrast of the
existing tokens (WCAG, nominal):

| Token | on page | on card |
|---|---|---|
| `kadoInk500` (secondary) | 6.36:1 | 5.89:1 |
| `kadoInk300` (tertiary) | 3.25:1 | 3.00:1 |
| system `.secondary` | 3.37:1 | 3.12:1 |
| `kadoInk500` dark | 7.20:1 | 6.73:1 |

`kadoEyebrow()` (`KadoFont.swift`) draws section-style micro-labels in
`kadoForegroundTertiary`; the README moves section labels to the
darker grey, so the helper moves with them.

### Dark mode is already warm

The README says the dark ground is "pure black". It is not:
`docs/screenshots/…/07-today-dark.png` samples the ground at `#14130F`
and the card at `#1C1A16`, against the spec's `#141210` / `#1E1B17` —
within two units. Nothing to change in the dark neutrals. What *does*
change in dark is the habit hues (raise L) and, per the README, the
selected tab chip — but the chip is the system's Liquid Glass tab bar
(`#43413B` on `#22201B` in dark vs `#EDEBE4` on `#FFFDF7` in light) and
`UITabBarAppearance` doesn't reach it on iOS 26. Flagged, not fought.

## Habit hues: what the spec produces

`HabitColor` is eight cases mapped to `Color.red` … `Color.purple`
(system hues). The README gives OKLCH bases for the five hues in the
sample data and says new hues should be generated on the same L / C.
Converting (script in the job's tmp; the same math will live in Swift):

| Case | OKLCH (light) | sRGB | ink-on-tint (L 0.46) | white on base | 
|---|---|---|---|---|
| red | 0.60 0.14 30 | `#C65B4C` | `#973023` | 4.2:1 |
| orange | 0.64 0.12 65 | `#BE7B32` | `#844600` | 3.5:1 |
| yellow *(new)* | 0.70 0.12 95 | `#B69D3A` | `#6D5500` | 2.7:1 |
| green *(new)* | 0.60 0.12 145 | `#4D9351` | `#226929` | 3.7:1 |
| mint *(new)* | 0.60 0.11 165 | `#2D9570` | `#006A48` | 3.7:1 |
| teal | 0.58 0.11 180 | `#008F7D` (clips slightly) | `#006B5A` | 4.0:1 |
| blue | 0.58 0.12 250 | `#3C7EBE` | `#125A98` | 4.3:1 |
| purple | 0.58 0.14 305 | `#8E62BC` | `#6B3E95` | 4.5:1 |

Two things fall out of the numbers:

1. **Ink-on-tint works.** At L 0.46 every hue clears 5.1–5.9:1 on its
   own 16% mark — the README's derivation holds.
2. **White on the filled control does not, in dark.** In light the
   bases sit at 2.7–4.5:1 under white (fine for a bold 28pt glyph
   whose state is also carried by fill-vs-outline; yellow is the weak
   one). In dark, with L raised to 0.70 as the README asks, white
   drops to **2.5–2.8:1** while the dark ground reaches 7.4–8.3:1. The
   glyph on a filled control should therefore be the page colour
   (`kadoBackground`), which is cream in light and the warm dark in
   dark — not `Color.white`.

Yellow is lifted to L 0.70 the same way the README lifts orange to
0.64: at 0.58 it is olive. Teal at C 0.11 is a hair outside sRGB at
h 180; the conversion clips it, as `color-mix` would.

### Where the hue is consumed

Every site reads `HabitColor.color` and derives tints with
`.opacity(x)` — sRGB compositing, which the README calls out as
muddying mid tints:

- `Kado/UIComponents/HabitRowView.swift` — badge fill/ring/icon, `+5m`
  chip, check circle, counter `+`, count label; the Slipped pill is
  `.tint(.red)` regardless of the habit.
- `Packages/KadoCore/…/Views/MatrixCell.swift` and
  `Widgets/Views/WeeklyGridLargeView.swift` — the scored ramp
  (`DayCell.colorOpacity`, 0.2 → 1.0), off-schedule border and wash;
  `.notDue` is `.tertiarySystemFill` (cool) in the app but
  `kadoHairline` (warm) in the widget.
- `Packages/KadoCore/…/Design/WidgetPalette.swift` — `.fullColor`
  branch: complete = base, partial = `opacity(0.3 + 0.4p)`, glyph and
  label knock out to `.white`. `.accented` is alpha-only and untouched.
- `Kado/Views/Overview/OverviewView.swift`, `MatrixRowView`,
  `CellPopoverContent`, `DayEditPopover`, `HabitColorPicker`,
  `HabitIconPicker`, `MonthlyCalendarView` — icon or swatch in the
  base; picker checks in `.white`.
- `MetricsChip` — the streak flame is system `.orange`, deliberately
  off-palette ("means streak regardless of the habit"). It is the last
  full-chroma system colour on the two screens.

`ConfettiView` already draws in sage and paper (#86) — nothing to do.

## Mixing in a perceptual space on iOS

SwiftUI has no `color-mix(in oklab)`. `Color.opacity` composites in the
working space (gamma-encoded), which is the sRGB mixing the README
warns about. The alternative is cheap: author each hue as OKLCH, mix in
Oklab against the page ground, convert to sRGB, and hand SwiftUI an
*opaque* dynamic `UIColor` — one for light, one for dark — through the
`Color(light:dark:)` initialiser `Theme.swift` already uses. The
matrices are Björn Ottosson's published ones; ~150 conversions at
static-init time, no runtime cost per frame.

Opaque tints are also what the README literally specifies ("X% over
page" = mix with `#FAF6EE`). A mark on the card is mixed over the page
rather than the card; at 16% the difference is a unit or two.

## Sketch

- `Packages/KadoCore/Sources/KadoCore/Design/OKLCH.swift` — `OKLCH`
  and `Oklab` value types, `mix`, sRGB conversion with gamut clip.
- `HabitColor` gains `base` (light) / `darkBase` (L 0.70), and derives
  `color`, `onTint`, `onFill`, `tint(_ amount:)`; a `HabitTint` enum
  names the README's surfaces (`mark` 0.16, `timerPill` 0.18,
  `counterPill` 0.14, `slippedTag` 0.20, `outline` 0.36,
  `tilePartial` 0.45, `tileLight` 0.20).
- Views swap `.color.opacity(x)` for `.tint(x)` and `Color.white` for
  `Color.kadoBackground` on filled controls.
- Text roles: system `.secondary` → `kadoForegroundSecondary`;
  `kadoEyebrow()` → secondary; weekday initials → `kadoInk300`.

## Open questions

- [ ] Streak flame: keep system `.orange`, or move it to the palette's
      orange base so it sits in the warm world? (The README doesn't
      mention it; goal 1 argues for the swap.)
- [ ] Missed tile: the README's derivation table keeps a 20% "light"
      tile and the app has a documented reason for it
      (`DayCell.colorOpacity`'s floor); the mockup's legend shows
      "Missed" as neutral `#E7E1D4` instead. Keep the hue, or go
      neutral?
- [ ] The `.secondary` → `kadoForegroundSecondary` swap is the same
      rule everywhere; ~25 sites sit outside Today / Overview (Detail,
      Settings, sheets). Sweep them in this PR, or stop at the two
      screens the handoff covers?
