# Compound — Colour update (design handoff)

**Date**: 2026-09-12
**Status**: complete
**Research**: [research.md](./research.md)
**Plan**: [plan.md](./plan.md)
**Branch / PR**: `feature/color-update` — after-captures in [`after/`](./after/)

## Summary

The eight habit hues are authored in OKLCH at matched lightness and
chroma, every habit-coloured surface is derived from the base by
mixing in Oklab over the page ground, and every secondary-text role
sits on `kadoForegroundSecondary` instead of the system's cool grey.
Nothing moved. The plan held except in the widget, where the Home
Screen's tint forced a split between "mix in Oklab" and "carry the
value as alpha"; and the text sweep grew to cover the system-drawn
form section headers, which turned out to be most of Settings. The
headline lesson: the handoff's numbers were sampled off anti-aliased
screenshots, so measuring the *tokens* first — and stating the
verification list as invariants over every hue in both schemes —
was what kept the work to colours only.

## Decisions made

- **Author hues in OKLCH, derive everything, cache the derivations**:
  matched L / C is the whole point of the handoff; a table-backed
  `HabitColor.tint(_ surface:)` means views take a named surface and
  two reads of it are the same `Color`.
- **Mix in Oklab at static-init time, hand SwiftUI opaque dynamic
  colours**: SwiftUI has no `color-mix`; `Color.opacity` composites
  in gamma-encoded sRGB, which the handoff explicitly calls out.
  ~150 conversions once, none per frame.
- **The ground is read back from `kadoPaper50`, not restated**: the
  palette cannot drift from the token it mixes over.
- **Glyphs on a filled control are the page colour, not white**: on
  the lifted dark bases white is 2.5–2.8:1; the page is 7:1+, and in
  light it is cream, which is what white was doing anyway.
- **Teal C 0.105, yellow L 0.64**: the last in-gamut chroma at the
  handoff's hue, and the same lift the handoff gives orange, so the
  cream glyph clears 3:1.
- **Widget: Oklab in full colour, alpha under the tint**: alpha is
  the one thing `.accented` preserves.
- **Slipped pill keeps its system button styles**: the handoff's "no
  resize" beats the handoff's "exactly 20%"; the label is still
  ink-on-tint.
- **Missed tile keeps the 20% hue**: the README's derivation table
  has it and `DayCell.colorOpacity` documents why; the mockup legend's
  neutral "Missed" was the designer's rendition, not the spec.
- **The flame moves to the palette's orange**: last full-chroma system
  colour on the two screens; meaning unchanged.
- **Dark neutrals untouched**: already within two units of the spec.

## Surprises and how we handled them

### The handoff's "old" values were pixel samples

- **What happened**: the README's `#7C7568` for row meta didn't match
  any token; sampling the glyph *cores* showed the meta text was
  already `kadoInk500` (`#605B51`), the very colour the README asked
  for, while the section headers were the system's `.secondary`
  (`#888789` on cream).
- **What we did**: treated the README as a role remap, not a ramp
  change, and swept every `.secondary` onto the existing secondary
  token. No new neutral was added.
- **Lesson**: before implementing a colour handoff, sample the
  screenshots and diff against the tokens. Half the "changes" may
  already be there and the real bug may be somewhere the handoff
  didn't name.

### White on the filled control fails in dark mode

- **What happened**: computing the contrast table for the handoff's
  values showed the L 0.70 dark bases at 2.5–2.8:1 under white.
- **What we did**: `onFill` is `kadoBackground`; the test pins ≥ 3:1
  in both schemes for all eight hues.
- **Lesson**: a spec written against light mode needs its dark-mode
  numbers run before its light-mode rules are copied across.

### The widget's tint eats an opaque mix

- **What happened**: the plan routed the weekly grid through
  `tint(_:)`; the cell's own comment ("scored cells already carry
  their own alpha, so they survive the tint untouched") said why that
  would flatten the ramp on the Home Screen's Tinted / Clear.
- **What we did**: `WidgetPalette.matrixTint(_:amount:)` — Oklab mix
  in `.fullColor`, hue-at-alpha under the tint — with a test that
  checks the alpha under the tint and the channels in full colour.
- **Lesson**: any change to how a habit hue is *built* has to be
  checked against `.accented` separately; `CLAUDE.md`'s widget-colour
  section is the checklist.

### Form section headers are the system's grey too

- **What happened**: after the `.secondary` sweep, Settings still read
  in the old grey — its eleven `Section("…")` titles are drawn by the
  system.
- **What we did**: rewrote them to the closure form with a styled
  header `Text`, the pattern `DayStartSection` already used, plus the
  footers.
- **Lesson**: grep for `Section("` alongside `.secondary` when
  chasing a text colour; the two look the same on screen and live in
  different places in the code.

### Dynamic colours don't compare by value

- **What happened**: `progressIsClamped` compared two freshly built
  `Color(UIColor { … })`s with `==` and failed, as the plan's risk
  section predicted.
- **What we did**: tests resolve to 8-bit channels per scheme; named
  surfaces are cached so identity comparison still works where views
  use it.
- **Lesson**: `#expect(colorA == colorB)` only means something for
  colours that come from the same table cell.

### The review round

