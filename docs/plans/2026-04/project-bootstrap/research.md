# Research — Project bootstrap

**Date**: 2026-04-16
**Status**: ready for plan
**Related**: [CLAUDE.md](../../../../CLAUDE.md), [ROADMAP.md](../../../ROADMAP.md) (v0.1 MVP)

## Problem

Kadō has no code yet — only product docs, a habit-score spec, and a
`CLAUDE.md` defining the intended architecture. Before v0.1 work can
begin, we need a minimal but correctly-shaped Xcode project so that
every subsequent piece of work (habit score calculator, SwiftData
models, Today view…) lands in an established skeleton rather than
inventing one per feature.

Scope per the user: **main app target only, empty views, no business
logic**. No widget / watch / live-activity / UI-test targets yet — they
get added in the versions that need them (v0.2, v0.3).

"Done" looks like: `build_sim` succeeds on iPhone 16 Pro simulator,
`test_sim` runs a single trivial Swift Testing case green, and the
folder layout matches the one declared in `CLAUDE.md`.

## Current state of the codebase

Nothing buildable exists. Present at repo root:

- [CLAUDE.md](../../../../CLAUDE.md) — architectural contract (MVVM +
  Services, DI via `Environment`, `@Observable`, SwiftData, zero
  third-party deps, iOS 18.0+, Xcode 16.0+, Swift 5.10+).
- [docs/PRODUCT.md](../../../PRODUCT.md), [docs/ROADMAP.md](../../../ROADMAP.md),
  [docs/habit-score.md](../../../habit-score.md).
- `.claude/skills/conductor/` — this workflow.
- `.gitignore` — already covers Xcode/SPM artefacts.

What's missing: the Xcode project itself, any Swift source, the test
target, the asset catalog, the Info.plist settings (display name,
bundle ID, supported orientations), the String Catalog, the SwiftData
`ModelContainer` setup, and the example DI Environment key that will
set the pattern for every future service.

## Proposed approach

Create a single-target iOS app project named **Kado** at the repo
root, with bundle ID `dev.scastiel.kado`, display name **Kadō** (with
macron, set via `CFBundleDisplayName` so the on-device label differs
from the ASCII bundle name), iOS 18.0 deployment target, Swift 5.10,
SwiftUI lifecycle, universal device family (iPhone + iPad). Organize
sources under `Kado/` matching the folder layout in `CLAUDE.md`, even
though most folders will be empty at this stage — the empty folders
declare intent and give future features an obvious home.

The `.xcodeproj` sits at the repo root (not nested in a subfolder):
this is what Xcode's New Project wizard produces when you pick the
repo as the project location, and it matches the sibling-folder layout
declared in `CLAUDE.md`. Future targets (KadoWidgets, KadoWatch…) will
be added as siblings to `Kado/` inside the same `.xcodeproj`.

Add a Swift Testing unit test target (`KadoTests`) with one trivial
passing test, so `test_sim` has something to execute and the TDD
workflow described in `CLAUDE.md` is runnable from day one.

Keep everything else deferred. No CloudKit container, no App Group, no
HealthKit entitlement, no Watch target, no widget extension — each of
those has a dedicated roadmap slot and pulling them in now means
entitlement friction without corresponding code to justify it.

### Key components

- **`KadoApp`** (`App/KadoApp.swift`): `@main` struct, hosts the root
  `WindowGroup` with a `ContentView`. No `ModelContainer` yet — adding
  SwiftData to the environment without any `@Model` types means an
  empty schema, which is noise. The first `@Model` (Habit) lands in
  the v0.1 data task; the container gets wired then.
- **`ContentView`** (`Views/ContentView.swift`): SwiftUI `TabView`
  with two placeholder tabs (Today, Settings) so the shell of the
  intended information architecture is visible. Each tab renders a
  one-line `Text`.
- **`TodayView`** (`Views/Today/TodayView.swift`), **`SettingsView`**
  (`Views/Settings/SettingsView.swift`): empty placeholder views, each
  with a `#Preview`. These exist so later features land against a
  named view rather than creating one from scratch.
- **`EnvironmentValues+Services.swift`**
  (`App/EnvironmentValues+Services.swift`): empty `extension
  EnvironmentValues {}` with a comment pointing at the DI example in
  `CLAUDE.md`. Declares the file where future service keys land, so
  the pattern is discoverable without needing to hunt.
