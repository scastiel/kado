# Plan — Paper/sage re-skin: polish follow-up

**Date**: 2026-04-19
**Status**: ready to build
**Source PR**: [#17 (merged)](https://github.com/scastiel/kado/pull/17)

## Summary

Three small follow-ups from the PR-17 walkthrough that were deferred
as non-blocking: a proper dark-mode app-icon variant, a branded
launch screen (ensō on paper instead of iOS auto white/black), and
the hand-off's "稼 働 ・ in operation" inscription at the bottom of
the Settings tab. One PR, three commits, no data-layer change.

## Decisions locked in

- **Dark app icon**: produce a second 1024×1024 PNG (warm-dark paper background + lighter-sage ensō) and drop into the AppIcon's dark slot. Tinted slot stays iOS-auto-generated (deferred to v1.0).
- **Launch screen**: use the declarative `INFOPLIST_KEY_UILaunchScreen_*` build settings rather than a storyboard. Background color from the asset catalog (AccentColor or a dedicated `LaunchBackground`), centered image = ensō mark.
- **Inscription**: plain SwiftUI `Text("稼 働 ・ in operation")`. iOS renders kanji via the system's native font-fallback chain (Hiragino Mincho Pro, etc.) — no Noto Serif JP bundle needed. Handoff concern about "don't bundle Noto Serif JP" applies to web, not iOS.
- **Location**: Settings tab only (per user answer). Rendered as a `Section` footer below DevModeSection, or as a free `VStack` at the bottom of the Form — whichever lands cleaner.

## Task list

### Task 1: Dark app icon

**Goal**: Dark-mode home-screen icon renders in warm-near-black + sage, matching the dark-mode palette.

**Changes**:
- `branding/kado-app-icon-dark.svg` — new SVG, swap `#FBF8F2→#F0E8D8` gradient for `#14130F→#1C1A16`, swap ensō stroke `#355944` for `#9EBEA9` (kadoSage dark).
- Rasterize via `qlmanage -t -s 1024` → `Kado/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-Dark.png`.
- Update `AppIcon.appiconset/Contents.json`: add `"filename": "AppIcon-Dark.png"` to the dark-appearance entry.

**Verification**:
- `build_run_sim`, toggle simulator appearance to dark, go to home screen, confirm the icon reads in warm tones (not inverted cream).

**Commit message**: `feat(reskin): dark-mode app icon variant`

---

### Task 2: Branded launch screen

**Goal**: Cold launch shows the ensō mark on paper-50 (light) or paper-50-dark (dark) instead of iOS's auto white/black splash.

**Changes**:
- Add `LaunchMark.imageset` under `Kado/Resources/Assets.xcassets/` containing a PDF or PNG of the ensō mark (single-color, iOS renders the asset-catalog tint if applicable).
- Add `LaunchBackground.colorset` with paper-50 light + paper-50 dark (same hex values as `kadoPaper50`).
- In `Kado.xcodeproj/project.pbxproj`, add both config blocks:
  - `INFOPLIST_KEY_UILaunchScreen_BackgroundColor = LaunchBackground;`
  - `INFOPLIST_KEY_UILaunchScreen_Image = LaunchMark;`
- The existing `INFOPLIST_KEY_UILaunchScreen_Generation = YES` stays — it's what allows the other keys to drive the launch screen without a storyboard.

**Verification**:
- Fully kill + cold-launch the app. Launch screen should flash paper + ensō briefly before the first view loads.
- Toggle dark mode and cold-launch again — background should be warm-dark, mark should adapt.

**Commit message**: `feat(reskin): branded launch screen (ensō on paper)`

---

### Task 3: 稼 働 ・ in operation inscription

**Goal**: Render the Japanese wordmark at the bottom of the Settings tab.

**Changes**:
- In `Kado/Views/Settings/SettingsView.swift`, add a trailing block below `DevModeSection()`:
  ```swift
  Section {
      EmptyView()
  } footer: {
      Text("稼 働 ・ in operation")
          .font(.system(size: 13, design: .serif))
          .tracking(2.0)  // matches 0.16em @ 13pt ≈ 2.08pt
          .foregroundStyle(Color.kadoForegroundTertiary)
          .frame(maxWidth: .infinity, alignment: .center)
          .padding(.vertical, 24)
          .accessibilityLabel("Kadō — in operation")
  }
  .listRowBackground(Color.clear)
  ```
  (or move to a `VStack` tail if a footer-only `Section` renders awkwardly).
- The `accessibilityLabel` keeps VoiceOver sensible — without it, VoiceOver would try to pronounce 稼働 in English phonetics, which is bad UX.
- String catalog entry: the literal "稼 働 ・ in operation" goes through `LocalizedStringKey` — add to `Localizable.xcstrings` with an English-catalog entry and a comment.

**Verification**:
- Settings tab, scroll to bottom, kanji + "in operation" render in the system serif at tertiary ink tone.
- VoiceOver announces "Kadō — in operation" instead of trying to read the kanji.

**Commit message**: `feat(reskin): 稼 働 ・ in operation footer on Settings`

---

## Out of scope

- Hand-authored tinted app-icon variant (still iOS-auto-generated).
- Inscription on Today / Overview / Habit Detail (Settings only per user).
- Re-visiting the nav bar Fraunces-Regular 34pt thinness.
- Extracting `.kadoSurface()` / `.kadoSectionCard()` helpers (separate refactor PR).
- Tightening `KadoFontTests.registerIdempotent`.
