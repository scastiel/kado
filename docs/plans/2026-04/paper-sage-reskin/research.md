# Research — Paper / sage re-skin (handoff from Claude Design)

**Date**: 2026-04-19
**Status**: ready for plan
**Related**:
- Handoff source: `/Users/sebastien/Downloads/design_handoff_kado_reskin/`
  (README, SKILL, `swift_patches/`, `assets/`, `ui_kits/ios/`)
- Roadmap context: `docs/ROADMAP.md` — v0.3 polish tier; the handoff
  accelerates the "Core themes" item currently parked in v1.0.
- Prior relevant work: `docs/plans/2026-04/dark-mode/` (first dark
  adaptation of the current palette), `docs/plans/2026-04/widgets/`
  (current widget surfaces).

## Problem

Kadō currently ships the default iOS chrome: system blue tint, system
grouped-list backgrounds, SF Pro everywhere. The author (solo dev,
also user-0) has commissioned a design-identity pass from Claude
Design. The output: a paper-surfaces + sage-accent + Fraunces-display
system, captured as authoritative tokens, three new Swift files, a
5-line patch sketch for `HabitRowView`, production-ready SVG brand
assets (ensō mark, wordmark, app icon), and an HTML prototype of the
three main tabs.

"Moderate adoption" is the explicit intent: keep SF Pro for body
chrome, keep SF Symbols, keep SwiftUI navigation — swap tint / fill /
large-title font only. The handoff's stated target effort is
30–60 minutes; the three open questions in the handoff plus the
divergences between the mock and the current code (detailed below)
push that closer to a half-day if we include widget and app-icon
refresh.

**Scope (confirmed with user)**: ship the full re-skin + the widget
re-skin + the new app icon in one PR. Take the lowest-effort path
for chrome — `KadoThemeModifier` + `UINavigationBarAppearance`, not
per-screen `safeAreaInset` titles.

## Current state of the codebase

### Targets and layering
- Main app: `Kado/` with `App/KadoApp.swift` (SwiftUI `App` entry,
  wires `.modelContainer`, `.environment` services, scene phase +
  dev-mode swaps).
- Shared package: `Packages/KadoCore/` — single target, iOS 18 only,
  no `resources:` yet. All `@Model` types, domain types, calculators,
  widget-snapshot types live here.
- Widget extension: `KadoWidgets/` — 6 widget surfaces (3 home, 3
  lock) sharing `HabitWidgetCell`, all using
  `.containerBackground(.fill.tertiary, for: .widget)` for the home
  sizes and `.clear` for the lock sizes.
- Tests: `KadoTests/` (Swift Testing).