`/code-review` on the branch returned ten findings; six were applied,
two were left as deliberate:

- **The warm not-due tile was within a JND of the warm hues' 20%
  floor** (orange `#F0DFCD` beside paper `#E9E1D2`, Oklab ΔE ≈ 0.01).
  The hairline swap in Task 4 had quietly recreated the collapse the
  0.2 floor exists to prevent — for warm hues only, which is why the
  Overview screenshot (purple, green, blue, red) looked fine. The
  handoff's own neutrals table has the answer: the not-scheduled tile
  is a lighter paper *inside a 1pt hairline ring*. `MatrixCell` and
  the widget both draw it now; `notDueIsQuietest` pins the fill under
  the floor in both schemes.
- **The ink clipped for six of sixteen hue/scheme pairs** — L 0.46 at
  the base's chroma is outside sRGB for yellow, orange, teal and mint,
  and per-channel clipping had shifted their hue. `OKLCH.fittedToSRGBGamut()`
  gives up chroma instead; `inkIsDisplayable` pins hue and lightness.
- **The calendar's completed cell used an ad-hoc `tint(0.9)` under
  `onFill`**, which is only tested against the full base — 2.8:1 for
  yellow. It is the base now.
- **Unselected icon-picker glyphs drew the base on the hairline**,
  under 3:1 for half the palette. They are `onTint` now.
- **`tint(_ amount:)` built a new dynamic colour per call.** The ramp
  is a 101-entry table per hue; every `HabitTint` amount is a whole
  hundredth, so a named surface and its amount are the same entry and
  `==` holds again.
- The yellow reference in `OKLCHTests` said L 0.70; the gamut check's
  slack is measured in encoded units now; the two pickers have dark
  previews.
- **Left as is**: the weekday initials at 3.25:1 (the handoff keeps
  them light; `CLAUDE.md`'s AA rule argues the other way — a product
  call), and **Increase Contrast**, which the habit hues no longer
  honour because `Color(light:dark:)` branches on style only. The
  paper / ink tokens never did either; proper support is a four-way
  provider (light / dark × normal / high) and is recorded here as a
  known gap rather than bolted on.

## What worked well

- **Computing the whole contrast table before writing the plan.** The
  yellow / teal / white-on-fill decisions were all made from numbers,
  not after a screenshot looked wrong.
- **An independent reference for the colour math.** The Swift
  conversions are checked against a Python implementation, so the
  tests aren't a second copy of the same arithmetic.
- **Invariants over examples.** "Every hue, both schemes, ≥ 4.5:1 on
  the mark" caught nothing this time — which is the point; it will
  catch the ninth hue.
- **`Scripts/screenshots.sh --output … --no-site`** as a verification
  tool: every screen, light and dark, on iPhone and iPad, into scratch
  space in one run, without touching `docs/`.
- **Per-worktree simulators** (`make test`, the screenshot script's
  `SIM_PREFIX`) — nothing collided with the other checkouts.

## For the next person

- `HabitColor` has four derived colours and one function. Use them.
  There is no `.opacity()` on a habit hue anywhere in the app or the
  full-colour widget, and `HabitColorTests` is the contract.
- A new habit colour is a new case with an `OKLCH` base in the same
  C band, spaced ≥ 15° from its neighbours; the tests will say if it
  clips, drifts in lightness, or fails contrast.
- `HabitTint` is the handoff's table. If a view needs a new tinted
  surface, add a named case rather than passing a number.
- `Color(light:dark:)` in `Theme.swift` is module-internal now, for
  the palette's use. Don't make it public without a reason.
- The widget's `.accented` branch is untouched and must stay
  alpha-only. `matrixTint` is the one place a hue takes an alpha.
- The Slipped pill's fill alpha is the system's; if a pixel-exact 20%
  is ever wanted, that is a hand-rolled capsule and a resize.
- The App Store captures and the marketing site are now stale:
  `make screenshots` regenerates both.
- The habit palette does not respond to Increase Contrast (see the
  review round above). If that is picked up, the place is
  `Color(light:dark:)` in `Theme.swift` growing a high-contrast pair,
  and `Palette` in `HabitColor` resolving a second ink / ramp for it.

## Generalizable lessons

- **[→ CLAUDE.md]** Habit hues are authored in OKLCH in `HabitColor`
  and every tinted surface derives from the base via `tint(_:)` /
  `onTint` / `onFill`; never `.opacity()` a habit hue, and never put
  `Color.white` on a habit fill — the dark bases are lifted and white
  sits under 3:1. Under the widget tint, hue-at-alpha is still the
  rule (`WidgetPalette.matrixTint`).
- **[→ CLAUDE.md]** Text on paper is `kadoForegroundSecondary` or
  darker; system `.secondary` and `kadoForegroundTertiary` are ~3:1
  on this cream and are for glyph-scale decoration only (weekday
  initials, the settings colophon). String-titled `Section("…")`
  headers are drawn in the system grey — use the closure form with a
  styled `Text`.
- **[→ CLAUDE.md]** Compare dynamic `Color`s in tests by resolved
  channels per scheme, not `==`, unless both sides come from the same
  cached table entry.
- **[local]** Teal is C 0.105 and yellow is L 0.64 for the reasons in
  `HabitColor.base`'s doc comment.
