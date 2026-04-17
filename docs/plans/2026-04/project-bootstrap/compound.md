# Compound — Project bootstrap

**Date**: 2026-04-16
**Status**: complete
**Research**: [research.md](./research.md)
**Plan**: [plan.md](./plan.md)
**Branch / PR**: [feature/project-bootstrap](https://github.com/scastiel/kado/pull/1)

## Summary

Kadō's Xcode project skeleton is in place: main app target (`Kado`,
bundle ID `dev.scastiel.kado`, iOS 18.0+, universal), Swift Testing
unit-test target (`KadoTests`), folder layout per `CLAUDE.md`, and an
empty TabView shell with Today/Settings placeholders. Build and test
green on iPhone 17 Pro and iPad Air 13". The headline lesson: Xcode
16's synchronized folder references make filesystem moves safe, but
they aggressively treat every file in the tree as a target resource —
including `.gitkeep` files, which is why empty folders can't persist
in git.

## Decisions made

- **iOS 18.0 deployment target**: matches `CLAUDE.md` spec, widest
  audience, nothing on the roadmap through v1.0 needs a newer API.
- **`.xcodeproj` at repo root**: siblings `Kado/`, `KadoTests/` follow
  `CLAUDE.md`'s declared folder tree; repo is iOS-only so no need to
  partition under a subfolder.
- **Synchronized folder references**: kept the Xcode 16+ default (blue
  folder icons). Filesystem moves auto-reflect in the project without
  pbxproj edits.
- **Drop `KadoUITests` target now**: UI tests belong to v1.0 per
  `ROADMAP.md`; empty target would churn the pbxproj for no value.
- **Use iOS 18 `Tab { }` API**: newer declarative syntax over
  `.tabItem { }`; explicit systemImage, cleaner for localization.
- **`ContentUnavailableView` for empty states**: native placeholder
  with icon + headline + description; same shape v0.1's "no habits"
  empty state will use, so the shell isn't throwaway.
- **DI extension point as a pure scaffold file**: empty
  `extension EnvironmentValues {}` with the `HabitScoreCalculating`
  example commented out. Future service keys land here.
- **Commit `.mcp.json`**: contributors get the same XcodeBuildMCP
  config (with Sentry telemetry disabled) without manual setup.

## Surprises and how we handled them

### Xcode wizard nests under a product-folder container

- **What happened**: Told the user the wizard would produce
  `.xcodeproj` at the repo root. It actually always creates a folder
  named after the product (`kado/Kado/Kado.xcodeproj`) regardless of
  the save location.
- **What we did**: Filesystem move up one level after the wizard
  (`mv Kado/* .` with a temp-rename dance to avoid the inner/outer
  `Kado/` collision). Synchronized folders made this safe.
- **Lesson**: The wizard's "Save location" dialog is where the
  container folder gets created, not where the `.xcodeproj` ends up.
  Either accept one level of nesting or plan for the move.

### Wizard defaulted to mismatched deployment targets

- **What happened**: Main app target at iOS 26.4 (Xcode 26 default),
  test target at iOS 18.6. `test_sim` failed: "compiling for iOS 18.6
  but module 'Kado' has a minimum deployment target of iOS 26.4".
- **What we did**: Replaced all four `IPHONEOS_DEPLOYMENT_TARGET`
  entries in `project.pbxproj` (Debug + Release for each of app and
  tests) with `18.0` via `Edit` with `replace_all`.
- **Lesson**: Setting "Minimum Deployments" in Xcode's General tab
  only updates the targeted configuration. Always grep pbxproj to
  confirm all four entries match.

### `.gitkeep` collided in synchronized folders

- **What happened**: Added `.gitkeep` to each empty folder (`Models/`,
  `Services/`, etc.) so the layout persists in git. Build failed with
  "Multiple commands produce `Kado.app/.gitkeep`" — every sync'd file
  gets copied flat into the app bundle, and identical filenames
  collide.
- **What we did**: Removed the `.gitkeep` files. Empty folders don't
  persist in git, but they materialize the moment v0.1 drops its
  first file in each.
- **Lesson**: In Xcode 16+ synchronized roots, placeholders with the
  same filename across subfolders always collide. Either use unique
  filenames, configure `PBXFileSystemSynchronizedBuildFileExceptionSet`
  entries, or just accept that git won't track empty dirs.