### Files the re-skin touches
| Area | Current | Re-skin impact |
|---|---|---|
| `Kado/App/KadoApp.swift` | Wires env + model container | Add `KadoFont.register()` in `init`; add `.kadoTheme()` on the root `ContentView` |
| `Kado/Views/ContentView.swift` | `TabView` with 3 tabs | Apply `.kadoTheme()` |
| `Kado/Views/Today/TodayView.swift` | `NavigationStack { List(due) { … } }` with `.navigationTitle("Today")` | Tint + background inherited from root; large title font inherited via `UINavigationBarAppearance.largeTitleTextAttributes` (Fraunces-Regular 34pt). No structural change. |
| `Kado/Views/Overview/OverviewView.swift` | Horizontal-scroll habits × days matrix (v0.2 spec) | **Divergence**: handoff describes a different layout — centered 180pt score ring + two metric tiles + 28-day mini-matrix. See Q1 below. |
| `Kado/Views/Settings/SettingsView.swift` | `Form { SyncStatusSection; NotificationsSection; BackupSection; DevModeSection }` | Tint + background inherited; optional "稼働 · in operation" SVG footer (Q4). |
| `Kado/Views/HabitDetail/HabitDetailView.swift` | Scroll view: header · metrics row · quick-log · `MonthlyCalendarView` · `CompletionHistoryList` | **Divergence**: handoff describes a different layout — hero row (54pt badge + Fraunces name) + two metric tiles + "Last 28 days" mini-matrix + reminder section. See Q2 below. |
| `Kado/UIComponents/HabitRowView.swift` | 478 LOC — badge / name / metrics / type-aware trailing | 5 small edits per handoff patch sketch: name font, metrics color, ring animation constant, row background + corner radius. Badge stays. |
| `Kado/UIComponents/MetricsChip.swift` | (to verify) | Flame emoji stays orange regardless of habit accent — handoff red line. |
| `Kado/Resources/Assets.xcassets/AppIcon.appiconset/` | Empty (Contents.json only, no PNG) | Generate 1024×1024 PNG from `assets/kado-app-icon.svg`; drop into Xcode's single-image AppIcon slot. |
| `Kado/Resources/Assets.xcassets/AccentColor.colorset/` | Empty Contents.json | Either populate with sage, or let `.kadoTheme()`'s `.tint(.kadoSage)` take over — they should agree. |
| `KadoWidgets/*.swift` | `.containerBackground(.fill.tertiary, for: .widget)` across 6 files | Swap to `Color.kadoBackgroundSecondary` (home) or keep `.clear` (lock). Sage tint inherits via widget target linking `KadoCore`. |
| `KadoWidgets/Assets.xcassets/WidgetBackground.colorset/` | Exists | May repoint to kadoBackgroundSecondary, or leave alone if we set color programmatically. |
| `Packages/KadoCore/Package.swift` | No `resources:` | Add `resources: [.process("Resources")]` to the target. |
| `Packages/KadoCore/Sources/KadoCore/Resources/Fonts/` | Does not exist | Create; drop `Fraunces[SOFT,WONK,opsz,wght].ttf` (~800 KB, SIL OFL). |
| `Packages/KadoCore/Sources/KadoCore/Design/` | Does not exist | Create; add `Theme.swift`, `KadoFont.swift`, `KadoThemeModifier.swift`. |
| `Kado/Info.plist` | No `UIAppFonts` entry | Add `Fraunces[SOFT,WONK,opsz,wght].ttf`. |
| `Kado/Resources/Localizable.xcstrings` | — | No new keys expected in this pass. |

### Current `HabitColor` and the handoff palette

`Packages/KadoCore/Sources/KadoCore/Models/HabitColor.swift` maps the
8 habit accents to SwiftUI's **system** colors (`.red`, `.orange`,
`.yellow`, …). The handoff's red-line in README.md line 157–160 says:

> Habit accents (preserved verbatim from HabitColor.swift — do NOT
> change) / red `#D9534A` · orange `#E07A3C` · yellow `#D9A93A` ·
> green `#4F9F6B` · mint `#5FBDA3` · teal `#3F9CA8` · blue `#4A7FB8`
> · purple `#8A6FB5`

Those hex values don't match SwiftUI's system colors (system red is
~`#FF3B30`, system orange `#FF9500`, etc.) — the handoff authored the
web mocks against the hex palette but documented them as if they
already lived in the codebase. **They don't.** See Q3.

## Proposed approach

Single PR with seven atomic commits, each independently buildable and
revertable. Order is chosen so the app is visually coherent at each
step (not "half-re-skinned" at any commit):

1. **Package plumbing + tokens**: add `Design/Theme.swift`, wire
   `resources:` on `KadoCore`, populate `AccentColor.colorset` with
   sage so Xcode Previews pick it up immediately.
2. **Fraunces registration**: add `Design/KadoFont.swift`, drop the
   TTF under `Resources/Fonts/`, add `UIAppFonts` in `Info.plist`,
   call `KadoFont.register()` in `KadoApp.init`.
3. **Root theme application**: add `Design/KadoThemeModifier.swift`,
   apply `.kadoTheme()` on `ContentView`. At this point every screen
   is sage on paper with Fraunces large titles via nav bar
   appearance.
4. **HabitRow tokenization**: apply the 5-point patch. Keep its
   shape + a11y + previews intact.
5. **Widget re-skin**: swap `.containerBackground(.fill.tertiary)` →
   `Color.kadoBackgroundSecondary` for home widgets; leave lock
   widgets on `.clear`. Verify snapshot preview.
6. **App icon**: generate 1024×1024 PNG from `kado-app-icon.svg`,
   drop into `AppIcon.appiconset`. Generate dark + tinted variants
   per `Contents.json`.
