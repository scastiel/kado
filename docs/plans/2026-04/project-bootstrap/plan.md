# Plan — Project bootstrap

**Date**: 2026-04-16
**Status**: ready to build
**Research**: [research.md](./research.md)

## Summary

Create the initial Xcode project for Kadō: one iOS app target named
`Kado` (bundle ID `dev.scastiel.kado`, display name "Kadō" with
macron, universal, iOS 18.0+), one Swift Testing unit test target
(`KadoTests`), and the folder layout declared in `CLAUDE.md`. No
business logic, no SwiftData `ModelContainer`, no CloudKit / HealthKit
/ Watch / widget scaffolding — just a buildable, testable shell that
subsequent v0.1 tasks land into.

## Decisions locked in

From the research stage, restated here so the plan is self-contained:

- Project name: `Kado` (ASCII), display name `Kadō` (macron, set via
  `CFBundleDisplayName`).
- Bundle ID: `dev.scastiel.kado`. Future CloudKit container will be
  `iCloud.dev.scastiel.kado`.
- Deployment target: iOS 18.0. Swift 5.10. SwiftUI lifecycle.
- Device family: universal (iPhone + iPad).
- `.xcodeproj` location: repo root. `Kado/` and `KadoTests/` as
  siblings.
- Test target uses **Swift Testing**, not XCTest.
- No `ModelContainer` wiring yet — the first `@Model` type (v0.1)
  introduces it.
- Folder layout matches `CLAUDE.md` exactly, even where folders start
  empty (they declare intent).
