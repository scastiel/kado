---
name: Widgets research
description: v0.2 WidgetKit pass covering home (small/medium/large) and lock-screen (rectangular/circular/inline) surfaces
type: project
---

# Research — Widgets

**Date**: 2026-04-18
**Status**: draft
**Related**: `docs/ROADMAP.md` § v0.2 / Widgets; prior plans `cloudkit-sync/`, `multi-habit-overview/`, `today-row-actions/`, `swiftdata-models/`

## Problem

Kadō users can't see or act on their habits without opening the app.
v0.2's "visible iOS-native" theme closes that gap with WidgetKit
surfaces — home and lock screen. Widgets matter because a habit
tracker that requires opening the app every time loses against
system-level friction (one tap from Home vs. three taps through the
app switcher). Kadō's score-shaded cells also translate well to
glance-sized UI, so widgets double as a visible differentiator
against binary-checkmark competitors.

Scope for this pass: **all six surfaces** named in the roadmap.
- Home small: today's grid (5-6 habits max)
- Home medium: grid + progress summary
- Home large: weekly grid (habits × days, reusing Overview)
- Lock rectangular: one-habit row with mini score bar
- Lock circular: one-habit progress ring (or "N / M done today")
- Lock inline: one-line text summary

Done, from the user's side: widgets appear in the picker, render
real habit data offline, update within minutes of a completion, and
(on home screen) tapping a cell can complete a binary habit without
a context switch.

## Current state of the codebase

### What's ready to reuse

All of the "heavy" pieces are pure value types or stateless
structs — widgets can import them directly:

- **Domain values** — `Habit`, `Completion`, `HabitColor`,
  `Frequency`, `HabitType`, `HabitRowState`, `DayCell` — all
  `Sendable` + `Codable` (`Kado/Models/*.swift`).
- **Calculators** — `DefaultHabitScoreCalculator`,
  `DefaultFrequencyEvaluator`, `DefaultStreakCalculator` — plain
  structs with an injectable `Calendar`, no ModelContext
  dependency (`Kado/Services/Default*.swift`).
- **Matrix compute** — `OverviewMatrix.compute(...)` returns the
  exact shape the large widget wants (`Kado/Services/OverviewMatrix.swift:43`).
- **Presentational views** — `HabitRowView`
  (`Kado/UIComponents/HabitRowView.swift:17`) and `MatrixCell`
  (`Kado/UIComponents/MatrixCell.swift:7`) take only props, no env.
  They need resizing to fit widget families but the content logic
  is reusable.
- **Schema** — `KadoSchemaV2` + `KadoMigrationPlan` are the single
  source of truth; widgets open the same `ModelContainer`.

### What's missing (blocking)

- **No widget target.** Only `Kado` + `KadoTests` exist in
  `Kado.xcodeproj` (pbxproj lines 153–156). `KadoWidgets/` is
  documented in CLAUDE.md but not on disk.
- **No App Group entitlement.** `Kado/Kado.entitlements` has
  CloudKit (`iCloud.dev.scastiel.kado`) but no
  `com.apple.security.application-groups`. Widget can't share the
  SwiftData store with the app until this is added on both
  targets.
- **No `AppIntent` types.** Roadmap lists them for v0.3, but
  iOS 17+ interactive widgets require `AppIntent` conformance for
  tap-to-complete. v0.2 Notifications also need intents (check /
  skip from the lock screen). See Open Questions.
- **No URL scheme / deep-link handling.** Non-interactive widgets
  tap-to-open the app — we'd either register a URL scheme or use
  `widgetURL(_:)` + `NavigationPath`. Minor, but new code.
- **No `TimelineProvider` infrastructure.** Cadence, placeholder
  seeding, and refresh strategy all need to be designed.

### Dev mode interaction

`DevModeController` (`Kado/App/DevModeController.swift:16`) swaps
the `ModelContainer` at runtime between production CloudKit and an
on-disk dev SQLite (`~/Library/Application Support/KadoDev.sqlite`).
Widgets run in a separate process and won't see the dev flag in
`@AppStorage` unless it's moved into `UserDefaults(suiteName:)` on
the App Group. Two reasonable stances — see Open Questions.

## Proposed approach

**One widget extension target (`KadoWidgets`) hosting all six
widgets, backed by an App Group-shared SwiftData store, with
interactive completion via a new `CompleteHabitIntent`.**

### Data-sharing strategy: App Group + shared SwiftData URL

Move the SwiftData production store into the App Group container
(`group.dev.scastiel.kado`). Both app and widget open the same
`ModelContainer` with `cloudKitDatabase: .private(CloudContainerID.kado)`
— CloudKit continues to sync on the app side; the widget reads the
local SQLite directly.

