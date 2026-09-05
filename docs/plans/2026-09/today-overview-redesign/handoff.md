# Handoff: Kado — Today & Overview redesign

## Overview

Kado is an iOS habit tracker. This handoff covers a reworked **Today** screen and **Overview** screen, addressing four problems in the shipping build:

1. Today rows carried four inconsistent control types plus a redundant chevron, and the "Slipped" state occupied the action slot so a slipped habit could not be logged.
2. The Today screen never answered "how much of today is done".
3. The unexplained percentage on every row (`43%`) read as completion when it is actually habit strength.
4. The Overview heatmap alternated light and full-saturation tiles with no legend, so it read as a decorative checkerboard rather than data; tiles were also misaligned with their date column headers.

The redesign also pulls the habit palette down in chroma so the saturated system colors stop fighting the warm cream / serif / dark-green brand, and moves the add button from the top-right into thumb reach.

## About the design files

`Kado Redesign.dc.html` is a **design reference created in HTML** — a static prototype showing intended look, layout, and copy. It is not production code and should not be ported or embedded.

The task is to **recreate these two screens in Kado's existing iOS codebase** (SwiftUI, presumably) using its established view structure, color assets, type styles, and components. Where this document gives an exact value, match it; where the codebase already has an equivalent token, prefer the token and note the discrepancy.

## Fidelity

**High fidelity.** Colors, type sizes, spacing, and corner radii are final and specified below. Two deliberate exceptions:

- **Habit marks are placeholders.** The prototype draws monogram letters (`M`, `R`, `N`, `D`, `G`) in a tinted circle because the real SF Symbol icon set was not available to the prototype. Use the app's existing per-habit icons in the same 38pt tinted circle. Everything else about the mark — circle size, 16% tint fill, icon color — is final.
- **Device chrome** (status bar, bezel) in the prototype is a mock frame, not part of the design.

---

## Screen 1 — Today

**Purpose:** log today's habits in one tap, and see at a glance how much of the day is complete.

### Layout

Vertical stack, 20pt horizontal page margin, 14pt top padding below the status bar. Gap between major blocks: 22pt.

```
Title block
  "Today"                       Playfair Display 500 / 40pt / line-height 1
  progress row                  [4pt bar, 1fr] — gap 10 — "3 of 5 done"
  "Percentages show habit strength."
Section: SCHEDULED TODAY
  card (4 rows, hairline separators)
Section: NOT SCHEDULED TODAY
  card (1 row)
[spacer]
FAB (absolute, bottom-right)
Tab bar
```

### Section header

12pt, weight 700, uppercase, letter-spacing 0.08em, color `#5F5849`, 2pt left inset, 8pt gap to the card below. Copy: `SCHEDULED TODAY` / `NOT SCHEDULED TODAY` — parallel phrasing (the shipping build used "Scheduled" / "Not scheduled today").

### Habit row — the core of this redesign

Card: background `#F1ECE2`, corner radius 22pt, padding `4pt 14pt`. Rows separated by a 1pt `#E4DDCF` hairline **inset 50pt from the left** so it starts at the text column, not under the icon.

Row grid: `38pt | 1fr | auto`, `align-items: center`, column gap 12pt, vertical padding 13pt.

| Element | Spec |
|---|---|
| Mark | 38×38pt circle. Fill = habit color at 16% over `#FAF6EE`. Icon in habit color darkened to ~L 0.48. |
| Title | 17pt, weight 600, color `#191712`, letter-spacing −0.01em |
| Meta | 13pt, color `#605949`, `white-space: nowrap`, tabular numerals, 3pt below title |
| Control | Right-aligned, **44pt tall in every variant** |

**Meta line must not wrap.** All five strings are short enough to fit on one line at the narrowest text column (the stepper row, ~167pt): `2-day streak · 43%`, `20/30 min · 35%`, `Streak reset · 41%`, `4/8 glasses · 30%`, `Next Monday · 21%`. Equal row heights are the whole point of the row system — if a longer real string appears, truncate the meta with an ellipsis rather than wrapping.

**No chevron on any row.** The full row is tappable and opens detail; the chevron duplicated that affordance and crowded the control.

#### Control variants — exactly one per habit type

1. **Binary, done** — 44pt circle filled with the habit color, white checkmark.
2. **Binary, not done** — 44pt circle, 2pt border in habit color at 36% over cream, no fill.
3. **Binary, not scheduled today** — 44pt circle, 2pt **dashed** border in habit color at 40%. Signals "you may log this, but it doesn't count against today".
4. **Timer** — pill, 44pt tall, 22pt radius, min-width 62pt, 16pt horizontal padding. Fill = habit color at 18% over cream; label `+5m` at 16pt weight 700 in habit color at ~L 0.44.
5. **Counter** — pill, 44pt tall, 22pt radius, fill = habit color at 14% over cream, 4pt padding. Contents: 36pt circular minus button (bare, glyph in habit color L 0.48) → current value, 15pt weight 700, tabular, min-width 12pt centered → 36pt circular plus button filled with the habit color, white glyph. The filled plus makes the forward action obvious; minus stays quiet.

