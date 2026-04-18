---
name: Widgets compound
description: Retrospective on the v0.2 widget pass — what we learned about SwiftData + CloudKit + widget extensions, and why we ended up with a JSON-snapshot bridge
type: project
---

# Compound — Widgets

**Date**: 2026-04-18
**Status**: complete
**Research**: [research.md](./research.md)
**Plan**: [plan.md](./plan.md)
**Branch / PR**: `feature/widgets` → [#14](https://github.com/scastiel/kado/pull/14)

## Summary

Shipped six widget surfaces (three home sizes + three lock variants)
plus the first `AppIntent` (`CompleteHabitIntent`). The architecture
landed nothing like the plan predicted: the widget extension does
**not** open SwiftData. Instead, the main app writes a JSON snapshot
to an App Group container on every mutation, and widgets decode it.
The headline lesson: **two SwiftData processes cannot both attach
CloudKit to the same store, and every workaround (read-only mode,
opposite CloudKit configs, `@objc(Name)`) dead-ends into the same
trap**. Accepting that constraint up front would have saved ~15
commits of iteration.

## Decisions made

- **App Group + shared SQLite** (original plan): abandoned. Two
  CloudKit-attached `ModelContainer`s in different processes race
  for sync ownership and trap `NSCocoaErrorDomain 134422`.
- **JSON snapshot via App Group** (final): app-side
  `WidgetSnapshotBuilder` writes `widget-snapshot.json`; widget
  reads via `WidgetSnapshotStore.read()`. Value types only — no
  SwiftData in the widget process.
- **Shared code lives in `Packages/KadoCore/`** (Swift Package),
  not a synchronized folder duplicated across targets. Module
  identity has to be singular for SwiftData to recognize schemas
  across targets; duplicated files = duplicate types = schema
  mismatch trap.
- **`CompleteHabitIntent.openAppWhenRun = true`**: tapping an
  interactive widget opens the app, which performs the toggle on
  the live CloudKit-attached container. Less "magical" than
  silent completion, but the only shape that respects the
  single-owner constraint.
- **`ActiveContainer.shared` singleton**: `KadoApp` primes it;
  `CompleteHabitIntent.perform()` reads it. Guarantees the intent
  reuses the app's live container rather than opening a second
  one in the same process (a mistake we repeated three times).
- **Lock widgets use `WidgetConfigurationIntent`** with `PickHabitIntent`
  so the user picks which habit appears. Auto-selecting "top habit"
  was rejected because there's no universal right answer.
- **Large widget mirrors the Overview layout**: per-habit block
  with name + icon on top, full-width cell stripe beneath.
  GeometryReader-based widths keep cells aligned with the
  weekday header above.

## Surprises and how we handled them

### SwiftData + CloudKit single-owner rule

- **What happened**: Adding iCloud entitlement to the widget and
  opening with `cloudKitDatabase: .private(...)` traps with
  "another instance actively syncing." Flipping to
  `cloudKitDatabase: .none` traps at the first `context.fetch()`
  because the on-disk metadata was stamped CloudKit. Setting
  `allowsSave: false` doesn't help — read-only mode still
  registers a sync handler.
- **What we did**: Five commits of pivoting, then full-on JSON
  snapshot refactor.
- **Lesson**: iOS SwiftData stores that are CloudKit-mirrored are
  *exclusively* owned by the writing process. Any sharing pattern
  has to export **data**, not a store reference.

### `#Predicate` crashes in the widget extension process

- **What happened**: Even a trivial `#Predicate { $0.archivedAt == nil }`
  traps with `EXC_BREAKPOINT` on the first fetch inside the
  widget. Bad generated code at predicate-compile time? Unclear.
- **What we did**: Stripped every `#Predicate` from widget-path
  fetches; filter in Swift after a broad fetch. Still used inside
  the main app where it's stable.
- **Lesson**: Don't trust `#Predicate` outside the main app
  process. Prefer `FetchDescriptor()` + Swift `.filter { }`.

### Module identity across targets

- **What happened**: Even after moving shared code into a
  `Shared/` synchronized folder with dual target membership,
  SwiftData debug output showed `KadoWidgetsExtension.HabitRecord`
  in the widget while the SQLite was written with `Kado.HabitRecord`.
  The fetch descriptor's generic type doesn't match the schema →
  trap.
- **What we did**: Carved shared code into a Swift Package
  (`Packages/KadoCore/`). Both targets link the same compiled
  module → same type identity.
- **Lesson**: Duplication-via-target-membership is a trap for any
  framework that does runtime type inspection (SwiftData,
  Codable + `_mangledTypeName`, CoreData, App Intents). Share via
  a proper library, not two compiled copies.

### Xcode 16 synchronized folders

- **What happened**: Initial `Shared/` was added as a *regular*
  PBXGroup (manual file list), not a synchronized root group —
  new files didn't auto-enroll. Xcode's "Convert to Folder"
  option refused when stray files existed that weren't in the
  group.
- **What we did**: Moved offending files aside, converted, moved
  them back. Synchronized folder then auto-picked everything up.
- **Lesson**: Synchronized folders are worth the upfront setup but
  can't coexist with leftover manual file references. Keep the
  filesystem and the pbxproj strictly in sync.

### `.gitignore` hid the local package

- **What happened**: Standard Swift project gitignore has
  `Packages/` (intended for SwiftPM build cache). The new local
  package at `Packages/KadoCore/` was silently ignored — the
  package existed locally but never made it to the remote.
- **What we did**: Un-ignore `!Packages/KadoCore/` explicitly.
- **Lesson**: When introducing a local Swift Package, audit
  `.gitignore` first. The catch-all directory rules in the Apple
  gitignore template assume Packages/ is generated.

### AppIntent container leak

- **What happened**: Code review surfaced that
  `CompleteHabitIntent.perform()` opened
  `try SharedStore.productionContainer()` per call — but the
  app's `.modelContainer(_:)` modifier had one already. Two
  CloudKit-attached containers in the same process.
- **What we did**: Introduced `ActiveContainer.shared`; `KadoApp`
  primes on scene build + every dev-mode swap; intent reads from it.
- **Lesson**: Every AppIntent running in-app should access the
  app's live container via a process-scoped reference, not by
  constructing its own. Useful convention for future intents.

## What worked well

- **Research + plan stages caught the big question early.** Even
  though the plan's assumption (SwiftData works fine in widgets)
  was wrong, writing it out made the pivot moment explicit.
- **AskUserQuestion at forks.** Every architectural pivot
  (widget-path fallback, package vs synchronized folder, JSON
  snapshot vs disable widgets) was a four-option question the
  user decided in ~10s.
- **XcodeBuildMCP in-loop.** Once the user nudged to run builds
  locally instead of handing off, iteration velocity jumped.
- **Small commits per pivot.** Each fix-then-fail cycle shipped
  its own commit, so the bisectable history reads like a
  narrative.
- **180 tests, rarely red for long.** Even across two major
  architectural pivots (package split, snapshot refactor), the
  test suite stayed green after a short recovery on each pivot.
- **`@preconcurrency import WidgetKit`** silences Swift 6's
  `Timeline<Entry>` Sendable diagnostic without editing Apple
  headers. Worth remembering for any future WidgetKit code.

## For the next person

- **Adding a widget surface?** Extend `WidgetSnapshot` +
  `WidgetSnapshotBuilder`, then add the widget that reads from
  `SnapshotTimelineProvider` / `PickedSnapshotProvider`. Do
  **not** import SwiftData in widget code.
- **Adding a new `AppIntent`?** Read the container via
  `ActiveContainer.shared.get()`, not `SharedStore.productionContainer()`.
  Set `openAppWhenRun = true` if it mutates state (the widget
  extension process can't hold the writer role).
- **Adding a new `@Model` class?** It has to live in `KadoCore`,
  with `public` on the class and its stored properties (so the
  macro-generated `PersistentModel` conformances satisfy their
  protocol requirements).
- **Adding a new `#Predicate`?** Fine for app code. In the
  widget target, **always** do a broad fetch + `.filter { }` in
  Swift instead.
- **Tests for persistence types** should use
  `isStoredInMemoryOnly: true` configurations; the test
  `ModelContainer` never touches the App Group or CloudKit.
- **The widget snapshot is written on**: app launch (via
  `KadoApp.task`), every mutation (via `WidgetReloader.reloadAll`),
  and `CompleteHabitIntent.perform()`. If a new mutation site
  appears, it must call `WidgetReloader.reloadAll(using:)` too.

## Generalizable lessons

- **[→ CLAUDE.md]** SwiftData stores mirrored to CloudKit are
  exclusively owned by one process. Widgets and extensions
  consume via file-system snapshots (App Group JSON), not by
  opening the store.
- **[→ CLAUDE.md]** Share SwiftData `@Model` types via a Swift
  Package, not via target-membership duplication. Two compiled
  copies = two Swift types = SwiftData schema mismatch.
- **[→ CLAUDE.md]** Avoid `#Predicate` in widget / extension code
  paths. A `FetchDescriptor` with a `SortDescriptor` plus Swift
  `.filter { }` is boring and works.
- **[→ CLAUDE.md]** AppIntents running in-app should read the
  live `ModelContainer` via a process-scoped reference
  (`ActiveContainer.shared` pattern), not by building a fresh
  one per `perform()`.
- **[→ CLAUDE.md]** When adding a local Swift Package, audit
  `.gitignore` — the standard Apple template ignores `Packages/`.
- **[→ CLAUDE.md]** Snapshot-reader widget pattern: app writes
  pre-computed JSON in an App Group file on every mutation;
  widget's `TimelineProvider` decodes on each reload. Kills
  dual-process data-sync problems dead.
- **[local]** `CompleteHabitIntent` uses `openAppWhenRun = true`.
  Not ideal UX; revisit in v0.3 with Live Activities or once iOS
  exposes a safe cross-process SwiftData bridge.
- **[local]** Widget `WeeklyGridLargeWidget` truncates weekday
  labels to two characters (`Su`, `Mo`, `Tu`...) — good for
  readability at widget density but not a global convention; the
  main app's Overview keeps the full standalone symbols.

## Metrics

- Tasks completed: 16 planned + 1 compound-stage fix (JSON
  snapshot refactor replaced the "SwiftData in widget" path of
  tasks 7-14)
- Commits on branch: 35
- Tests: 180 (net +12 from main, after deleting 13 tests for
  removed widget-SwiftData types)
- Files touched: 119
- Lines changed: +3,794 / −167

## References

- [Apple: CloudKit mirroring](https://developer.apple.com/documentation/coredata/mirroring_a_core_data_store_with_cloudkit)
- [Apple: WidgetKit](https://developer.apple.com/documentation/widgetkit)
- [Apple: AppIntents — openAppWhenRun](https://developer.apple.com/documentation/appintents/appintent/openappwhenrun)
- [NSCocoaErrorDomain 134422](https://developer.apple.com/documentation/coredata/nscocoaerrordomain)
  — the error code we chased for most of this PR.