Why this over alternatives:
- Single source of truth — widget shows exactly what the app sees.
- No custom serialization layer to maintain or keep in sync on
  every write.
- Widget process doesn't need CloudKit auth/network on wake; read
  is local SQLite.
- Scales to Apple Watch (v0.3) using the same pattern.

### Interactivity: bring `CompleteHabitIntent` forward from v0.3

Define `CompleteHabitIntent: AppIntent` in a new
`Kado/Services/Intents/` folder, shared between app and widget
target. Home small / medium widgets wire the cell `Button(intent:)`
to it. This is the same intent v0.3 will expose to Siri — building
it now advances both features and is the only way to make iOS 17+
widgets interactive.

Counter/timer habits can't be meaningfully incremented from a
widget in one tap — tapping opens the app at the habit detail via
`widgetURL` fallback.

### Widget configuration

- **Home small/medium** — no configuration, auto-select "habits
  due today," ordered by `createdAt`, capped at 5/8 rows.
- **Home large** — no configuration, reuses Overview's 7-day
  window ending today.
- **Lock rectangular/circular** — `WidgetConfigurationIntent` lets
  the user pick a single habit (or "overall progress" for
  circular). Without this, lock widgets are either all-or-nothing
  or guess wrong.
- **Lock inline** — auto "N of M habits done today."

### Key components

- **`KadoWidgets/` target** — one extension, multiple
  `Widget`/`WidgetBundle` registrations for the six surfaces.
- **`SharedStore`** (new, `Kado/App/SharedStore.swift`) — resolves
  the App Group SQLite URL and hands back a configured
  `ModelContainer`. Used by both app and widgets so the URL logic
  lives once.
- **`CompleteHabitIntent`** (`Kado/Services/Intents/CompleteHabitIntent.swift`)
  — the first `AppIntent`. Takes a `HabitEntity` (new, lightweight
  `AppEntity` wrapping habit ID + name) and writes a completion
  via a shared `CompletionToggler`-style helper.
- **`HabitTimelineProvider`** (per widget kind, or one generic) —
  loads habits, computes today's row state or matrix, emits
  entries for the next ~6 hours (refresh roughly hourly; system
  has final say).
- **Widget views** — `TodayGridWidgetView`, `WeeklyGridWidgetView`,
  `LockRectangularWidgetView`, `LockCircularWidgetView`,
  `LockInlineWidgetView`. Each takes a value-type entry, reuses
  `HabitColor`, `MatrixCell`-style cell rendering.

### Data model changes

None to `@Model` types. Two adjustments:
1. `ModelConfiguration` gains an explicit `url:` pointing into the
   App Group container (replacing the default app-container
   location). Needs a one-time migration for existing installs —
   on first launch, copy the old SQLite to the new location if
   present.
2. `@AppStorage("devModeEnabled")` moves to
   `UserDefaults(suiteName: "group.dev.scastiel.kado")` if we want
   widgets to follow the dev sandbox — otherwise widgets always
   read production (acceptable; see Open Questions).

### UI changes

None to app views. New widget views in `KadoWidgets/`. A couple of
app-side surface touches are worth anticipating:
- Settings gains "Widgets" row later (post-v0.2) — out of scope
  now.
- No "edit in app" buttons need adjustment.

### Tests to write

- `SharedStoreTests`: App Group URL resolution, migration from
  app-container SQLite to group-container SQLite (with and without
  prior store present).
- `CompleteHabitIntentTests`: intent toggles a binary habit
  correctly; is idempotent for already-completed today; doesn't
  touch counter/timer habits (must fail gracefully — app-open
  fallback).
- `TodayWidgetEntryTests`: given a seeded container and a fixed
  `Calendar`, the timeline entry lists the right habits in the
  right order, with the right `HabitRowState.status`.
- `WeeklyWidgetEntryTests`: matrix shape matches
  `OverviewMatrix.compute(...)` output for the same inputs.
- `LockConfigurationTests`: configuration intent's `habit`
  parameter resolves to the correct `HabitEntity` for a given ID.
- Snapshot tests: **skip for now** — CLAUDE.md's "cheap insurance"
  pixel-check is a `screenshot` on simulator in the done gate, not
  a stored snapshot library.

## Alternatives considered

### Alternative A: CloudKit-direct from widget

- Idea: widget target opens `ModelContainer` with
  `cloudKitDatabase: .private(...)` and no shared local store;
  each wake re-syncs.
- Why not: widget process has strict memory + wake-time budgets,
  and CloudKit auth on cold start adds latency. Widgets would
  render stale-then-refresh, which looks broken. Also duplicates
  sync overhead across app and widget processes.

