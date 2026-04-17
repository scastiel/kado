# Research — Dev Mode

**Date**: 2026-04-17
**Status**: ready for plan
**Related**: `docs/ROADMAP.md`, `Kado/Preview Content/PreviewContainer.swift`

## Problem

Working on Kadō — reviewing score curves, reviewing calendar/history
rendering, tuning the detail view, demoing the app — is painful
without realistic historical data. Today the only realistic seed
lives in `PreviewContainer` and is only reachable from SwiftUI
previews. Manually creating months of completion data in the running
app is tedious and disposable.

We want an in-app **dev mode**: a toggle in Settings that replaces
the live SwiftData store with a seeded sandbox store. When turned
off, the real data reappears untouched. Edits in dev mode can be
discarded on exit — no iCloud sync from the sandbox, no requirement
to persist them at all.

"Done" from the user's perspective:
- Flip a toggle in Settings → the whole app (Today, Detail, History,
  Score) instantly operates on a rich seeded dataset.
- Flip it back → real data returns, untouched.
- Edits while in dev mode are local-only; losing them on exit is
  acceptable (even desirable).

## Current state of the codebase

- **Single container at app root**: `KadoApp.swift` builds one
  `ModelContainer` with `ModelConfiguration(cloudKitDatabase:
  .private(CloudContainerID.kado))` around `KadoSchemaV1`, and
  injects it via `.modelContainer(...)`. All `@Query` in the app
  reads from this container.
- **Preview seed already exists**: `Preview Content/PreviewContainer.swift`
  has `static func seed(_ context: ModelContext)` covering all four
  `HabitType` variants (binary / counter / timer / negative) and
  mixed frequencies, with ~14 days of staggered completions. The
  file is in Preview Content, so it's Debug-only and not shipped in
  Release.
- **Models**: `HabitRecord` (+ cascade `CompletionRecord`),
  codable-as-data for `Frequency` and `HabitType`. CloudKit-shape
  rules already applied (optional relationships, no uniqueness
  constraints).
- **Settings screen** (`Views/Settings/SettingsView.swift`): minimal,
  only an iCloud account section. No `UserDefaults`/`@AppStorage`
  used anywhere yet — this would be the first one.
- **CloudKit**: wired up (container ID, entitlements, account
  observer) but not yet user-facing / actively exercised in v0.1.
  Risk of conflict with a sandbox container is low today.

## Proposed approach

**Two `ModelContainer`s, swap at the root view.** Shipped in both
Debug and Release — the user activates dev mode from Settings at
runtime, it is not a build-time flag. `PreviewContainer.seed` will
need to move out of `Preview Content/` (Debug-only) into a regular
source folder so it's reachable in Release builds.

Flow:

1. `@AppStorage("kado.devMode")` bool (UserDefaults — not synced to
   iCloud by default, which is exactly what we want).
2. A `DevModeController` (`@Observable`, `@MainActor`) owns two
   lazily-built containers:
   - `productionContainer`: today's CloudKit-backed container.
   - `devContainer`: on-disk at a separate URL (e.g.
     `Application Support/KadoDev.sqlite`), **no CloudKit**,
     seeded via the extracted seed function on first build.
     Edits persist across app launches as long as dev mode stays
     on.
   It exposes `var currentContainer: ModelContainer` derived from
   the toggle.
3. `KadoApp.body` reads the toggle and applies the right container
   via `.modelContainer(controller.currentContainer)`. SwiftUI
   tears down and rebuilds the environment when the identity of
   the injected container changes — all `@Query`s re-fetch, so
   the UI snaps to the new store without any per-view work.
4. Turning dev mode **off** drops the dev container reference.
   The sandbox file stays on disk but is not accessed — real
   data is back in the UI.
5. Turning dev mode **on again** deletes the sandbox file and
   rebuilds a fresh seeded container — a clean slate each
   off→on cycle is how the user resets dev data (no separate
   "Reseed" button needed).