7. **Tests + verification**: add a smoke test that `KadoFont.register`
   is idempotent; update dark-mode snapshot preview expectations if
   any. Run `build_sim`, `test_sim`, screenshot each tab (light +
   dark).

### Key components

- **`Color.kado*` tokens** — single source of truth, authored in
  `Design/Theme.swift`. Dynamic light/dark via
  `Color(UIColor { trait in … })`. Public so the widget extension
  (which links `KadoCore`) can reach them.
- **`KadoRadius`, `KadoSpace`, `KadoMotion`** — value-less enums
  exposing CGFloat / Animation constants.
- **`Font.kado(.display, size:)` + `.kadoDisplay(size:)` / `.kadoEyebrow()`**
  — convenience view modifiers for the three display-serif moments
  (Today/Overview/Settings titles, HabitDetail hero name, Overview
  score number) and the uppercase mono micro-label.
- **`KadoThemeModifier`** — applies `.tint(.kadoSage)`,
  `.background(Color.kadoBackground)`, `.scrollContentBackground(.hidden)`,
  and the one-shot `UINavigationBarAppearance` / `UITabBarAppearance`
  override. Called once from `ContentView`'s body.

### Data model changes

None. This is a style-only pass. No `@Model` edits, no schema bump,
no migration stage, no CloudKit surface change, no App Group data
shape change. The existing v0.2 widget-snapshot JSON does not change
and we intentionally keep it that way so the widget extension doesn't
ship with a new schema in the same PR as the re-skin.

### UI changes

Cosmetic only, at token-swap depth. See Q1/Q2 for the two layout
questions where the handoff mock and the current code diverge.

### Tests to write

- `@Test("KadoFont register is idempotent and tolerant of missing TTF")`:
  call `register()` twice, assert no crash; use a debug hook or just
  exercise the `didRegister` short-circuit path.
- No new tests for the `HabitRowView` patch (the row is style-only at
  this level; existing row tests stay green).
- `@Test("KadoTheme exposes sage as process tint")` is **not worth
  writing** — too tautological; the visual screenshot is the test.
- Keep the `CloudKitShapeTests`, `KadoSchemaTests`, etc. passing —
  zero change to the data layer means they should be untouched.

## Alternatives considered

### Alternative A: per-screen `safeAreaInset` titles instead of nav bar appearance

Lets us match the mock precisely — Fraunces 40pt with `opsz 48` and
`-0.015em` letter-spacing, date eyebrow below, shared across all three
tabs. Trade-off: we lose the native collapsing-title behavior (large
→ inline on scroll), which is a non-trivial UX regression on long
lists. More code (per-screen inset + spacer + hide-default-title),
more bugs (scroll offset sync, safe-area math under keyboards).

**Rejected** per user's "do the easiest" call on question #3.

### Alternative B: handoff-mock Overview layout (score ring + tiles + matrix)

The mock's Overview is a centered 180pt score ring + two metric tiles
+ per-habit mini-matrix. Kadō's current Overview is the v0.2
horizontal-scroll habits × days matrix that already serves a
different, more-utilitarian purpose (scrub back through 28 days to
log / inspect a past cell). Replacing it would delete a feature
shipped two PRs ago.

**Deferred** — see Q1.

### Alternative C: update `HabitColor` to the handoff hex palette

The handoff mocks assume custom hex accents. Switching to them makes
the in-app badges match the printed mock exactly, at the cost of
every user's existing habit colors shifting slightly on upgrade.

**Deferred** — see Q3.

### Alternative D: full app-icon multi-size set instead of single 1024

iOS 18 supports single-image AppIcon slots (one 1024×1024 does the
job), but classic multi-size sets are still supported. Single-image
is simpler and matches the current `Contents.json` layout.

**Accepted.**

## Risks and unknowns

1. **`UITableView.appearance(whenContainedInInstancesOf: [UIHostingController<AnyView>.self])`
   is likely a no-op in production.** SwiftUI wraps root views in
   generic hosting controllers like
   `UIHostingController<ModifiedContent<…>>`, not
   `UIHostingController<AnyView>`. The appearance override probably
   never matches. We rely on `.scrollContentBackground(.hidden) +
   .background(Color.kadoBackground)` on `Form` / `List` for the
   actual effect. Will verify via screenshot; if Settings Form still
   shows system gray, swap to the global `UITableView.appearance()`
   or add `.scrollContentBackground(.hidden)` per-Form.
