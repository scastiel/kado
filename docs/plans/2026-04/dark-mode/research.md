# Research — Dark mode (v0.1)

**Date**: 2026-04-17
**Status**: ready for plan
**Related**: [ROADMAP.md](../../../ROADMAP.md) v0.1 "Full dark mode"

## Problem

`docs/ROADMAP.md` lists "Full dark mode" as a v0.1 MVP deliverable
alongside Dynamic Type XXXL. The line is a one-liner with no explicit
definition, so we scope it here.

**Scope (confirmed)**: every existing v0.1 view renders correctly in
system dark mode, validated via dark-scheme SwiftUI previews and
simulator screenshots. No user-facing toggle (deferred to v1.0's
"Core themes: light, dark, sepia, high contrast"). No brand accent
color redesign (stay on system blue for now).

**Out of scope**: theme picker in Settings, sepia and high-contrast
themes, custom `AccentColor` asset, per-habit color palette tuning
(there are no per-habit colors yet).

**Done looks like**: launch the app with system set to Dark → every
screen is legible, no invisible text, no washed-out cards, no jarring
white flashes. A reviewer can flip `.preferredColorScheme(.dark)` in
any preview and see a sensible result.

## Current state of the codebase

The codebase is already largely dark-mode-friendly because nearly all
color use is semantic and flows through SwiftUI's adaptive system
colors. A full Grep for hardcoded colors turned up **two** literal
`Color.white` uses, and zero `Color(red:…)`, hex strings, or custom
`Color` definitions.

### Colors in use (all semantic, auto-adapt)

- `Color.primary`, `Color.secondary` — text
- `Color.accentColor` — system default blue (no `AccentColor.colorset`
  value set; the asset exists but is empty)
- `Color(.secondarySystemBackground)` — card backgrounds
- `Color(.tertiarySystemFill)`, `Color(.secondarySystemFill)` — button
  and cell fills

### The two `Color.white` literals

Both are **white text on an accent-tinted fill** — a legitimate iOS
pattern, not bugs. Listed here so we verify them under dark mode, not
"fix" them:

- [WeekdayPicker.swift:33](../../../../Kado/UIComponents/WeekdayPicker.swift:33) — selected day capsule (white
  on `Color.accentColor`)
- [MonthlyCalendarView.swift:171](../../../../Kado/UIComponents/MonthlyCalendarView.swift:171) — completed-day number (white on
  `Color.accentColor.opacity(0.9)`)

With system blue, these read fine in both schemes. If we later ship a
custom brand accent, we'll re-validate contrast.

### What's already configured

- `AppIcon.appiconset/` has dark + tinted variants declared.
- No `UIUserInterfaceStyle` override in the project (app respects the
  system setting).
- No existing `@Environment(\.colorScheme)` or `.preferredColorScheme`
  usage anywhere — clean slate for previews.
- [KadoApp.swift](../../../../Kado/App/KadoApp.swift) sets no global tint or scheme override.

### What's missing

- No dark-scheme previews anywhere. 15+ preview blocks all use the
  implicit light default, so no regression surface for dark mode.
- `AccentColor.colorset` is empty. Fine for now — system blue has
  built-in light/dark variants — but it's worth noting for v1.0.
- `SettingsView` is a `ContentUnavailableView` placeholder; its own
  comment defers themes to v1.0.

## Proposed approach

Treat this as a **validation-and-fix pass**, not a redesign. Five
small steps:

### Key components

1. **Dark-scheme preview coverage**. Add one `.preferredColorScheme(.dark)`
   preview per view that has non-trivial color surface — the 5
   UIComponents and the main screens. Simple rule: if the existing
   preview exercises a layout, add a matching dark one.
2. **Screenshot audit**. Boot the iPhone 16 Pro simulator with Dark
   Appearance, launch the app, navigate: Today → Habit Detail → New
   Habit sheet → Monthly calendar (month with mixed states) → Counter
   quick-log → Timer log sheet → Settings. `screenshot` at each stop,
   eyeball for legibility and contrast.
