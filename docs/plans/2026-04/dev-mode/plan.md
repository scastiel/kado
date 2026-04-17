# Plan — Dev Mode

**Date**: 2026-04-17
**Status**: ready to build
**Research**: [research.md](./research.md)

## Summary

Add a user-facing Settings toggle that swaps the app's SwiftData
store between the production CloudKit-backed container and an
on-disk sandbox container seeded with a demo dataset. Real data is
never touched. Shipped in Release. Dev mode off→on wipes and reseeds
the sandbox; turning it off preserves the sandbox file but returns
to real data.

## Decisions locked in

- Two `ModelContainer`s: production (CloudKit, current behavior) and
  dev (on-disk at a dedicated URL, no CloudKit).
- Dev container uses the same `KadoSchemaV1` / `KadoMigrationPlan`.
- Dev mode flag stored as `@AppStorage("kado.devMode")` (UserDefaults,
  not synced to iCloud). Default `false`.
- Seed function moves out of `Preview Content/` into a Release-
  compilable source location. Preview helpers (`PreviewContainer.shared`,
  `emptyContainer`, etc.) stay in `Preview Content/` and call the
  relocated seed.
- Seed scope: ~14 days of history, one habit per `HabitType` variant,
  mixed `Frequency` coverage (essentially today's `PreviewContainer.seed`).
- Off→on transition wipes the dev `.sqlite` and reseeds. No separate
  "Reseed" button.
- Shipped in Debug and Release.

## Task list

### Task 1: Extract seed function into shippable source

**Goal**: Move the seed logic so it's reachable from the main app
target in Release, while preview helpers keep working.

**Changes**:
- New `Kado/Services/DevModeSeed.swift` exposing
  `enum DevModeSeed { static func seed(into context: ModelContext, calendar: Calendar = .current) }`.
- `Kado/Preview Content/PreviewContainer.swift`: delete the private
  `seed(_:)`, call `DevModeSeed.seed(into:)` instead. Preview
  variants unchanged otherwise.

**Tests / verification**:
- Existing preview-driven tests (if any) still pass.
- `build_sim` clean.
- Visual: open Xcode previews on `HabitListView` — seeded data still
  shows.

**Commit message**: `refactor(dev-mode): extract seed into shippable DevModeSeed`

---

### Task 2: Add DevModeController with container lifecycle

**Goal**: Encapsulate the two-container logic behind one observable
type that the app root can drive.

**Changes**:
- New `Kado/App/DevModeController.swift`: `@MainActor` `@Observable`
  class. Responsibilities:
  - Build / return the prod `ModelContainer` (lazy).
  - Build / return the dev `ModelContainer` (lazy, on-disk at
    `Application Support/KadoDev.sqlite`, no CloudKit).
  - `func activateDevMode()` — delete the dev sqlite file if it
    exists, build a fresh container, seed via `DevModeSeed`.
  - `func deactivateDevMode()` — drop the dev container reference.
  - `func container(forDevMode enabled: Bool) -> ModelContainer`
    that routes correctly.
- `CloudContainerID.kado` usage stays on the prod container only.

**Tests / verification** (`KadoTests/DevModeControllerTests.swift`):
- `@Test("Prod container uses CloudKit configuration")` — sanity.
- `@Test("Dev container is on-disk, no CloudKit")`.
- `@Test("activateDevMode seeds at least one habit per HabitType")`.
- `@Test("Off→on cycle wipes sandbox edits")` — seed, insert a
  sentinel habit, deactivate, reactivate, confirm only seeded
  habits remain and sentinel is gone.

**Commit message**: `feat(dev-mode): add DevModeController for container lifecycle`

---

### Task 3: Wire the container swap in KadoApp

**Goal**: Make the root view drive its `.modelContainer(...)` from
the dev-mode flag.

**Changes**:
- `Kado/App/KadoApp.swift`:
  - Replace the current `let container` with a `@State` or `let`
    `DevModeController`.
  - `@AppStorage("kado.devMode") private var isDevMode = false`.
  - Compute the active container from `controller.container(forDevMode: isDevMode)`.
  - `.onChange(of: isDevMode)` — call `controller.activateDevMode()`
    when turning on, `controller.deactivateDevMode()` when turning
    off. Apply before the view re-reads the container so the swap
    is atomic.

**Tests / verification**:
- `build_sim` clean.
- Manual: launch app, no dev mode, real data (empty on fresh
  install) shows. Then (with Task 4 landed) flip the toggle and
  confirm the UI snaps to seeded data and back.

**Commit message**: `feat(dev-mode): swap SwiftData container from app root`

---

### Task 4: Settings toggle + copy

**Goal**: Surface the toggle in the Settings screen.

**Changes**:
- `Kado/Views/Settings/SettingsView.swift`: new `Section("Dev mode")`
  (or similarly named) with a `Toggle` bound to
  `@AppStorage("kado.devMode")`, and a footer explaining the
  behavior: "Replace your data with a demo dataset. Your real data
  is safe and returns when you turn this off."
- Localized via `String(localized:)` — add EN + FR entries to the
  string catalog.

**Tests / verification**:
- `screenshot` of Settings with toggle off and on.
- Manual round-trip: toggle on → seeded data everywhere (Today,
  Detail, History). Toggle off → original data back. Toggle on
  again → fresh seed (any edits from previous dev session gone).

**Commit message**: `feat(dev-mode): add Settings toggle`

---

### Task 5: Manual verification pass + PR polish

**Goal**: End-to-end sanity before marking ready for review.

**Changes**: none or tiny.

**Verification**:
- `build_sim` + `test_sim` both green.
- iPhone 16 Pro: toggle cycle, create a habit while in dev mode,
  toggle off and on, confirm it's gone.
- iPad Air: same cycle.
- VoiceOver on the Settings toggle reads correctly.
- Dynamic Type XXXL on the Settings footer doesn't clip.
- Confirm `KadoDev.sqlite` appears in the simulator sandbox under
  Application Support while dev mode is on.

**Commit message**: (none — or doc updates only)

---

## Risks and mitigation

- **Container swap doesn't trigger `@Query` refresh.** → Confirm
  with a 2-minute smoke test during Task 3. If SwiftUI caches the
  container identity incorrectly, fall back to re-rooting the
  `WindowGroup` content on a `.id(isDevMode)` modifier.
- **Seed function now compiled in Release** (size cost). →
  Negligible (~a few hundred lines of data), but worth noting.
- **Schema evolution later**: when `KadoSchemaV2` ships, both
  containers pick it up automatically since they share the
  migration plan. Dev sandbox file gets migrated on first access
  too — acceptable, since the user can always toggle off/on to
  reseed.
- **User confusion ("where did my data go?")**. → Footer copy is
  explicit; the toggle itself says "Dev mode." Revisit wording if
  testers misread it.

## Open questions

None blocking. Will revisit toggle copy during Task 4 based on how
it reads in-app.

## Out of scope

- Release-facing "demo mode" with its own onboarding hook (if ever
  desired, separate feature).
- Reseed-while-on button.
- Richer seed (60–90 days, streak-heavy, etc.).
- Dev-mode-only debug tools (time travel, force-advance date,
  inject completions) — possible future follow-ups.