- Git: work continues on `feature/project-bootstrap`, draft
  PR [#1](https://github.com/scastiel/kado/pull/1) is already open.

## Task list

### Task 1: Install & verify XcodeBuildMCP

**Goal**: Unblock every later task by confirming the MCP tools Claude
will use to build, test, and inspect the project are connected.

**Changes**: none in-repo. User action: run the install commands from
the CLAUDE.md Tooling section (with `XCODEBUILDMCP_SENTRY_DISABLED=true`),
then `claude mcp list`.

**Tests / verification**:
- `claude mcp list` shows `XcodeBuildMCP: ... - Connected`.
- From a Claude session, tool names like `build_sim`, `test_sim`,
  `list_sims`, `discover_projs` appear in the available tool list.

**Commit message (suggested)**: no commit — external install.

---

### Task 2: Create the Xcode project with correct baseline settings

**Goal**: Produce a buildable `Kado.xcodeproj` at the repo root with
the default SwiftUI template, already configured with the bundle ID,
display name, deployment target, device family, and a Swift Testing
test target.

**Changes**:
- `Kado.xcodeproj/` at repo root.
- `Kado/KadoApp.swift`, `Kado/ContentView.swift`, `Kado/Assets.xcassets/`,
  `Kado/Preview Content/` (Xcode wizard defaults).
- `KadoTests/KadoTests.swift` (Swift Testing template).
- `Info.plist` additions: `CFBundleDisplayName = "Kadō"`, supported
  interface orientations for iPhone and iPad (Portrait +
  Landscape-Left/Right, and Portrait-Upside-Down for iPad).
- Build settings: `IPHONEOS_DEPLOYMENT_TARGET = 18.0`,
  `PRODUCT_BUNDLE_IDENTIFIER = dev.scastiel.kado`,
  `TARGETED_DEVICE_FAMILY = 1,2`, `SWIFT_VERSION = 5.10`.

**Execution path**:
- Preferred: XcodeBuildMCP's project-creation tool if one is exposed
  (e.g. `scaffold_ios_project`). If not, the human creates via Xcode's
  New Project wizard — pick "App", name "Kado", org id
  `dev.scastiel`, interface "SwiftUI", storage "None", testing system
  "Swift Testing", language "Swift". Wizard location: this repo's
  root, uncheck "Create Git repository" (the repo already exists).

**Tests / verification**:
- `build_sim` against iPhone 16 Pro simulator succeeds with zero
  warnings.
- `test_sim` runs the wizard-generated smoke test and reports 1 passed.
- App installed on the simulator shows `Kadō` (with macron) under the
  icon on the home screen.

**Commit message (suggested)**: `chore(bootstrap): create Xcode
project with baseline settings`

---

### Task 3: Apply the CLAUDE.md folder layout

**Goal**: Move and create filesystem folders so the project matches
the tree declared in `CLAUDE.md`. Folders that will start empty
(`Models/`, `ViewModels/`, `Services/`, `Managers/`, `UIComponents/`,
`Extensions/`) still get created so future contributors / future you
have an obvious home for each concern.

**Changes**:
- Move `Kado/KadoApp.swift` → `Kado/App/KadoApp.swift`.
- Move `Kado/ContentView.swift` → `Kado/Views/ContentView.swift`.
- Create empty directories: `Kado/Models/`, `Kado/ViewModels/`,
  `Kado/Services/`, `Kado/Managers/`, `Kado/UIComponents/`,
  `Kado/Extensions/`, `Kado/Resources/`, `Kado/Views/Today/`,
  `Kado/Views/Settings/`.
- Move `Kado/Assets.xcassets` → `Kado/Resources/Assets.xcassets`
  (update the asset-catalog reference in build settings if needed).
- Keep `Kado/Preview Content/` at the Kado/ root — it's referenced by
  `DEVELOPMENT_ASSET_PATHS` and Xcode expects it where the wizard put
  it.
- Each empty folder gets a `.gitkeep` file so git tracks it.

**Note on Xcode "synchronized folders"**: Xcode 16 defaults to
synchronized folder references (blue folder icon) that mirror the
filesystem automatically. If the wizard used synchronized folders, no
project-file edits are needed — moving files in Finder / git is
enough. If the wizard used classic Groups (yellow icon), file moves
must also be reflected in the `.pbxproj` (easiest: drag in Xcode
rather than editing the pbxproj by hand).

**Tests / verification**:
- `build_sim` still succeeds.
- `test_sim` still green.
- `ls -R Kado/` matches the tree in `CLAUDE.md`.

**Commit message (suggested)**: `chore(bootstrap): adopt CLAUDE.md
folder layout`

---

### Task 4: Build the empty shell views

**Goal**: Replace the wizard's `ContentView` placeholder with a
`TabView` shell that shows where `TodayView` and `SettingsView` will
live.

**Changes**:
- `Kado/Views/ContentView.swift`: `TabView` with two tabs — Today
  (`list.bullet.clipboard` icon) and Settings (`gearshape` icon).
  Each tab hosts its dedicated view. Localized titles via
  `String(localized:)` (strings register automatically into the String
  Catalog added in Task 6).
- `Kado/Views/Today/TodayView.swift`: empty view containing a single
  `Text("Today")` for now, wrapped in `NavigationStack`. Ship with a
  `#Preview`.
- `Kado/Views/Settings/SettingsView.swift`: same shape as TodayView
  for Settings. Ship with a `#Preview`.

**Tests / verification**:
- `build_sim` succeeds.
- `screenshot` on iPhone 16 Pro shows the TabView with both tabs,
  switching tabs works.
- Dynamic Type XXXL doesn't clip the tab labels.

**Commit message (suggested)**: `feat(shell): add empty TabView with
Today and Settings placeholders`

---

### Task 5: Add the DI extension point

**Goal**: Create the file where future service keys will be
registered, so the pattern from `CLAUDE.md` is visible and
discoverable from the start.

**Changes**:
- `Kado/App/EnvironmentValues+Services.swift`: empty
  `extension EnvironmentValues {}` with a doc comment pointing at the
  example `HabitScoreCalculating` snippet in `CLAUDE.md`. No keys yet.

**Tests / verification**:
- `build_sim` succeeds — file compiles in isolation.

**Commit message (suggested)**: `chore(bootstrap): add DI extension
point for service environment keys`

---

### Task 6: Add an empty String Catalog

**Goal**: Register the localization pipeline so the first
`String(localized:)` call has a place to auto-populate.

**Changes**:
- `Kado/Resources/Localizable.xcstrings`: create via Xcode (File > New
  > File > String Catalog). Source language English. No FR entries
  yet — FR lands at v1.0 per ROADMAP.

**Tests / verification**:
- `build_sim` succeeds.
- Running the app once populates the catalog with the strings used in
  `ContentView` (tab titles) — verify the catalog is no longer empty
  after a launch.

**Commit message (suggested)**: `chore(bootstrap): add empty String
Catalog for localization`

---

### Task 7: Replace the wizard test with a Kadō-flavored smoke test

**Goal**: If the wizard produced the generic Swift Testing template,
replace its body with a named smoke test that documents intent.

**Changes**:
- `KadoTests/SmokeTests.swift` (rename the wizard's file if needed):

```swift
import Testing
@testable import Kado

@Test("test target is wired") func smokeTargetIsWired() {
    #expect(true)
}
```

**Tests / verification**:
- `test_sim` runs 1 test, green.

**Commit message (suggested)**: `test(bootstrap): rename smoke test
and document intent`

---

### Task 8: Verify build + test on both iPhone and iPad

**Goal**: Close out bootstrap by confirming the project behaves on
both the iPhone 16 Pro and iPad Air (M2) simulators, per the
"Definition of done" in `CLAUDE.md`.

**Changes**: none in-repo. Verification only.

**Tests / verification**:
- `build_sim` on iPhone 16 Pro → success.
- `build_sim` on iPad Air (M2) → success.
- `test_sim` on iPhone 16 Pro → 1 passed.
- `screenshot` on each device shows the TabView shell.

**Commit message (suggested)**: no commit — verification only.

---

## Risks and mitigation

- **Xcode wizard drops XCTest instead of Swift Testing**: some Xcode
  16 minor versions default to XCTest for the test target even when
  Swift Testing is selected. Mitigation: delete the generated
  `*.swift` test file and replace with the snippet in Task 7; remove
  the `XCTest` import from build settings if added.
- **Synchronized folders vs classic groups**: Task 3 (folder
  restructuring) is simple if the wizard used synchronized folder
  references (Xcode 16 default), and painful if it used classic
  Groups. Mitigation: after Task 2, inspect `project.pbxproj` for
  `PBXFileSystemSynchronizedRootGroup` entries. If present → Task 3
  is filesystem-only. If absent → do folder moves via drag-in-Xcode,
  not `mv`, to keep the pbxproj consistent.
- **Preview Content path**: moving or renaming it breaks
  `DEVELOPMENT_ASSET_PATHS`. Mitigation: leave it where the wizard
  puts it (`Kado/Preview Content/`). It's listed as-is in `CLAUDE.md`.
- **XcodeBuildMCP not installed by Task 2**: Task 1 is the hard gate.
  If the user hasn't finished installing before Task 2, pause build
  and surface it.
- **`.xcodeproj` binary merge conflicts later**: this is the generic
  Xcode pain. Bootstrap can't eliminate it, just minimize by keeping
  the project simple. When KadoWidgets / KadoWatch are added later,
  each will land on its own branch to keep pbxproj churn linear.

## Open questions

None — all research-stage questions were resolved. New ones, if any,
will be added during build and carried to `compound.md`.

## Notes during build

- **Task 2**: Xcode wizard creates a container folder named after the
  product, so the wizard output ended up nested one level too deep.
  Fixed with a filesystem move (synchronized folders mean no pbxproj
  surgery). Also: wizard defaulted the app target to iOS 26.4 and the
  tests to iOS 18.6 — harmonized both to 18.0 via a direct pbxproj
  edit. User-confirmed the 18.0 minimum matches `CLAUDE.md`.
- **Task 2**: Wizard includes `KadoUITests` by default with no way to
  opt out. Xcode's "Delete target" leaves an orphan
  `PBXFileSystemSynchronizedRootGroup` entry behind — cleaned by
  hand, then `rm -rf KadoUITests`.
- **Task 3**: Plan called for `.gitkeep` in empty folders to preserve
  the layout. Synchronized root groups pull every file in as a bundle
  resource and collide on identical filenames (all `.gitkeep`). Pbxproj
  exception sets would fix it but aren't worth it for bootstrap;
  dropped the `.gitkeep` files. Empty folders won't persist in git —
  they materialize when v0.1 drops its first file into each.
- **Simulator choice**: `CLAUDE.md` names "iPhone 16 Pro (iOS 18.x)"
  as the default target, but only iOS 26.4 simulators are installed
  (iPhone 17 Pro etc.). Using iPhone 17 Pro on 26.4 for now. Deployment
  target 18.0 still builds and runs fine on a 26.4 runtime. Consider
  updating `CLAUDE.md` to name the current-flagship equivalent.

## Out of scope

Explicitly deferred — do not pull in during this bootstrap:

- `@Model` types (`Habit`, `Completion`) and the `ModelContainer` —
  belong to v0.1 data-layer task.
- CloudKit container, iCloud entitlement, App Group — added when sync
  code first needs them (v0.1 end, v0.2 widgets).
- HealthKit entitlement — v0.3.
- Widget extension target — v0.2.
- Watch target, Live Activity target, UI-test target — v0.3 / v1.0.
- App icon artwork — stays at the Xcode default placeholder; real
  icon is a v1.0 polish item.
- FR localization — v1.0 per ROADMAP.
- Biometrics, theming, import/export — not bootstrap concerns.
