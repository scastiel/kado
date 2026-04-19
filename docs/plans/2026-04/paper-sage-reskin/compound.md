# Compound — Paper / sage re-skin

**Date**: 2026-04-19
**Status**: complete
**Research**: [research.md](./research.md)
**Plan**: [plan.md](./plan.md)
**Branch / PR**: [feature/paper-sage-reskin](https://github.com/scastiel/kado/pull/17)

## Summary

Applied the Claude Design paper-surfaces + sage-accent + Fraunces
hand-off to the iOS app in 13 commits on one branch, no schema or
CloudKit change. The headline lesson is that most of the debugging
happened *after* the plan's "build is done" checkpoint — three
visual bugs (nav bar tone mismatch, sheets not inheriting theme,
Today/Overview not matching Settings) only showed up during the
hands-on simulator walkthrough. Every one of them was a quirk in
how `.kadoTheme()` does (or doesn't) propagate through SwiftUI's
presentation boundaries. Token plumbing is easy; presentation
topology is where the subtlety lives.

## Decisions made

- **Chrome path is `UINavigationBarAppearance` + `.kadoTheme()` root modifier**: the lowest-effort option the hand-off suggested. `safeAreaInset`-per-screen titles deferred.
- **Keep current Overview and HabitDetail layouts**: re-tint only; no hero-row / mini-matrix / score-ring rework. Layouts are working product, not design debt.
- **`HabitColor` stays on SwiftUI system accents**: custom hex palette deferred to v1.0 identity audit. Touching 8 accents mid-re-skin would shift every user's stored colors on upgrade.
- **Widgets get background + tint swap only**: no Fraunces in widget digits. Lock widgets keep `.clear` so the system's lock-screen glass handles itself.
- **App icon ships one light 1024×1024 variant**: iOS auto-generates dark + tinted. Hand-authored variants wait for v1.0 App Store polish.
- **Fraunces TTF lives in `KadoCore/Resources/Fonts/`, not `Kado/`**: package-level resource bundle lets widget + future watch target reuse the registration path if we ever want to.
- **Drop the `UITableView.appearance(whenContainedInInstancesOf: [UIHostingController<AnyView>.self])` line from the hand-off sketch**: SwiftUI's hosting controllers are generic over concrete types, not `AnyView` — the override would never match.
- **`configureWithDefaultBackground()` beats `configureWithTransparentBackground()` + explicit tint** for the final nav bar config: the latter had a UIKit quirk where alpha 1.0 suppressed the large title.
- **Switch from `static var didRegister` to `static let registration: Void = { … }()`** for idempotent init: Swift 6 concurrency-clean without locks or `nonisolated(unsafe)`. Same pattern applied to `KadoThemeModifier.ApplyOnce`.

## Surprises and how we handled them

### Fraunces TTF download is automatable

- **What happened**: The hand-off instructed "user downloads from Google Fonts → unzip → copy TTF." The plan listed this as a user prerequisite. But Google Fonts files are mirrored on the `google/fonts` GitHub repo.
- **What we did**: `curl -sL` directly from `raw.githubusercontent.com/google/fonts/main/ofl/fraunces/Fraunces%5B…%5D.ttf` — no zip, no browser, no manual step. 352 KB in one request.
- **Lesson**: Open-source Google Fonts are always in the GH repo. Worth documenting as the default download path in future font-bundling work.

### `UIAppFonts` Info.plist entry was a red herring

- **What happened**: Hand-off README and `swift_patches/KadoFont.swift` both said to add `<key>UIAppFonts</key><array>…</array>` to Info.plist.
- **What we did**: Skipped it. Fonts bundled in an SPM resource and registered at runtime via `CTFontManagerRegisterFontsForURL(Bundle.module.url(forResource:…), .process, …)` don't need `UIAppFonts` — that key is for fonts iOS should load automatically from the main app bundle.
- **Lesson**: `UIAppFonts` is only required when the font file is a direct main-app-bundle resource. Runtime-registered fonts from SPM packages skip it.

### Swift 6 and mutable static state

- **What happened**: Initial `KadoFont.swift` had `private static var didRegister = false` — Swift 6 mode rejects this as "nonisolated global shared mutable state not concurrency-safe."
- **What we did**: Replaced with `private static let registration: Void = { … }()`. Swift guarantees `static let` initialization runs exactly once, thread-safe. Same idiom applied to `KadoThemeModifier.ApplyOnce`.
- **Lesson**: The Swift 6 idiom for idempotent process-level init is `static let X: Void = { body() }()` + a no-op accessor that touches it. Cleaner than `nonisolated(unsafe)` or an actor for this shape of problem.

### `configureWithTransparentBackground()` + opaque `backgroundColor` suppresses large title

- **What happened**: Walkthrough showed the nav bar was visibly lighter than content below (alpha 0.85 compositing over white). Bumping alpha to 1.0 made the backgrounds match but the large "Today" title disappeared entirely.
- **What we did**: Switched to `configureWithDefaultBackground()` with no `backgroundColor` override at all. Kept only `titleTextAttributes` + `largeTitleTextAttributes` for Fraunces + ink color. System's blur material composites cleanly onto paper-50; no seam, title renders.
- **Lesson**: If you want system-native nav/tab bar behavior but with custom typography, `configureWithDefaultBackground()` + typography overrides is the primitive. `configureWithTransparentBackground()` + `backgroundColor` has weird internal transitions at alpha = 1.0.

### Sheets don't inherit `.kadoTheme()`

- **What happened**: New Habit sheet rendered on iOS's default gray Form background with white row cards, even though `.kadoTheme()` was applied at `ContentView` root.
- **What we did**: Added explicit `.scrollContentBackground(.hidden) + .background(Color.kadoBackground.ignoresSafeArea())` + per-`Section` `.listRowBackground(Color.kadoBackgroundSecondary)` to every Form-containing sheet (NewHabit, CounterLog, TimerLog) and the Settings tab itself.
- **Lesson**: SwiftUI sheet presentations are a fresh environment root — inherited environment values propagate but structural modifiers (tint, background, scrollContentBackground) don't. Every sheet's Form needs its own surface wiring.

### `.kadoTheme()` doesn't cascade through child NavigationStacks either

- **What happened**: Today and Overview still painted on iOS gray because their internal `List` / `ScrollView` sits inside a tab's `NavigationStack`, which breaks `.scrollContentBackground(.hidden)` propagation from the TabView root.
- **What we did**: Applied the same explicit pair (`.scrollContentBackground(.hidden)` + `.background(Color.kadoBackground)`) directly on `TodayView`'s `List` and `OverviewView`'s outer `ScrollView`.
- **Lesson**: `.scrollContentBackground(.hidden)` is a scroll-view-level modifier and must be applied to the scroll view or to a view that will eventually contain it in the same modifier scope. It does not reliably propagate through a child `NavigationStack`.

### `qlmanage` rasterizes SVG without librsvg

- **What happened**: `magick -background none -resize 1024x1024 kado-app-icon.svg AppIcon.png` failed with "no images found" — ImageMagick needs `librsvg` for SVG, and it's not installed locally.
- **What we did**: Used macOS's `qlmanage -t -s 1024 -o <dir> kado-app-icon.svg`. QuickLook handles SVG natively. One command, 1024×1024 RGBA PNG output.
- **Lesson**: For one-off SVG→PNG rasterization on macOS, `qlmanage -t -s <N>` is the no-dependencies path. Cleaner than installing the ImageMagick→librsvg chain.

### Visual audit has a tap gap

- **What happened**: XcodeBuildMCP's default install doesn't enable tap/type/gesture primitives. `screenshot` only ever reaches the launched screen. Kadō also doesn't expose a URL scheme for Overview or Settings tabs. Net effect: I could verify Today tab + home screen via MCP but nothing else programmatically.
- **What we did**: Relied on hands-on walkthrough — which is exactly when three visual bugs surfaced (commits `e85c211`, `481b68e`, `033ca61`).
- **Lesson**: Already documented in `CLAUDE.md` under XcodeBuildMCP limitations. Reinforces that the user walk-through is load-bearing, not a formality. For design-heavy PRs, budget time for a post-build visual pass — it's where half the real bugs are caught.

## What worked well

- **Conductor stages**. Writing `research.md` before touching code surfaced the 3→6 open-questions jump and the `HabitColor`-palette contradiction in the hand-off before either could cause damage mid-build.
- **Seven atomic commits** rather than one big "re-skin" blob. Every commit builds; every commit has an isolatable revert path.
- **Fraunces-download automation** (curl from google/fonts GH). Shaved ~15 min off the prerequisite phase.
- **`static let X: Void = { … }()` idempotence idiom.** Swift 6 clean, zero boilerplate, used twice in this PR.
- **Screenshot-driven verification, even when partial.** The Today + home-screen shots caught visible issues early; the hands-on walkthrough caught the rest.

## For the next person

- **Do not re-introduce `configureWithTransparentBackground()` + opaque `backgroundColor`** in `KadoThemeModifier`. It mysteriously suppresses the large title. If you need the bar to match content exactly, use `configureWithDefaultBackground()` and accept the system blur — in practice it disappears against paper.
- **Every new Form / sheet needs its own `.scrollContentBackground(.hidden) + .background(Color.kadoBackground)` pair** + per-Section `.listRowBackground(Color.kadoBackgroundSecondary)`. `.kadoTheme()` at the TabView root does not cascade to sheets or through child NavigationStacks. A `.kadoSurface()` / `.kadoSectionCard()` helper is on the follow-up list (see review).
- **`HabitColor` stores SwiftUI system accents** (`.red`, `.orange`, …), *not* the hex values the hand-off README claims. The hand-off was wrong about the repo's current state. If you ever migrate to custom hex, every user's stored color shifts — plan a migration note and pick a release that tolerates that.
- **Fraunces is registered from `KadoCore`'s bundle via `Bundle.module`**, not the main app bundle. Do not add `UIAppFonts` to `Info.plist` — it's redundant for SPM-bundled fonts registered at runtime.
- **App icon dark + tinted slots are empty by design.** iOS auto-generates them. Re-verify before App Store submission; auto-generated tinted on a two-color icon is acceptable, auto-generated dark can look muddy.
- **The nav bar large title uses Fraunces-Regular at 34pt**, which reads slightly thin vs. the hand-off's 40pt/opsz48/-0.015em spec. Known limitation — `UINavigationBarAppearance` can set the font but not variable-axis `opsz` or letter-spacing. If it needs fixing, the upgrade is `safeAreaInset`-per-screen titles (plan's Alternative A).
- **Flame in `MetricsChip` stays `Color.orange`** regardless of habit accent. Hand-off red line. Do not tint it via `habit.color`.
- **`NegativePillStyleModifier` uses `.tint(.red)`** (system red), not `kadoSage` or `habit.color`. "Slipped" intentionally reads distinct from positive habits.

## Generalizable lessons

- **[→ CLAUDE.md]** *Swift 6 idempotent init idiom.* For process-scoped one-shot registration (font loading, appearance config), prefer `private static let registration: Void = { body() }()` + a trivial `public static func register() { _ = registration }` accessor. Thread-safe by construction, Swift 6 clean, no locks, no `nonisolated(unsafe)`. Canonical examples: `KadoFont.register`, `KadoThemeModifier.applyUIKitAppearance`.
- **[→ CLAUDE.md]** *`.scrollContentBackground(.hidden)` + `.background(_:)` must be applied at the scroll view, not at the app root.* It does not cascade through `NavigationStack` or sheet boundaries. Every `List` / `Form` / `ScrollView` that wants the paper surface needs its own pair. Canonical pattern in `TodayView`, `OverviewView`, `SettingsView`, `NewHabitFormView`, etc.
- **[→ CLAUDE.md]** *Sheet presentations are a fresh SwiftUI environment root for structural modifiers.* Inherited env values propagate; tint, background, and scroll modifiers don't. Every sheet-hosted view needs its own `.kadoTheme()` / surface wiring.
- **[→ CLAUDE.md]** *Bundled fonts via SPM resources don't need `UIAppFonts` in Info.plist.* Register at runtime via `CTFontManagerRegisterFontsForURL(Bundle.module.url(…), .process, _)` and SwiftUI `Font.custom` / UIKit `UIFont(name:size:)` resolve them. Canonical: `KadoFont.swift`.
- **[→ CLAUDE.md]** *`UITableView.appearance(whenContainedInInstancesOf: [UIHostingController<AnyView>.self])` is a false lead.* SwiftUI's hosting controllers specialize over concrete types, not `AnyView`, so this appearance override never matches in production. Drop it when you see it in hand-off sketches.
- **[→ CLAUDE.md / tooling]** *`qlmanage -t -s <N> -o <dir> <file.svg>`* rasterizes SVG natively on macOS without `librsvg`. Good one-liner for app-icon generation when ImageMagick isn't set up.
- **[→ ROADMAP.md]** *Re-visit the nav-bar large-title typography.* Fraunces-Regular at 34pt via `UINavigationBarAppearance` reads slightly thin vs. the 40pt/opsz48 spec. Upgrade path: `safeAreaInset`-per-screen titles (research's Alternative A) — accept more code in exchange for variable-axis control.
- **[local]** The hand-off claimed `HabitColor.swift` already used custom hex accents; the repo actually uses SwiftUI system colors. Scope question Q3 was resolved in favor of keeping system colors for this PR; a v1.0 custom-hex migration is a follow-up.
- **[local]** App icon dark + tinted variants are iOS-auto-generated. Re-author before App Store submission.

## Metrics

- Tasks completed: 7 of 7
- Extra post-build fix commits (visual walkthrough): 3
- Tests added: 1 (thin — `KadoFontTests.registerIdempotent`)
- Commits: 13
- Files touched: 39
- Diff: +1021 / −42
- Branch lifetime: ~2 hours planned, ~3 hours actual (mostly the walkthrough-driven fixes)

## References

- Hand-off bundle: `~/Downloads/design_handoff_kado_reskin/`
- PR: <https://github.com/scastiel/kado/pull/17>
- Fraunces upstream (SIL OFL): <https://fonts.google.com/specimen/Fraunces>
- Google Fonts repo direct-download path: `https://raw.githubusercontent.com/google/fonts/main/ofl/<family>/<filename>`
- HIG — widgets: <https://developer.apple.com/design/human-interface-guidelines/widgets>
