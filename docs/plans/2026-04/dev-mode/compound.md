# Compound — Dev Mode

**Date**: 2026-04-17
**Status**: complete
**Research**: [research.md](./research.md)
**Plan**: [plan.md](./plan.md)
**Branch / PR**: `feature/dev-mode` — https://github.com/scastiel/kado/pull/11

## Summary

Shipped an in-app **Dev mode** Settings toggle that swaps the live
SwiftData store for an on-disk sandbox seeded with demo data. Real
data is never touched: prod and dev are two distinct `ModelContainer`s
owned by a `DevModeController`. Headline lesson: the simplest swap
pattern (build two containers, bind `@AppStorage` to `.modelContainer`,
let `@Query` re-fetch) works out of the box — no `.id(...)` remount
hack needed, and the safety net you reach for up front can quietly
degrade UX.

## Decisions made

- **Two `ModelContainer`s, never delete real data**: prod (CloudKit)
  and dev (on-disk, no CloudKit) coexist; the swap happens at the
  `.modelContainer(...)` call site. Container B in Alternative A
  ("stash and restore") was rejected as too risky — a mid-swap crash
  could sync deletions to CloudKit.
- **Ship in Release, not Debug-only**: activation is a runtime
  toggle, not a build flag, so the user can flip it on a shipped
  build for demos/testing without installing a dev build.
- **On-disk sandbox, not in-memory**: edits survive app launches
  while dev mode stays on. `Application Support/KadoDev.sqlite`.
- **Off→on wipes and reseeds**: no separate "Reseed" button — the
  existing toggle doubles as the reset gesture.
- **`@AppStorage("kado.devMode")` for the flag**: UserDefaults,
  not `NSUbiquitousKeyValueStore`, so the flag does not sync to
  iCloud. Default `false`.
- **Seed extraction**: `PreviewContainer.seed` moved into
  `Services/DevModeSeed.swift` so it's compiled into Release.
  Preview helpers in `Preview Content/` still call it.
- **Sync status reflects dev mode**: `SyncStatusSection` shows a
  "Sync paused while dev mode is on" row so the Settings screen
  isn't self-contradictory when the sandbox is active.

## Surprises and how we handled them

### `onChange(..., initial: true)` broke the persistence contract

- **What happened**: the first wiring of the toggle used
  `.onChange(of: isDevMode, initial: true)`, which called
  `activateDevMode()` on every cold launch. That wiped the sandbox
  file and reseeded, breaking the "edits persist across launches
  while dev mode stays on" promise.
- **What we did**: switched to edge-triggered `onChange` (explicit
  old/new comparison for the off→on transition) and pushed
  "seed if the habit table is empty" into `DevModeController.
  devContainer()`. Result: launches with the flag already on read
  the existing sqlite file as-is; first-ever activation or a
  wipe-and-rebuild still seeds.
- **Lesson**: `initial: true` on `onChange` is a convenient way to
  fire setup code, but it's stateless — the callback can't tell
  "app just launched with X already true" from "user just flipped
  X to true." If the two paths need different behavior, don't use
  `initial: true`.

### The `.id(isDevMode)` safety net wasn't safe

- **What happened**: the research flagged a risk that changing the
  container passed to `.modelContainer(...)` might not re-fetch
  `@Query`, and suggested `.id(isDevMode)` on the root view as a
  fallback. We pre-emptively added it, and the trade-off showed
  up in user testing — flipping the toggle reset the selected tab
  and any in-flight navigation stack.
- **What we did**: removed the `.id`. SwiftUI propagates the new
  container to `@Query` automatically; data refreshes in place,
  navigation state is preserved.
- **Lesson**: a "defensive" modifier you add without testing the
  unforced path first costs real UX. When you suspect a framework
  might not do the right thing, try without the workaround and
  measure; don't ship the workaround speculatively.

### MainActor defaults on a `@MainActor @Observable` init