3. **Fix anything surfaced**. Most likely candidates, *if* anything
   needs it:
   - Card backgrounds that look too close to the page (swap
     `secondarySystemBackground` → `.regularMaterial` for depth, or
     add a subtle stroke).
   - Accent-on-fill contrast in the `MonthlyCalendarView` for
     non-completed-but-accent-tinted cells (the `.nonDue` and `.future`
     opacity tweaks may read too dim in dark).
4. **Dynamic Type + dark combo spot-check**. Dynamic Type XXXL is
   already on the v0.1 checklist; run one pass with Dark + XXXL
   together on the Habit Detail screen, which is the densest.
5. **Accessibility contrast pass**. Enable the simulator's "Increase
   Contrast" toggle once and re-screenshot Today + Habit Detail.
   Not a shipping requirement for v0.1, but cheap to check now.

### Data model changes

None.

### UI changes

None planned as code rewrites. Any changes will be small surgical
tweaks discovered during step 2 (the audit). Most likely zero-to-one
modifier changes.

### Tests to write

No unit tests — dark mode is a visual concern. The "tests" are:

- Dark-scheme SwiftUI previews (covered in step 1).
- One UI smoke-test note in the PR description: "verified
  Today/Detail/New in system dark".

## Alternatives considered

### Alternative A: Ship a user-facing theme toggle now

- Idea: Add `@AppStorage("themePreference")` + a `Picker` in
  `SettingsView` for Light/Dark/System, bind to
  `.preferredColorScheme` at the App root.
- Why not: Deferred by the existing `SettingsView` comment to v1.0,
  and v0.1's Settings scope is "about, iCloud sync on/off." A toggle
  adds a new user-facing surface that'll want to be revisited once
  sepia/high-contrast join it.

### Alternative B: Define a custom `AccentColor` with explicit light/dark pair

- Idea: Fill `AccentColor.colorset` with a brand blue (or similar)
  that has hand-tuned dark variant.
- Why not: Belongs to a separate "visual identity" task. System blue
  is fine, and changing the accent is a decision with product weight
  beyond dark mode.

### Alternative C: Do nothing and ship

- Idea: Claim "full dark mode" is already done because semantic
  colors handle it.
- Why not: We don't *know* it renders well — no previews, no
  screenshots. The validation pass is what makes the checkbox honest.

## Risks and unknowns

- **Accent-tinted text contrast under custom accents**. Not a v0.1
  risk (we're on system blue), but the white-on-accent pattern in
  WeekdayPicker and MonthlyCalendarView will need a contrast check if
  we ever ship a non-blue accent. Noted here so future-us remembers.
- **`screenshot` doesn't catch "feels off"**. A human eyeball on the
  device is still the final arbiter. The author uses the app daily
  (per ROADMAP exit criteria), so dogfooding fills the gap.
- **`MonthlyCalendarView` cell state opacity values** (`0.9`, `0.4`)
  were picked in light mode and may need dark adjustment — flag for
  the audit step.

## Open questions

- [ ] After the audit, if a card ends up flat against the background
      in dark, do we add depth via `.regularMaterial` or a 1px
      separator stroke? (Decide when we see the screenshot.)
- [ ] Do we want to commit the dark-scheme screenshots to
      `docs/plans/2026-04/dark-mode/` as a visual record, or is the
      PR description enough?

## References

- [Apple HIG — Dark Mode](https://developer.apple.com/design/human-interface-guidelines/dark-mode)
- [SwiftUI `preferredColorScheme(_:)`](https://developer.apple.com/documentation/swiftui/view/preferredcolorscheme(_:))
- [UIKit system colors](https://developer.apple.com/documentation/uikit/uicolor/ui_element_colors) — the ones bridged to SwiftUI via `Color(.secondarySystemBackground)` etc.
- [ROADMAP.md](../../../ROADMAP.md) v0.1 and v1.0 entries for theming