#### Slipped state

`Slipped` is a **status, not a control**. It renders as a tag beside the title — 11pt, weight 700, uppercase, letter-spacing 0.04em, radius 5pt, padding `2pt 6pt`, text in habit color at L 0.46, fill = habit color at 20% over cream. The meta line reads `Streak reset · 41%`. The action slot keeps variant 2 (empty circle) so the habit is still loggable.

### Progress row

4pt tall track, 2pt radius, background `#E4DDCF`; fill `#24402E` at the completed fraction (60% in the mock). Label right of the bar: 12pt, weight 600, color `#4E4938`, tabular numerals, format `{done} of {total} done`. Counts scheduled habits only.

Beneath it, 12pt `#5F5849`: `Percentages show habit strength.` — labels the number once instead of repeating "strength" on every row.

### Add button (FAB)

58×58pt circle, `#24402E`, white plus (20×2.5pt bars, 2pt radius), shadow `0 10pt 24pt rgba(26,24,20,.26)`. Positioned 20pt from the right edge, 108pt from the bottom — clearing the tab bar and sitting in thumb reach. The shipping build placed it top-right.

### Tab bar (both screens)

Centered floating pill: background `#FFFDF8`, radius 30pt, padding 7pt, shadow `0 4pt 18pt rgba(26,24,20,.10)`, 26pt bottom margin, 4pt gap between items. Each item: vertical stack, 4pt gap, padding `8pt 20pt`, radius 24pt. Selected item gets a `#E7E1D4` chip, `#24402E` icon, 11pt weight 700 label. Unselected: `#8A8375` outline icon, 11pt weight 600 `#8A8375` label. **Selection treatment must be identical in light and dark mode** — in the shipping dark build the selected chip was far brighter than its light-mode counterpart.

The tab-bar glyphs in the prototype are plain squares/circles standing in for the real icons.

### Removed

The caption "Tap to open detail, or long-press to edit or archive." is gone. If retained as onboarding, it should decay after a few sessions rather than living in the layout permanently.

---

## Screen 2 — Overview

**Purpose:** compare habits across recent days, and see something the Today list can't tell you.

### Layout

Same 20pt page margin. Block gap 18pt.

```
Title block     "Overview" + "Last 10 days · 34 of 47 scheduled days logged"
Date header     10-column grid
Habit rows      5 × (label row + 10-column tile grid), gap 16pt
Legend          top hairline, wrapping row
[spacer]
Tab bar
```

### Date header

`grid-template-columns: repeat(10, 1fr)`, gap 5pt, 2pt horizontal inset. Per column, centered: weekday initial 10pt weight 700 `#8A8375`, then date 12pt `#5F5A4E` tabular. Today's column: both lines `#24402E`, date weight 700.

**The tile grid uses the identical grid definition**, so tiles line up with their headers. Misalignment (and left-edge clipping) was a defect in the shipping build.

### Habit row

Label row: `space-between`, 2pt inset. Left: 9pt habit-color dot + 15pt weight 600 `#191712` name, 8pt gap. Right: strength percentage, 13pt `#605949`, tabular. Habit color appears in the dot only — not in the name.

Tile grid 7pt below: 10 columns, gap 5pt, each tile `aspect-ratio: 1`, radius 7pt.

### Tile ramp — one hue per row, four states

| State | Fill |
|---|---|
| Complete | habit color, full |
| Partial | habit color at 45% over `#FAF6EE` |
| Light / minimal | habit color at 20% over `#FAF6EE` |
| Missed (scheduled, not logged) | `#E7E1D4` |
| Not scheduled | `#EFEAE0` with a 1pt inset `#E4DDCF` ring |

A single-hue intensity ramp per row makes rows comparable at a glance; the old alternating full-saturation pattern did not encode anything readable. "Not scheduled" is visually distinct from "missed" — an empty ring, not a filled tile — which matters for habits like Gym that run a few days a week.

### Legend

Above the tab bar, 1pt `#E4DDCF` top border, 14pt top padding, 14pt gap, wrapping. Four items, each a 13pt swatch (4pt radius) + 11pt `#5F5849` label: **Missed** `#E7E1D4`, **Partial** `color-mix(#8A8375 45%, #FAF6EE)`, **Complete** `#6C6558`, **Not scheduled** `#EFEAE0` + inset ring. Neutral greys in the legend teach the ramp without implying a habit.

### Summary line

13pt `#605949` under the title: `Last 10 days · 34 of 47 scheduled days logged`. Gives Overview a reason to exist beyond restating Today. Compute over the visible window, counting scheduled days only.

### Row order

Overview and Today must use the same sort order. They diverged in the shipping build.

---

## Interactions & behavior