2. **Dynamic `UIColor` under `.withAlphaComponent(_:)`**. The nav and
   tab bar appearance use
   `UIColor(Color.kadoBackground).withAlphaComponent(0.85)`. On iOS
   18, `.withAlphaComponent` on a dynamic `UIColor` preserves the
   dynamic provider — so light / dark still swap correctly. Confirm
   with a live light↔dark toggle during verification.
3. **Fraunces bundle cost**. The variable TTF is ~800 KB.
   Acceptable for a zero-third-party app; still the biggest single
   asset we've shipped. Worth noting in the PR description.
4. **Widget background in dark mode**. Current widgets use
   `.fill.tertiary`, which auto-adapts. Paper-100 dark is `#1C1A16`
   — warm near-black. Need to verify widget timeline snapshots look
   right against both the user's iOS 18 wallpapers (light backing,
   dark backing, photo) and the system's tinted-icon rendering mode.
5. **App icon tinted / dark variants**. The handoff ships one SVG.
   iOS 18 expects three 1024×1024 PNGs (light, dark, tinted). We'll
   need to produce the dark and tinted variants ourselves, or accept
   Apple's auto-generated versions from the single light icon. Auto
   is fine for v0.2; a real pass lands in v1.0.
6. **Simulator availability** for the final screenshots. On the
   current toolchain iPhone 17 Pro is the practical default (iPhone
   16 Pro isn't pre-installed). Note the substitution in compound.
7. **Pixel-faithful metrics vs. `UINavigationBarAppearance`
   constraints**. The mock specifies Fraunces 40pt with `opsz 48`
   and specific letter-spacing for the large title. `UINavigationBarAppearance`
   can set the font (Fraunces-Regular 34pt per the handoff modifier),
   but not `opsz` or letter-spacing on the variable axes. This is
   the known cost of the "easiest" path. Acceptable per user
   direction; if the result looks off, we revisit.

## Resolved questions

All six open questions were resolved in favor of the recommendations
on 2026-04-19. Recorded here verbatim so the plan stage can treat them
as decided scope.

- [x] **Q1 — Overview layout.** Decision: **keep the v0.2 horizontal-
  scroll matrix; re-tint only.** The layout redesign is a future PR,
  not part of the re-skin.
- [x] **Q2 — HabitDetail layout.** Decision: **keep the current
  layout; re-tint only.** No hero-row / mini-matrix restructure in
  this pass.
- [x] **Q3 — `HabitColor` palette.** Decision: **keep SwiftUI system
  accents.** The handoff's hex palette is deferred to a v1.0 identity
  audit; touching 8 habit accents mid-re-skin is scope creep and
  would visibly shift every existing user's stored colors on upgrade.
- [x] **Q4 — "稼働 · in operation" footer.** Decision: **defer.** Not
  shipped in this PR; revisit with the full About screen.
- [x] **Q5 — Widget re-skin depth.** Decision: **background + tint
  only.** No Fraunces in widget digits this pass.
- [x] **Q6 — App-icon variants.** Decision: **ship single light
  1024×1024; let iOS auto-generate dark + tinted.** Hand-authored dark
  and tinted variants wait for v1.0 submission polish.

## References

- Handoff bundle README: `/Users/sebastien/Downloads/design_handoff_kado_reskin/README.md`
- Handoff iOS migration guide: `/Users/sebastien/Downloads/design_handoff_kado_reskin/swift_patches/README.md`
- Handoff tokens (authoritative hex values): `/Users/sebastien/Downloads/design_handoff_kado_reskin/colors_and_type.css`
- Handoff Swift patches: `/Users/sebastien/Downloads/design_handoff_kado_reskin/swift_patches/{Theme,KadoFont,KadoThemeModifier}.swift`
- Fraunces font (SIL OFL): <https://fonts.google.com/specimen/Fraunces>
- HIG — Apps — Widgets: <https://developer.apple.com/design/human-interface-guidelines/widgets>
- HIG — Apps — App icons: <https://developer.apple.com/design/human-interface-guidelines/app-icons>
- Prior dark-mode adaptation work: `docs/plans/2026-04/dark-mode/`