- **What happened**: `DevModeController.defaultDevStoreURL` and
  `defaultProductionContainer()` were initially plain `static`s on
  the MainActor-isolated class. Swift 6 warned that evaluating
  them as default-argument expressions (at a caller that might be
  nonisolated) converts a `@MainActor () -> ModelContainer` to
  `() -> ModelContainer` and loses isolation.
- **What we did**: marked both `nonisolated static`. Neither touches
  MainActor state (URL arithmetic + `ModelContainer.init` are both
  fine off-actor), so the isolation drop was safe.
- **Lesson**: `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` already
  bit us with `CloudContainerID` and `DefaultCKAccountStatusProvider`.
  Static defaults used as default arguments on MainActor types need
  `nonisolated` — add this to the existing note in `CLAUDE.md`.

## What worked well

- **Injecting container factory + URL into `DevModeController`**
  kept tests honest: the controller is exercised end-to-end without
  constructing a real CloudKit container or writing into the app's
  real Application Support.
- **Seed function was already a single entry point**. Moving it
  from Preview Content to Services was a two-line change — no
  rewrite, no duplication.
- **Plan's staged decomposition** (extract → controller → wire →
  toggle → verify) meant each commit left the app in a working
  state, including the tests.
- **`seed-if-empty` is a clean invariant**. Both the cold-launch
  path and the off→on wipe path end up in the same "empty
  container" state, so one branch covers both.

## For the next person

- **Real data is untouched.** The toggle never writes to the prod
  container. If you see something odd about the prod store while
  working on dev mode, look elsewhere — dev mode cannot corrupt it.
- **`KadoDev.sqlite` is intentionally left on disk when dev mode
  is turned off.** That's not a leak; it's cached state so the
  user's in-progress dev session survives app launches. Wiping
  happens on the next off→on transition.
- **Don't add `.id(isDevMode)` back** unless you've confirmed the
  container swap stopped propagating to `@Query`. It's the kind of
  modifier that looks harmless but eats navigation state.
- **Prod container is still cached.** `DevModeController` holds it
  for the app's lifetime. If you later add a "reset real data"
  path, drop that cache too.
- **`@AppStorage("kado.devMode")` is read in two places**: `KadoApp`
  (to pick the container) and `SyncStatusSection` (to show the
  paused row). Keep them in sync if the key changes.
- **When `KadoSchemaV2` ships**, both containers pick it up
  automatically via `KadoMigrationPlan`. The dev sandbox will be
  migrated on first access; if migration ever gets messy, the
  user can always toggle off/on to reseed.

## Generalizable lessons

- **[→ CLAUDE.md]** Don't use `.onChange(of: X, initial: true)` for
  setup that should distinguish "launch with X=true" from "user
  just set X=true." The callback is stateless; use
  edge-triggered `onChange` and handle the at-launch case
  elsewhere (e.g. lazy init keyed on presence/absence of state).
- **[→ CLAUDE.md]** Swapping `.modelContainer(_:)` at runtime does
  propagate to `@Query` in place — no `.id(...)` remount required.
  Adding `.id` as a defensive swap-trigger resets navigation state
  and is usually wrong.
- **[→ CLAUDE.md]** Static defaults evaluated as default arguments
  on a `@MainActor`-isolated type must be `nonisolated static`
  under `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`. Extends the
  existing `CloudContainerID` / `DefaultCKAccountStatusProvider`
  note.
- **[local]** When a feature shows a status ("Synced"), check
  whether a sibling toggle/mode can contradict it, and reconcile
  in the UI (the "paused" row).

## Metrics

- Tasks completed: 5 of 5
- Tests added: 3 (in `DevModeControllerTests`)
- Commits on branch: 8 (3 docs + 5 code)
- Files touched: ~7

## References

- `Kado/App/DevModeController.swift` — the state machine.
- `Kado/Services/DevModeSeed.swift` — the seed used by both the
  sandbox and SwiftUI previews.
- `Kado/App/KadoApp.swift` — the `@AppStorage` → `.modelContainer`
  wiring.
- Apple: [SwiftData `ModelConfiguration`](https://developer.apple.com/documentation/swiftdata/modelconfiguration).