| Trigger | Result |
|---|---|
| Tap habit row (anywhere outside the control) | Push habit detail |
| Long-press habit row | Context menu: Edit, Archive |
| Tap binary control | Toggle today's completion; fill/unfill with a spring, and animate the day-progress bar |
| Tap `+5m` | Add 5 minutes; meta updates `20/30 min`; control becomes variant 1 on reaching target |
| Tap stepper `+` / `−` | Increment/decrement, clamped at 0 and at target; value animates |
| Tap FAB | Present New Habit sheet |
| Tap Overview tile | Optional: popover with that day's value; not specified here |
| Horizontal drag on Overview grid | Scroll the date window; header scrolls with the tiles and stays column-aligned |

Not specified in this handoff (behave as the codebase already does): pull-to-refresh, empty states, error states, haptics. All logging should be optimistic with local write-through.

Progress bar and control-state transitions: ~200ms, ease-out. Nothing else animates.

## State

Per habit: `id`, `name`, `icon`, `colorHue`, `type` (`binary | timer | counter`), `target`, `scheduleRule`, `isScheduledToday`, `todayValue`, `didSlip`, `streak`, `strength`, `nextScheduledDate`, plus a per-day log history for the Overview window.

Derived for Today: `scheduledHabits` / `unscheduledHabits`; `doneCount` and `scheduledCount` for the progress bar. Derived for Overview: per-habit `[dayState]` over the visible window, and `loggedDays / scheduledDays` for the summary.

## Design tokens

**Neutrals (light)**

| Token | Value | Use |
|---|---|---|
| Page | `#FAF6EE` | screen background |
| Card | `#F1ECE2` | habit cards |
| Card raised | `#FFFDF8` | tab bar |
| Hairline | `#E4DDCF` | separators, borders |
| Tile empty | `#E7E1D4` | missed tiles, selected tab chip |
| Tile off | `#EFEAE0` | not-scheduled tiles |
| Ink | `#191712` | titles |
| Ink secondary | `#605949` | meta, values |
| Ink tertiary | `#5F5849` | section labels, legend, captions |
| Ink quiet | `#8A8375` | weekday initials, unselected tab |
| Brand green | `#24402E` | progress fill, FAB, selection |

All secondary and tertiary text clears 4.5:1 against both `#FAF6EE` and `#F1ECE2`. Do not lighten these — low-contrast secondary text was one of the problems being fixed. `#8A8375` is used only for non-essential glyph-scale labels; if the codebase applies it to body copy, darken it.

**Habit hues** — declared in OKLCH so lightness and chroma stay matched across habits. Full-chroma system colors are what made the old screens loud.

| Habit | Base |
|---|---|
| Meditation (purple) | `oklch(0.58 0.14 305)` |
| Read (teal) | `oklch(0.58 0.11 180)` |
| No social media (coral) | `oklch(0.60 0.14 30)` |
| Drink water (blue) | `oklch(0.58 0.12 250)` |
| Gym (amber) | `oklch(0.64 0.12 65)` |

Derivations from a habit base: icon/text `L 0.42–0.50` at the same chroma and hue; mark fill 16% over page; timer pill 18%; counter pill 14%; slipped tag 20%; outline border 36–40%; Overview partial 45%, light 20%. New habits should be generated on the same L/C with a new hue, not picked from a system palette.

**Type** — Playfair Display 500 for screen titles (40pt) only; system sans for everything else. Sizes: 40 / 17 / 15 / 13 / 12 / 11. Weights: 600 for titles and labels, 700 for uppercase labels and numerals in controls. Tabular numerals everywhere a number can change.

**Spacing** — 4 / 5 / 7 / 8 / 12 / 14 / 16 / 18 / 20 / 22 / 26. Page margin 20. Radii: 5 (tag) / 7 (tile) / 22 (card, control pill) / 24 (tab item) / 30 (tab bar) / 50% (marks, FAB). Shadows: FAB `0 10 24 rgba(26,24,20,.26)`; tab bar `0 4 18 rgba(26,24,20,.10)`. Nothing else casts a shadow.

**Minimum hit target: 44pt.** Every control variant is 44pt tall by construction.

## Dark mode

Not mocked. Two findings from the shipping dark build that should be fixed alongside this work:

- Pure black ground with near-black cards loses both the brand warmth and the card/ground separation. Use a warm dark ground around `#141210` with a lifted card (roughly `#1E1B17`) and keep the same hairline logic.
- The selected tab chip was much brighter than in light mode. Use the same relative treatment in both.

Habit hues in dark mode: raise L to ~0.68–0.72 at the same chroma so marks and tiles keep contrast against the dark ground.

## Assets

None shipped in this bundle. Habit icons and tab-bar icons come from the app's existing icon set — the prototype substitutes monogram letters and plain squares/circles. Playfair Display is loaded from Google Fonts in the prototype; if the app doesn't already bundle it, either bundle it or substitute the existing display serif.

## Files

- `Kado Redesign.dc.html` — the prototype. Open in a browser; the two frames are labelled `1a` (Today) and `1b` (Overview). Inline styles carry every value quoted above.
- `mockups/1a-today.png`, `mockups/1b-overview.png` — 2x renders of the two redesigned screens.
- `current-app/01-today.png`, `current-app/03-overview.png` — the shipping screens, for before/after comparison.