- **Asset catalog** (`Resources/Assets.xcassets`): default AppIcon
  placeholder + AccentColor.
- **String Catalog** (`Resources/Localizable.xcstrings`): empty but
  present, so the first `String(localized:)` call has somewhere to
  register.
- **`KadoTests/SmokeTests.swift`**: one `@Test("smoke") func smoke()
  { #expect(true) }` case, confirming Swift Testing is wired up.

### Data model changes

None. Adding `@Model` types without the frequency / completion /
migration logic they imply would be half-finished; deferred to v0.1.

### UI changes

Bootstrap only: two empty tabs. No design decisions.

### Tests to write

Just the smoke test. Its only job is to prove the test target builds
and runs under Swift Testing.

```swift
import Testing
@testable import Kado

@Test("test target is wired")
func smoke() {
    #expect(true)
}
```

## Alternatives considered

### Alternative A: generate project via XcodeGen / Tuist

- Idea: declare the project in YAML/Swift and regenerate the `.xcodeproj`.
- Why not: it's a third-party dependency, and `CLAUDE.md` says
  "zero third-party dependencies for v0.x" with RevenueCat as the only
  future exception. The `.xcodeproj` gets checked in and edited in
  Xcode like any other iOS project.

### Alternative B: scaffold all targets now (Widgets, Watch, LiveActivity, UI tests)

- Idea: create every target upfront so later versions don't have to
  touch project config.
- Why not: each target pulls entitlements, signing config, and Info
  keys that we'd have to maintain without corresponding code. It also
  inflates build times on every `build_sim`. Deferred per user
  direction.

### Alternative C: use the MCP `scaffold_ios_project` (or equivalent) tool

- Idea: drive project creation through XcodeBuildMCP rather than the
  Xcode GUI.
- Why not: XcodeBuildMCP isn't installed yet — the user will install
  it separately ("i'll do it"). Project creation itself is a one-time
  step that Xcode's New Project wizard handles correctly; MCP's value
  is in the ongoing build/test/debug loop.

## Risks and unknowns

- **CloudKit container later**: adding CloudKit requires an entitlement
  and a container ID (`iCloud.dev.scastiel.kado`). Creating it in
  App Store Connect needs a paid Apple Developer account. Not a v0.1
  blocker, but worth knowing the bundle ID decided now propagates into
  the container ID later.
- **Swift Testing on the default template**: Xcode 16's "New Project"
  wizard defaults the unit-test target to XCTest. We'll need to either
  choose "Testing System: Swift Testing" in the wizard, or delete the
  default XCTest file and replace it with a Swift Testing file. Minor,
  but worth being deliberate about.
- **Preview Content folder**: Xcode auto-creates `Preview Content/` at
  the Kado/ root. `CLAUDE.md` lists it in the folder layout, so the
  default is correct — no action needed.
- **XcodeBuildMCP not yet installed**: the build/test commands the
  "Definition of done" in CLAUDE.md depends on (`build_sim`,
  `test_sim`) won't be runnable until the user finishes installing it.
  Plan stage should confirm the install is complete before build stage
  starts.

## Decisions

Resolved during research, recorded here so the plan stage doesn't
revisit them:

- **Display name**: "Kadō" (with macron), via `CFBundleDisplayName`.
  Bundle name and target name stay ASCII `Kado`.
- **Device family**: universal (iPhone + iPad) from the start.
- **Xcode project location**: `.xcodeproj` at repo root, with `Kado/`
  and `KadoTests/` as siblings. Future targets sit alongside.
- **Git workflow**: branch `feature/project-bootstrap`, commit, push,
  open as draft PR.

## Open questions

None — all resolved above.

## References

- [CLAUDE.md](../../../../CLAUDE.md) — architecture section, folder
  layout, Tooling/XcodeBuildMCP section
- [ROADMAP.md](../../../ROADMAP.md) — v0.1 MVP scope this skeleton
  will host
- Apple: [Configuring SwiftData in your app](https://developer.apple.com/documentation/swiftdata/preserving-your-apps-model-data-across-launches)
- Apple: [Swift Testing overview](https://developer.apple.com/xcode/swift-testing/)
