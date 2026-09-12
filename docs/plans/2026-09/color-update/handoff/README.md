# Handoff: Kado — color update only

## Scope

**Colors only.** No layout, spacing, type, component structure, or behavior changes. Every value below is a swap of an existing color for a new one. If a change appears to require moving, resizing, or restructuring anything, it is out of scope — leave it and flag it.

Two goals:

1. **Stop the two palettes fighting.** The warm cream / serif / dark-green brand and the full-chroma system habit colors read as two different apps. Habit hues move to a matched-lightness OKLCH set so they sit in the warm world.
2. **Fix secondary-text contrast.** Several greys fall below 4.5:1 on the cream grounds.

---

## 1. Neutrals

| Role | Old | New |
|---|---|---|
| Page background | `#FAF6EE` | unchanged |
| Card | `#F1ECE2` | unchanged |
| Card raised (tab bar) | `#FFFDF8` | unchanged |
| Hairline / separators | `#E4DDCF` | unchanged |
| Tile empty (missed), selected tab chip | `#E7E1D4` | unchanged |
| Tile off (not scheduled) | `#EFEAE0` | unchanged |
| Title ink | `#191712` | unchanged |
| Brand green | `#24402E` | unchanged |

The neutral ramp itself is fine. What changes is which greys carry text:

| Text role | Old | New | Why |
|---|---|---|---|
| Row meta (`2-day streak · 43%`), Overview percentages, summary line | `#7C7568` | **`#605949`** | 3.4:1 → 6.0:1 on card |
| Section labels (`SCHEDULED TODAY`), legend labels, captions | `#8A8375` | **`#5F5849`** | 2.9:1 → 6.1:1 |
| Progress label (`3 of 5 done`) | `#5F5A4E` | **`#4E4938`** | 5.3:1 → 7.4:1 |
| Weekday initials, unselected tab labels/icons | `#8A8375` | unchanged | glyph-scale, non-essential |

Keep `#8A8375` only for the Overview weekday initials and the unselected tab items. Anywhere it currently carries body or meta text, move it to `#5F5849`.

---

## 2. Habit hues

Declare each habit's color as an OKLCH base and derive every tint from it. The point is matched lightness and chroma across habits — the old set mixed saturated system colors at different perceptual weights, so some habits shouted and others vanished.

| Habit | Old | New base |
|---|---|---|
| Morning meditation | system purple | `oklch(0.58 0.14 305)` |
| Read | system teal | `oklch(0.58 0.11 180)` |
| No social media | system red | `oklch(0.60 0.14 30)` |
| Drink water | system blue | `oklch(0.58 0.12 250)` |
| Gym | system orange | `oklch(0.64 0.12 65)` |

### Derivations

Every habit-colored surface is one of these. Do not hand-pick per-habit values.

| Surface | Derivation |
|---|---|
| Icon / text on tint | same H and C, **L 0.42–0.50** |
| Mark circle fill (38pt) | base at **16%** over page |
| Timer pill (`+5m`) fill | base at **18%** over page |
| Counter pill fill | base at **14%** over page |
| Slipped tag fill | base at **20%** over page |
| Outline control border | base at **36%** (scheduled) / **40%** (not scheduled, dashed) |
| Filled control (done check, stepper `+`) | base, full |
| Overview tile — complete | base, full |
| Overview tile — partial | base at **45%** over page |
| Overview tile — light | base at **20%** over page |

"X% over page" = `color-mix(in oklab, base X%, #FAF6EE)`. On iOS, mix in a perceptual space (Oklab or Lab), not sRGB — sRGB mixing muddies the mid tints.

**New habits** should be generated on the same L/C with a new hue, spaced from existing hues — not picked from a system color palette.

---

## 3. Where habit color may appear

A placement rule, not a layout change — but it affects which element gets the color:

- **Overview:** habit color appears in the **9pt dot only**. The habit name stays `#191712`. Previously the saturated color ran across large tile fills and made row-to-row comparison hard; the single-hue ramp plus a neutral name fixes it.
- **Today:** habit color appears in the mark, the control, and the slipped tag. Titles and meta stay neutral.

---

## 4. Legend swatches (Overview)

The legend teaches the ramp, so its swatches are **neutral**, not any habit's hue:

| Item | Fill |
|---|---|
| Missed | `#E7E1D4` |
| Partial | `color-mix(in oklab, #8A8375 45%, #FAF6EE)` |
| Complete | `#6C6558` |
| Not scheduled | `#EFEAE0` with 1pt inset `#E4DDCF` ring |

---

## 5. Dark mode

| Change | Old | New |
|---|---|---|
| Ground | pure black | **`#141210`** (warm dark) |
| Card | near-black | **`#1E1B17`** (lifted off the ground) |
| Habit hues | same as light | raise **L to 0.68–0.72**, same C and H |
| Selected tab chip | much brighter than light mode | same relative treatment as light mode |

Pure black lost both the brand warmth and the card/ground separation. The hairline logic stays as-is, adapted to the dark ramp.

---

## Verification

- Every text color clears **4.5:1** against both `#FAF6EE` and `#F1ECE2`.
- Each habit's five tints are visibly one family, and the five habits read at equal weight — no habit dominates.
- Light and dark selected-tab treatments match in relative contrast.
- Nothing moved.

## Reference

- `Kado Redesign.dc.html` — frames `1a` (Today) and `1b` (Overview); inline styles carry every value above.
- `mockups/1a-today.png`, `mockups/1b-overview.png` — 2x renders.
- `current-app/01-today.png`, `current-app/03-overview.png` — before.