### Key components

- `DevModeController` (new, `Services/` or `App/`): lazy container
  accessors, `isEnabled` mirror of the `@AppStorage` value,
  wipe-and-reseed on off→on transition.
- Seed function: extracted from `PreviewContainer` into a shippable
  source folder (e.g. `Services/DevModeSeed.swift`) so it is
  available in Release. Keep the ~14-day history as-is.
- `SettingsView`: new section with a `Toggle`, always visible.
  Copy: "Dev mode — replace your data with a demo dataset. Your
  real data is safe and returns when you turn this off."
- `KadoApp`: read toggle, bind to controller, swap container.

### Data model changes

None. Uses the existing schema for both containers.

### UI changes

- Settings: new section with a single toggle + footnote
  explaining the effect. Shipped in Release.
- No other views change — they keep reading their `@Query` / env
  container.

### Tests to write

This is mostly wiring and Debug-only plumbing, so the testing bar
is low. Worth covering:

- `@Test("DevModeController returns the dev container when enabled")`
- `@Test("DevModeController seeds dev container with at least one habit of each HabitType")`
- `@Test("Toggling dev mode off→on wipes the sandbox and reseeds")`
  (write a sentinel habit into the dev container, flip off then
  on, confirm only seed habits remain).

UI behavior (the swap itself) is adequately covered by manual
check + screenshot.

## Alternatives considered

### Alternative A: Single container, stash/restore user data

Save user `HabitRecord`s to JSON on dev-mode enable, clear the
store, seed, then restore on disable.

- Why not: delete-and-restore on the real store is far scarier
  than leaving it alone in a parked container. A crash mid-swap
  could nuke user data, and it would sync the deletions to
  CloudKit. The container-swap approach keeps real data 100%
  untouched, at the cost of one extra `ModelContainer` instance.

### Alternative B: In-memory flag on the existing container

There is no runtime switch on `ModelConfiguration` — the
`isStoredInMemoryOnly` flag is set at construction. Would still
require rebuilding the container, so no win over Alternative
(chosen).

### Alternative C: Ship in Release too

Could expose dev mode to end users as a "demo mode" for
exploring the app without committing real data.

- Why not now: conflates "dev tool for us" with "demo for users."
  If we want a real demo mode later it deserves its own UX
  (onboarding hook, explicit copy, localization). Debug-only is
  the right MVP.

## Risks and unknowns

- **Container swap re-renders**: confirm that changing the
  `ModelContainer` passed to `.modelContainer(_:)` actually
  re-instantiates downstream `@Query`s. The SwiftUI contract here
  is solid in practice but worth a 2-minute smoke test before
  committing.
- **Observer singletons**: `CloudAccountStatusObserving` and any
  other long-lived services are fine — they don't hold a
  `ModelContext`. Double-check nothing else caches a context
  across the swap.
- **`@AppStorage` default**: `false`. User activates at runtime
  from Settings.
- **Seed file location**: moving `PreviewContainer.seed` into a
  shipped source folder means it's compiled into Release. Keep
  the Preview-only variants (`.shared`, `emptyContainer`, …) in
  `Preview Content/` — only the seed function itself needs to move.

## Open questions

Resolved:

- [x] **Debug-only, or Release too?** → Release too. Runtime toggle,
  no build-time flag.
- [x] **Seed richness** → ~14 days is fine.
- [x] **Sandbox persistence** → on-disk at a separate URL.
- [x] **Reset control** → no separate button; off→on wipes and
  reseeds.

## References

- `Kado/App/KadoApp.swift` — current container wiring.
- `Kado/Preview Content/PreviewContainer.swift` — existing seed.
- `Kado/Models/HabitType.swift`, `Kado/Models/Frequency.swift` —
  variants the seed must cover.
- Apple: [SwiftData `ModelConfiguration`](https://developer.apple.com/documentation/swiftdata/modelconfiguration)