### Alternative B: App-writes-snapshot JSON to App Group

- Idea: on every completion/edit, app serializes a
  "widget snapshot" struct to a JSON file in the App Group;
  widget reads only that file.
- Why not: every new widget surface adds a field to the snapshot
  schema. Drift risk — missed write path = stale widget forever.
  And we still need App Group setup, so we pay that cost without
  getting SwiftData's guarantees. Reasonable fallback if Option A
  hits SwiftData-in-widget issues (see Risks).

### Alternative C: Read-only widgets, defer `AppIntent`

- Idea: ship v0.2 widgets as tap-to-open only; bring `AppIntent`
  in v0.3 alongside Siri.
- Why not: the v0.2 Notifications section already needs intents
  (notification action → complete habit). We'd build the same
  intent either way. And tap-to-open widgets are ~50% of the
  value — a small widget that requires opening the app to
  complete is worse than no widget.
- If we're time-constrained, this is the right thing to sacrifice:
  ship read-only first, add interactivity in a follow-up.

## Risks and unknowns

- **SwiftData + App Group + CloudKit**: the combination is
  supported but low-traffic in the wild. Risk that
  `ModelContainer.init` with `cloudKitDatabase: .private(...)` +
  an explicit App Group URL hits an undocumented edge case.
  **Mitigation**: 30-minute smoke test before committing to the
  approach — build a throwaway widget that opens the store and
  logs counts, verify on a real device (not just sim — CloudKit
  in widget processes behaves differently).
- **Store migration**: existing TestFlight/dev users have a SQLite
  at the default app-container URL. First launch after the widget
  release must detect and copy it to the App Group URL. If we
  miss this, those users start fresh with a CloudKit resync —
  disruptive.
- **Timeline refresh budget**: iOS throttles widget reloads
  aggressively. A habit completed in-app should trigger
  `WidgetCenter.shared.reloadAllTimelines()`; without that, the
  widget shows stale state until the next scheduled reload.
- **Dev mode divergence**: if widgets always read production,
  dev mode's seeded sandbox shows in the app but not in widgets.
  Confusing for the author, irrelevant for end users. See Open
  Questions.
- **Interactive widget requirements**: `Button(intent:)` in widget
  views needs iOS 17+. Kadō targets iOS 18+ (CLAUDE.md line 16),
  so this is fine — but it changes nothing for iOS 16 users
  (we have none).
- **Xcode 26 SwiftData enum bug** (documented in
  `docs/plans/2026-04/swiftdata-models/plan.md:189`): already
  worked around in the schema via JSON `Data` blobs; widgets
  inherit the workaround transparently when they read the same
  schema.

## Open questions

- [ ] **App Group identifier** — proposed
  `group.dev.scastiel.kado`. Confirm or pick a different scheme.
- [ ] **AppIntent scope in v0.2** — ship interactive widgets
  (requires `CompleteHabitIntent` now), or ship read-only widgets
  and defer all intents to v0.3? Recommendation: build the intent
  now; it's the path of least duplication with v0.2 Notifications.
- [ ] **Dev mode in widgets** — widgets always read production
  (simpler, acceptable), or widgets also honor the dev-mode
  toggle via a shared UserDefaults (more faithful, more plumbing)?
  Recommendation: production-only for v0.2.
- [ ] **Configurable lock widgets** — add a
  `WidgetConfigurationIntent` letting users pick which habit
  appears on rectangular / circular? Recommendation: yes for both
  (the alternative is "we pick for you," which is guaranteed to
  be wrong for some users).
- [ ] **Inline lock widget** — "3 / 5 done today" is the obvious
  default. Anything more ambitious?
- [ ] **Home large = weekly grid**: reuse `OverviewMatrix` with a
  fixed 7-day window, or add a dedicated timeline provider? The
  matrix is already stateless so direct reuse seems fine.

## References

- Apple: [Creating a widget extension](https://developer.apple.com/documentation/widgetkit/creating-a-widget-extension)
- Apple: [Making a configurable widget](https://developer.apple.com/documentation/widgetkit/making-a-configurable-widget)
- Apple: [Adding interactivity to widgets](https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities)
- Apple: [App Intents framework](https://developer.apple.com/documentation/appintents)
- Prior plan: `docs/plans/2026-04/cloudkit-sync/plan.md` (entitlements discipline)
- Prior plan: `docs/plans/2026-04/multi-habit-overview/plan.md` (cell layout + matrix compute)
- Prior plan: `docs/plans/2026-04/swiftdata-models/plan.md` (schema invariants, enum-storage bug)
