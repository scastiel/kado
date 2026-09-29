# Compound — Paid habit palettes (#113)

**Date**: 2026-09-28
**Status**: complete, pending the hand checks below
**Issue**: #113 (part of #110; stacked on #115 theme system and #116 Supporter pack)
**Branch**: `feature/habit-palettes` — captures in [`screenshots/`](./screenshots/)

## Summary

Four Supporter-pack themes — **Muted**, **Vivid**, **Autumn** and
**Monochrome sage** — authored as OKLCH bases in `HabitTheme`, the way
#89 authored Kadō. Every surface derives from the bases by the existing
rules, so the per-theme sweeps from #111 (gamut, ink, ramp, not-due,
contrast, widget alpha) cover them with no new code. One new sweep:
the **minimum pairwise ΔE in Oklab** between a theme's eight slots.

Without the pack a paid theme renders as Kadō — in the app through
`\.supporterPack`, in the widgets through the App Group mirror
(`HabitThemeDefaults.renderedTheme()`) — and the stored pick is kept.
A tap on a locked row pushes the Supporter pack screen instead of
storing the pick.

## The palettes, measured

Rendered 8-bit colours, both schemes; the floor is 0.025.

| Theme | Closest pair (ΔE) | Min glyph on fill | Min ink on mark |
|---|---|---|---|
| Kadō (reference) | 0.029 — dark mint / teal | 3.16 | 5.33 |
| Classic (reference) | 0.049 — light mint / teal | 3.32 | 5.68 |
| Muted | 0.038 — dark red / orange | 3.17 | 5.40 |
| Vivid | 0.080 — dark mint / teal | 3.81 | 5.59 |
| Autumn | 0.096 — dark pumpkin / amber | 3.08 | 4.92 |
| Monochrome sage | 0.058 — light teal / blue | 3.63 | 4.86 |

Rationale for each palette lives in its doc comment in `HabitTheme.swift`.

## Decisions made

- **ΔE floor 0.025, under Kadō's own closest pair.** Kadō's dark mint
  and teal (0.029) are what people have told apart since #89; the floor
  rejects anything tighter. A JND-sized 0.02 is too lenient for eight
  18pt dots. Every paid palette clears 0.035.
- **Hue spacing stays, for themes spread around the wheel.**
  `HabitTheme.spansHueWheel` exempts Monochrome sage (held to a lightness
  ladder: one hue, ≥0.05 L per step, darkest first in both schemes) and
  Autumn (held to four oranges + four greens).
- **Autumn is oranges and greens only** (maintainer feedback on the first
  cut, which spread brick-to-plum across the wheel and read too close to
  Kadō). Rust, pumpkin, amber, chestnut; olive, moss, forest, pine — each
  family a lightness/chroma ladder. Slots keep their *temperature*
  (red/orange/yellow warm, green→blue cool, purple → chestnut).
- **Muted can't go below C ≈ 0.06.** The ink keeps the base's chroma and
  `inkIsDisplayable` requires it above 0.05, so the ink stays a tint of
  the hue rather than a grey. Muted's hues are spread to ≥35° apart to
  compensate for the halved chroma.
- **Monochrome's ends are set by the palette's rules.** Light L 0.36…0.78:
  0.78 is the palest base whose 20% ramp floor still sits under the
  never-due tile. Dark L 0.48…0.90 for the same reason on the other side.
- **"Seasonal" is named Autumn.** The issue describes it as "an autumn
  set"; *Autumn* / *Automne* says what the user gets.
- **The picker's checkmark follows the rendered theme.** A lapsed paid
  pick shows Kadō checked, because that is what the screen is painted in.
- **UI tests own the pack through a mock.** `-uiTestSupporter` makes
  `KadoApp` inject `MockSupporterPackStore(isSupporter: true)`;
  `-uiTestHabitTheme <raw>` writes the theme from inside the app.
  `HabitPaletteCaptureTests` photographs each palette and is skipped by
  `make e2e`.

## Known limits

- **Monochrome compares badly across rows.** In Overview, a pale slot's
  complete day is lighter than a dark slot's partial one. Within one
  habit's row the ramp still reads correctly, and rows are what the
  grid compares. Inherent to a lightness-only palette.

## Still to do by hand

- [ ] Widgets under **Tinted** and **Clear**, light and dark, for each
      paid palette (`test_sim` cannot see WidgetKit's flattening — see
      CLAUDE.md "Widget colours"). The alpha sweeps pass for every theme.
- [ ] Native-speaker review of the FR strings: *Feutré*, *Vif*,
      *Automne*, *Sauge monochrome*, and the lock footer and VoiceOver
      value and hint.
- [ ] VoiceOver pass on the picker: a locked row reads
      "Vivid, Needs the Supporter pack, Opens the Supporter pack."
