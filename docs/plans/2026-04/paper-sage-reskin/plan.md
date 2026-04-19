# Plan — Paper / sage re-skin

**Date**: 2026-04-19
**Status**: done
**Research**: [research.md](./research.md)

## Summary

Apply the Claude Design hand-off's moderate-fidelity re-skin to the
iOS app: paper surfaces, sage accent replacing system blue, Fraunces
variable font for large titles, ensō brand assets. Scope spans the
main app chrome, `HabitRowView`, the six widget surfaces, and the
app icon. No data-layer, schema, or CloudKit change. Seven atomic
commits on `feature/paper-sage-reskin`, PR [#17](https://github.com/scastiel/kado/pull/17)
already open as draft.

## Decisions locked in

- Chrome path: `UINavigationBarAppearance.largeTitleTextAttributes` +
  root `.kadoTheme()` modifier. No per-screen `safeAreaInset` titles.
- Overview + HabitDetail keep current layout; tokens only.
- `HabitColor` keeps SwiftUI system accents; custom-hex palette
  deferred to v1.0 identity audit.
- Widgets: background + tint swap only. No Fraunces in widget digits.
- App icon: single 1024×1024 PNG in the universal slot; iOS auto-
  generates dark + tinted variants.
- "稼働 · in operation" Settings footer: deferred.
- Fraunces ships as one variable TTF (`Fraunces[SOFT,WONK,opsz,wght].ttf`,
  ~800 KB, SIL OFL) bundled in `KadoCore`'s resources.
- Flame in `MetricsChip` already uses `Color.orange` — already compliant
  with the handoff's red-line, no change needed.

## Prerequisites (user action, off-task)

These two binary assets aren't in the repo yet and aren't in the
hand-off bundle. Get them before Task 2 / Task 6 respectively:

1. **Fraunces TTF**. Download "Fraunces" from Google Fonts → unzip →
   copy `Fraunces[SOFT,WONK,opsz,wght].ttf` into
   `Packages/KadoCore/Sources/KadoCore/Resources/Fonts/` (create the
   directory). Until this file is in place, `KadoFont.register()`
   no-ops and nav/hero titles fall back to the system serif — Task 2
   still compiles.
2. **App icon 1024×1024 PNG**. Rasterize
   `~/Downloads/design_handoff_kado_reskin/assets/kado-app-icon.svg`
   at 1024×1024. `magick` is installed locally
   (`/opt/homebrew/bin/magick`) so the conversion can be scripted as
   part of Task 6, but the SVG is source-of-truth and should be
   copied into the repo too (e.g. under `docs/` or a `branding/`
   folder) so future icon passes aren't handoff-directory-dependent.

## Task list

### Task 1: KadoCore plumbing + Theme tokens ✅

**Goal**: Add every design token and a light/dark-aware color system
in `KadoCore`, so nothing else in the plan has to invent a hex.

**Changes**:
- `Packages/KadoCore/Package.swift` — add `resources: [.process("Resources")]`
  to the target.
- `Packages/KadoCore/Sources/KadoCore/Resources/Fonts/.gitkeep` — stub
  so the directory survives `git add`.
- `Packages/KadoCore/Sources/KadoCore/Design/Theme.swift` — verbatim
  from the hand-off (`~/Downloads/.../swift_patches/Theme.swift`).
  Exposes `Color.kadoPaper50 … kadoSage900`, semantic aliases
  (`kadoBackground`, `kadoForeground`, `kadoAccent`, …), `KadoRadius`,
  `KadoSpace`, `KadoMotion`.

**Tests / verification**:
- `test_sim` — all existing tests still pass (the new types don't
  participate in persistence or business logic).
- `build_sim` — Package compiles; no warnings.

**Commit message**: `feat(reskin): design tokens (paper, sage, ink) in KadoCore`

---

### Task 2: Bundle Fraunces + KadoFont registration ✅

**Goal**: Register the Fraunces variable font at app launch and
expose `.kadoDisplay(size:)` + `.kadoEyebrow()` helpers.

**Changes**:
- Drop `Fraunces[SOFT,WONK,opsz,wght].ttf` into
  `Packages/KadoCore/Sources/KadoCore/Resources/Fonts/` (user
  prerequisite — Task compiles without it but font falls back).
- `Packages/KadoCore/Sources/KadoCore/Design/KadoFont.swift` — verbatim
  from the hand-off. Exposes `KadoFont.register()`, `Font.kado(_:size:)`,
  view modifiers `.kadoDisplay(size:weight:)` and `.kadoEyebrow()`.
- `Kado/Info.plist` — add `UIAppFonts` array with the TTF filename.
- `Kado/App/KadoApp.swift` — call `KadoFont.register()` in `init`.

**Tests / verification**:
- `build_sim` — app builds with and without the TTF present.
- Manual: launch app, confirm no `[KadoFont] Fraunces TTF not found`
  log line. If the file is missing, the log will say so — that's the
  "TTF not yet dropped in" signal.

**Commit message**: `feat(reskin): bundle Fraunces + font registration`

---

### Task 3: Apply KadoThemeModifier at the root ✅

**Goal**: Replace the system-blue tint and grouped-list gray with
sage + paper. Set the nav bar large-title font to Fraunces via
`UINavigationBarAppearance`.

**Changes**:
- `Packages/KadoCore/Sources/KadoCore/Design/KadoThemeModifier.swift`
  — verbatim from the hand-off, with one local adjustment: drop the
  `UITableView.appearance(whenContainedInInstancesOf: [UIHostingController<AnyView>.self])`
  line (unreliable — SwiftUI's hosting controllers are generic over
  concrete types, not `AnyView`). Rely on `.scrollContentBackground(.hidden)`
  + `.background(Color.kadoBackground)` from the modifier.
- `Kado/Views/ContentView.swift` — wrap the `TabView` body with
  `.kadoTheme()`.
- `Kado/Resources/Assets.xcassets/AccentColor.colorset/Contents.json`
  — populate with sage (`#355944` light / `#9EBEA9` dark) so Xcode
  Previews and anything reading the asset catalog agree with the
  runtime tint.

**Tests / verification**:
- `test_sim` — green.
- `build_sim` iPhone 17 Pro — green, no warnings.
- `screenshot` on each tab (Today, Overview, Settings) light + dark.
  Checklist:
  - Sage replaces blue everywhere (nav-bar actions, Forms, toggles).
  - Grouped backgrounds are warm cream, not iOS default gray.
  - Dark mode backgrounds are warm near-black, not pitch-black.
  - Large title reads as Fraunces (visible serif). If the TTF isn't
    present yet, the title reads as the system serif — acceptable
    until the font drops in.

**Commit message**: `feat(reskin): apply kadoTheme at the root`

---

### Task 4: HabitRowView token pass ✅

**Goal**: Apply the 5-point hand-off patch. Keep row shape, state
machines, accessibility, and previews intact.

**Changes** (in `Kado/UIComponents/HabitRowView.swift`):
- Wrap the row `HStack` in a paper-100 rounded card:
  `.background(Color.kadoBackgroundSecondary)
   .clipShape(RoundedRectangle(cornerRadius: KadoRadius.card, style: .continuous))`
  — applied at the level that reads well inside the existing `List`.
- Habit name: `.font(.body)` → `.font(.system(size: 15, weight: .medium))`;
  `.foregroundStyle(.primary)` → `.foregroundStyle(Color.kadoForeground)`.
- Leading badge ring animation:
  `.animation(.easeOut(duration: 0.2), value: state.progress)` →
  `.animation(KadoMotion.base, value: state.progress)` (same for
  `isComplete`).
- Counter `minus` circle background:
  `Color(.secondarySystemFill)` → `Color.kadoPaper200` (handoff spec
  for the counter minus-button).
- Metrics chip (in `Kado/UIComponents/MetricsChip.swift`):
  `.font(.caption2…)` → `.font(.system(size: 11, design: .monospaced))`
  for the non-flame text; flame + streak number stay `Color.orange`.

**Tests / verification**:
- `test_sim` — green (no logic change; row previews stay green).
- SwiftUI previews ("All types — not done", "All types — complete",
  "Counter — partial / overshoot", "Dynamic Type XXXL", "Dark") all
  render without overflow.
- Manual: tap + hold a row, verify context menu sage tint; tap
  binary check, verify `KadoMotion.base` feels right (quick, no
  spring).

**Commit message**: `feat(reskin): tokenize HabitRow + MetricsChip`

---

### Task 5: Widget re-skin ✅

**Goal**: Bring the six widget surfaces onto paper + sage. Widget
target already links `KadoCore`, so tokens are reachable.

**Changes**:
- `KadoWidgets/TodayGridSmallWidget.swift`,
  `KadoWidgets/TodayProgressMediumWidget.swift`,
  `KadoWidgets/WeeklyGridLargeWidget.swift`:
  `.containerBackground(.fill.tertiary, for: .widget)` →
  `.containerBackground(for: .widget) { Color.kadoBackgroundSecondary }`.
- Lock widgets (`LockRectangular`, `LockCircular`, `LockInline`):
  keep `.clear` container background — system handles the
  lock-screen glassy treatment.
- `KadoWidgets/Views/HabitWidgetCell.swift`: `Color.primary` glyph
  color → `Color.kadoForeground`; leave `habit.color.color` alone.
- `KadoWidgets/WeeklyGridLargeWidget.swift`: `Color.primary` weekday
  labels → `Color.kadoForeground` (today) / `Color.kadoForegroundSecondary`
  (other days).
- `KadoWidgets/Assets.xcassets/WidgetBackground.colorset/Contents.json`
  — repoint to paper-100 so any reference to `Color("WidgetBackground")`
  resolves consistently.

**Tests / verification**:
- `build_sim` — widget extension builds alongside the main app.
- Widget preview snapshots in Xcode for each size (small, medium,
  large, lock-rect, lock-circ, lock-inline).
- Manual: add each widget to a home screen + lock screen, verify
  dark mode + tinted rendering.

**Commit message**: `feat(reskin): widgets on paper surface + sage tint`

---

### Task 6: App icon ✅

**Goal**: Replace the empty AppIcon slot with the ensō mark.

**Changes**:
- Rasterize `~/Downloads/design_handoff_kado_reskin/assets/kado-app-icon.svg`
  to 1024×1024 PNG using local `magick`. Command:
  `magick -background none -resize 1024x1024 kado-app-icon.svg AppIcon.png`.
- Drop the PNG into `Kado/Resources/Assets.xcassets/AppIcon.appiconset/`.
- Update `AppIcon.appiconset/Contents.json` — add `"filename": "AppIcon.png"`
  to the universal entry; leave dark + tinted entries `filename`-less
  so Apple auto-generates (per Q6 decision).
- Also copy the original SVG into a versioned location in the repo —
  suggestion: `branding/kado-app-icon.svg`, alongside
  `branding/kado-mark.svg` and `branding/kado-wordmark.svg`, so
  future passes don't depend on the handoff bundle sitting in
  `~/Downloads`.

**Tests / verification**:
- `build_sim` — icon appears in simulator home screen.
- `screenshot` the home screen with the icon installed.

**Commit message**: `feat(reskin): ensō app icon`

---

### Task 7: Verification + polish ✅

**Goal**: Golden-path smoke test on the full re-skin, capture PR
screenshots, fix any obvious regressions.

**Changes** (open-ended — expect to touch small spots that slipped
through):
- Any lingering `Color.primary` / `Color.secondary` that reads wrong
  against paper (these mostly auto-adapt, but a few spots on
  HabitDetail or Overview may need `Color.kadoForeground` /
  `kadoForegroundSecondary` for better contrast).
- `MonthlyCalendarView` date-pill colors — verify they're legible
  against paper-50.
- `DevModeSection` cosmetic alignment.
- Add `KadoFont.register()` idempotence test:
  ```swift
  @Test("KadoFont.register is safe to call repeatedly")
  func registerIdempotent() {
      KadoFont.register()
      KadoFont.register()
  }
  ```

**Tests / verification**:
- `test_sim` — full suite green.
- `build_sim` iPhone 17 Pro + iPad Air (layout sanity).
- `screenshot` — Today, Overview, Settings, HabitDetail, each
  widget size, each in light + dark. Drop them into the PR
  description.
- Dynamic Type XXXL on TodayView — verify the HabitRow card layout
  doesn't overflow.
- VoiceOver pass on TodayView's first habit row — a11y labels and
  actions still announce.

**Commit message**: `chore(reskin): polish pass + register idempotence test`

## Integration checkpoints

- **Package resources**. `resources: [.process("Resources")]` on
  `KadoCore` is the first time the package bundles anything. Verify
  Xcode re-indexes after the `Package.swift` edit (clean-build once
  if SwiftUI previews go blank).
- **Widget process bundle lookup**. `KadoFont.register()` uses
  `Bundle.module`, which is the **package's** bundle. Widgets link
  `KadoCore` but are a separate process; `Bundle.module` inside
  `KadoCore` resolves consistently across processes, so the font
  registration code is callable from the widget too — **but we're
  not calling it from the widget** per Q5 decision. Still, check
  that the widget doesn't silently pull the font asset into its
  bundle and regress the widget extension size.
- **`UINavigationBarAppearance` dynamic color under `.withAlphaComponent`**.
  Confirm light↔dark toggle at runtime actually re-resolves the
  nav background color. If the first paint is correct but a live
  trait change doesn't update, we'll need to re-apply appearance
  on `UITraitCollection` change — possible but ugly.
- **CloudKit**. No schema change = no CloudKit risk. `CloudKitShapeTests`
  and `KadoSchemaTests` should stay green without touching.

## Risks and mitigation

| Risk | Signal | Mitigation |
|---|---|---|
| `UITableView.appearance(whenContainedInInstancesOf:)` is a no-op and Forms stay gray | Settings tab still shows iOS default background after Task 3 | Already dropped from the modifier. If Forms still look wrong, add `.scrollContentBackground(.hidden).background(Color.kadoBackground)` per-Form (Settings, New Habit). |
| Nav bar large title doesn't update on light↔dark trait change | Toggle Dark Appearance in simulator; nav bar stays one tone | Wrap appearance config in a `UITraitCollection` change observer, or set `UINavigationBar.appearance()` on every `sceneWillEnterForeground`. |
| Fraunces metrics look off at the default 34pt nav bar size | Large titles look cramped or too airy | Adjust the `UIFont(name: "Fraunces-Regular", size: 34)` literal — try 32 or 36. |
| App icon auto-generated dark + tinted look muddy | Settings → Display & Brightness → Dark, or Settings → Wallpaper → tinted — icon reads poorly | Mitigation is out of scope (Q6 deferred). Note in compound, fix in v1.0. |
| Widget dark mode paper looks too close to iOS's native widget surface | Home widget blends into other widgets with `.fill.tertiary` | If the contrast is wrong, lift widget background to `kadoPaper50` (matches main app) instead of `kadoPaper100`. |
| Existing widget preview snapshots break (`PreviewSnapshots.swift`) | Widget SwiftUI previews crash | Update snapshot fixture colors if necessary; snapshots are illustrative, not persistence. |

## Open questions

- [ ] Nav bar large title reads slightly thin at Fraunces-Regular
      34pt. Acceptable for v0.2; revisit if we upgrade to the
      `safeAreaInset` path or bump to Fraunces-Medium later.

## Notes during build

- **Task 2 — Info.plist `UIAppFonts` is not required** when the
  TTF lives inside a Swift package's resource bundle and is loaded
  at runtime via `CTFontManagerRegisterFontsForURL` + `Bundle.module`.
  The hand-off's README instructed to add `UIAppFonts` — that only
  applies when the font ships at the main-app bundle root, which is
  not our case. Skipped; nothing broke.
- **Task 2 — `nonisolated static var didRegister` is not Swift 6
  clean**. Switched to the `static let registration: Void = { … }()`
  idiom — Swift guarantees once-semantics for static `let`, no lock
  or isolation annotation needed. Same pattern applied to
  `KadoThemeModifier`'s `ApplyOnce`.
- **Task 6 — `magick` can't rasterize SVG without `librsvg`**, which
  isn't installed locally. `qlmanage -t -s 1024` handles SVG
  natively via macOS QuickLook and produced the 1024×1024 PNG in
  one call. Documented for future icon passes.
- **Task 7 — the polish sweep found six files** still referencing
  `Color(.secondarySystemBackground)` or `Color(.tertiarySystemFill)`.
  These were painting iOS's default gray on top of the new paper
  surface. Converted to `kadoBackgroundSecondary` / `kadoHairline`
  / `kadoPaper200`. `.primary` / `.secondary` foregrounds left
  alone — they auto-adapt fine.
- **Task 7 — visual audit is Today-tab only**. Tap/type/gesture
  primitives aren't enabled on this XcodeBuildMCP install, and the
  app doesn't have a URL scheme for Overview / Settings / Detail,
  so `screenshot` can't reach those surfaces without hands-on
  simulator interaction. The polish commits are confident on
  token-level consistency but would benefit from a manual
  walk-through before merging.

## Out of scope

- Overview layout redesign (score ring + tiles + mini-matrix).
- HabitDetail layout redesign (hero + tiles + mini-matrix + reminder
  toggle).
- `HabitColor` migration from SwiftUI system colors to custom hex.
- "稼働 · in operation" Settings footer (traced SVG).
- Fraunces in widget typography.
- App icon dark + tinted hand-authored variants.
- Watch app, Live Activities, widget intent mutations.
- `UINavigationBar` dynamic-type large-title behavior beyond the
  default.
- Any `@Model`, schema, or CloudKit surface change.