### Xcode "Delete target" leaves orphan sync-group entries

- **What happened**: After deleting `KadoUITests` in Xcode, the
  pbxproj still had a `PBXFileSystemSynchronizedRootGroup` entry for
  the folder plus a reference to it from the root `PBXGroup`.
- **What we did**: Removed both entries by hand and `rm -rf`'d the
  folder.
- **Lesson**: Xcode's target deletion is scoped to the target
  definition and its build configs — it doesn't cascade to the
  folder-reference graph. Always check the pbxproj for dangling refs
  after deleting a target.

### CLAUDE.md names outdated simulators

- **What happened**: `CLAUDE.md` says "Boot and use iPhone 16 Pro
  (iOS 18.x) as default". Only iOS 26.4 simulators are installed.
- **What we did**: Used iPhone 17 Pro + iPad Air 13" (M4). Deployment
  target 18.0 still runs fine on a 26.4 runtime.
- **Lesson**: Simulator names age with Xcode updates. Generic phrasing
  ("latest iPhone flagship") is more durable than specific model
  names in long-lived docs.

## What worked well

- **Synchronized folders + filesystem-first moves**: restructuring the
  whole project layout (move up one level, reorganize into `App/`,
  `Views/`, `Resources/`) cost zero pbxproj edits.
- **Small, per-task commits**: 9 commits on the branch, each an atom
  someone can revert independently. Made debugging the `.gitkeep`
  collision trivial because I could just `git reset` the Task 3
  commit.
- **XcodeBuildMCP's `build_sim`/`test_sim` loop**: sub-10-second
  feedback on each change without leaving the conversation.
- **Research + plan up front**: the "nest vs root" and "UI test target
  defer" decisions were already agreed before the wizard ran. When
  the wizard output didn't match, we had a reference point to
  reconcile against rather than drifting.

## For the next person

- The `.xcodeproj` is at the repo root. The sibling `Kado/` folder is
  target sources, not a project container — don't be confused by the
  similar names.
- Synchronized folders mean dragging a new Swift file into
  `Kado/Models/` from Finder is enough; no need to touch the pbxproj
  or Xcode's project navigator. Xcode picks it up on next build.
- Empty folders (`Models/`, `Services/`, etc.) are declared in
  `CLAUDE.md` but won't exist on a fresh clone until someone adds a
  file. Don't panic if they're missing.
- `IPHONEOS_DEPLOYMENT_TARGET` lives in four places in
  `project.pbxproj` — when bumping the minimum, update all four.
- `EnvironmentValues+Services.swift` is the single source of truth for
  service injection keys. When adding a service, follow the commented
  template at the top.

## Generalizable lessons

- **[→ CLAUDE.md]** Update default simulator from "iPhone 16 Pro (iOS
  18.x)" to "iPhone 17 Pro" and "iPad Air (M2)" to "iPad Air 13-inch
  (M4)", or switch to a version-neutral phrasing.
- **[→ CLAUDE.md]** Add a one-line note: "Empty sub-folders under
  `Kado/` (e.g. `Models/`, `Services/`) materialize when first
  populated — git does not track empty dirs, and `.gitkeep` placeholders
  collide under synchronized folder references."
- **[→ CLAUDE.md]** Consider a short Tooling sub-section: "When
  editing build settings, update all four
  `IPHONEOS_DEPLOYMENT_TARGET` entries in `project.pbxproj` (Debug +
  Release for each target)."
- **[local]** The `.mcp.json` committed at the repo root propagates
  the XcodeBuildMCP config to any contributor who clones and trusts
  the MCP server.

## Metrics

- Tasks completed: 8 of 8
- Tests added: 1 (smoke)
- Commits on branch: 10 (research, plan, 8× build)
- Files in repo after bootstrap: 10 code/config, 4 docs
- Build time (cold): ~30s; (incremental): ~3s

## References

- [Xcode 16 synchronized folders (WWDC24)](https://developer.apple.com/videos/play/wwdc2024/10171/)
- [Swift Testing documentation](https://developer.apple.com/xcode/swift-testing/)
- [`SwiftUI.Tab` iOS 18 API](https://developer.apple.com/documentation/swiftui/tab)
