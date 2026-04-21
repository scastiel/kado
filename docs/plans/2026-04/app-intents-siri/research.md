# Research — App Intents and Siri

**Date**: 2026-04-20
**Status**: draft
**Related**: [`docs/ROADMAP.md` v0.3](../../../ROADMAP.md),
[`CompleteHabitIntent.swift`](../../../../Packages/KadoCore/Sources/KadoCore/Services/Intents/CompleteHabitIntent.swift)

## Problem

v0.3's first track is "App Intents and Siri": the user should be able
to say "Hey Siri, mark Meditate as done", "I drank two glasses of
water", "What's my meditation streak?" — and have iOS surface those
as Shortcuts automations without the user configuring anything.
Today Kadō ships one `AppIntent` (`CompleteHabitIntent`) used **only
from widgets** — it's invisible to Siri because no
`AppShortcutsProvider` is registered.

Three gaps to close:

1. Expose intents to Siri / Shortcuts via an `AppShortcutsProvider`.
2. Build two new intents — `LogHabitValueIntent` (counter / timer)
   and `GetHabitStatsIntent` (read-only stats).
3. Seed `suggestedInvocationPhrase` + `AppShortcut` parameter
   prompts so the Shortcuts app discovers them contextually
   (morning / evening via `ShortcutTile` if we go that far).

## Current state of the codebase

### What's built

- **`HabitEntity`** (`Packages/KadoCore/.../Intents/HabitEntity.swift`)
  — an `AppEntity` backed by the widget's App Group JSON snapshot.
  Same query works in any process (main app, widget extension,
  hypothetical Intents extension) because it reads a file, not
  SwiftData. Good foundation.
- **`CompleteHabitIntent`** — toggles binary / negative habits,
  refuses counter / timer (`returns .opensApp`). Reuses
  `ActiveContainer.shared` primed by `KadoApp`. `openAppWhenRun =
  true`. Fully tested against an in-memory `ModelContainer`.
- **`PickHabitIntent`** — widget-only `WidgetConfigurationIntent`;
  not user-facing for Siri.
- **Domain services** the new intents need:
  - `DefaultStreakCalculator` — `current(for:completions:asOf:)` +
    `best(for:completions:asOf:)`
  - `DefaultHabitScoreCalculator` — `currentScore(...)` returns
    `Double` in `[0, 1]`
  - `CompletionToggler` — already the "toggle today" primitive

### What's missing

- No `AppShortcutsProvider` anywhere in the project. Siri can't see
  any intent.
- No intent `ProvidesDialog` or `IntentDialog` usage — zero spoken
  output plumbed. Counter / timer completion dialog prompts (value
  resolution) haven't been designed.
- No localization strings for intent titles / prompts / dialogs in
  `Localizable.xcstrings`. All existing intent copy is hardcoded
  `LocalizedStringResource` literals — the catalog doesn't have
  entries for them yet (Xcode IDE would extract on next build; we
  author by hand here — see CLAUDE.md).

### Architectural constraint (critical)

From `CLAUDE.md` SwiftData section and the `CompleteHabitIntent`
header comment: **two CloudKit-attached SwiftData containers in the
same process — or in two processes — trap at runtime**
(`NSCocoaErrorDomain 134422`). That's why the existing intent sets
`openAppWhenRun = true` and reuses `ActiveContainer.shared` instead
of opening its own container.

Implication for Siri UX: a silent-in-the-background completion via
an Intents extension process would need SwiftData access → trap.
Writing to the App Group JSON snapshot from an extension and
reconciling later is possible but breaks the "completions are
live" assumption widgets rely on.

**Verification target** (open question, see below): on iOS 18+,
does `openAppWhenRun = true` + an `IntentDialog` result give us
Siri-speaks-and-the-app-stays-backgrounded, or does the app
visually foreground every time? Apple's docs suggest the former
when `perform()` doesn't present UI, but this needs a
2-minute smoke test before the design locks in. If the app
foregrounds, the user's requested "silent w/ spoken reply" UX is
architecturally blocked and we need to confirm the fallback.

## Proposed approach

Single bundled research → plan → build cycle covering all four
items, gated by a smoke test at the top of the build stage.

### Key components

- **`KadoAppShortcuts: AppShortcutsProvider`** (new, main app
  target) — registers all three user-facing intents with a default
  invocation phrase ("Complete habit in Kadō", "Log habit value in
  Kadō", "Get habit stats from Kadō"). Must live in the main app
  target (Siri reads it from the main bundle's Info plist).
- **`CompleteHabitIntent`** (refactor) — add `ProvidesDialog`
  conformance + `IntentDialog` response so Siri speaks the result.
  Keep `openAppWhenRun = true` as the architectural floor but
  verify the background-launch behavior first. Counter / timer
  case still opens the app to the habit detail (unchanged).
- **`LogHabitValueIntent`** (new) — parameters: `habit`
  (`HabitEntity`, required), `value` (`Double`, required with
  prompt). Writes a `CompletionRecord` with the given value for
  today via `CompletionToggler` (needs a new method
  `setValueToday(_:for:in:)` that overwrites rather than toggles).
  Refuses binary / negative (returns dialog "Meditate is a yes/no
  habit — say 'Complete Meditate' instead").
- **`GetHabitStatsIntent`** (new) — parameters: `habit` only.
  Read-only: no mutation, so it can use `ActiveContainer` if the
  app is alive or fall through to a fresh read-only
  `ModelContainer` attached with `cloudKitDatabase: .none`. Returns
  an `IntentDialog` summarizing current streak + score + today's
  completion state. Snapshot-backed fallback path TBD (see
  Alternatives).
- **`AppShortcut` phrases** — per intent, with parameter
  interpolation: `"Complete \(.applicationName) habit \(\.$habit)"`,
  `"Log \(\.$value) for \(\.$habit) in \(.applicationName)"`,
  `"Stats for \(\.$habit) in \(.applicationName)"`.
- **Contextual suggestions** — iOS 18's `ShortcutTile` / `Tip` API
  surfaces shortcuts on the lock screen and in Shortcuts based on
  time-of-day and relevance heuristics. Minimum viable: set
  `suggestedInvocationPhrase` on each intent and rely on iOS's
  built-in learning. Stretch: implement `ShortcutTile` with
  morning/evening visibility predicates.

### Data model changes

None. Existing schemas cover all three intents. `CompletionToggler`
gains a method; no schema bump.

### UI changes

None in v0.3 phase 1. The intents are API, not UI. Future polish:
a Settings → "Siri & Shortcuts" row linking to the system
Shortcuts app (nice-to-have, not scope).

### Tests to write

Main-app target `KadoTests/`, Swift Testing:

```swift
@Test("LogHabitValueIntent writes a completion with the given value")
@Test("LogHabitValueIntent overwrites an existing same-day completion")
@Test("LogHabitValueIntent refuses a binary habit with a spoken error")
@Test("LogHabitValueIntent refuses a negative habit with a spoken error")

@Test("GetHabitStatsIntent returns current streak for a daily habit")
@Test("GetHabitStatsIntent returns 0 streak when no completions exist")
@Test("GetHabitStatsIntent reports today-completed vs not-yet-done")
@Test("GetHabitStatsIntent formats score as a percentage 0-100")
@Test("GetHabitStatsIntent refuses an archived habit")

@Test("CompleteHabitIntent dialog reads 'Marked Meditate as done'")
@Test("CompleteHabitIntent dialog reads 'Unmarked Meditate' on toggle-off")
```

Follow the pattern of `CompleteHabitIntentTests`: in-memory
`ModelContainer`, direct `Self.apply(...)` static-method test
surface, assertions against the returned `Outcome` / `IntentDialog`
content rather than running `perform()`.

## Alternatives considered

### Alternative A: Run mutating intents in an Intents extension

- Idea: Set `openAppWhenRun = false`, host `CompleteHabitIntent` and
  `LogHabitValueIntent` in a dedicated `.appex` that attaches its
  own read-write SwiftData container.
- Why not: CloudKit's exclusive-sync lock. Two processes can't both
  attach to the mirrored store. Already cost ~10 commits to
  discover in v0.1 (see CLAUDE.md). Non-starter.

### Alternative B: Snapshot-only write path

- Idea: Extension process writes a pending-completion record to a
  shared App Group file; the main app reconciles on next launch.
- Why not: widgets read the JSON snapshot and assume completions
  are authoritative. Two writers means the widget can desync from
  SwiftData until the app launches. Also breaks
  `CompletionToggler`'s unified API. Defer to post-v0.3 if we
  decide the background-launch UX isn't acceptable.

### Alternative C: Split into three sub-features

- Idea: One PR per intent.
- Why not: the user picked "bundle all four" explicitly. The pieces
  share an `AppShortcutsProvider` registration; splitting the PR
  would mean three rounds of Siri re-registration testing. Keep
  bundled.

## Risks and unknowns

- **Background-launch behavior of `openAppWhenRun = true`** — if
  iOS foregrounds the app visually on every Siri invocation, the
  "silent w/ spoken reply" UX the user chose is architecturally
  blocked. This is the single biggest risk; the first build task
  is a 2-minute smoke test against a booted simulator before any
  intent refactor.
- **Simulator Siri triggering** — `mcp__XcodeBuildMCP` doesn't
  expose a Siri voice input path. Testing Siri end-to-end requires
  Shortcuts app triggering (MCP can launch / screenshot) or a
  physical device. Plan around the MCP-limitation flagged in
  CLAUDE.md's known limitations.
- **Localization of spoken phrases** — FR equivalents need native
  phrasing ("Valide mon habitude", not literal Siri-ese). Pull in
  the French-translations author (self) for dialog copy; don't
  machine-translate (CLAUDE.md non-negotiable).
- **`GetHabitStatsIntent` container story** — if the main app is
  suspended and Siri asks for stats, we hit the two-process trap.
  Likely solution: read from the widget snapshot instead of
  SwiftData (read-only, always fresh because the app writes it on
  every mutation). Needs a snapshot API that exposes streak /
  score. This might motivate extending `WidgetSnapshotBuilder`'s
  output schema — flag in plan stage.
- **`LogHabitValueIntent` units** — "I drank 2 glasses" vs "I drank
  200 ml". The counter habit stores a raw `Double` with a
  user-defined target, not a unit-aware quantity. First release:
  assume the user's phrasing matches the habit's unit; document the
  limitation. Unit-aware counters are a separate feature.

## Open questions

- [ ] **(Blocking for build)** Does `openAppWhenRun = true` + no UI
  in `perform()` keep the app backgrounded on iOS 18+, or does the
  app visually foreground? Smoke test target: first build task.
- [ ] Should `GetHabitStatsIntent` read from SwiftData (via
  `ActiveContainer`) or from the widget snapshot? Preference:
  widget snapshot for process-independence, but requires extending
  `WidgetHabit` with streak / score fields.
- [ ] Contextual suggestion surface — `suggestedInvocationPhrase`
  only (MVP), or `ShortcutTile` with time-of-day predicates
  (stretch)?
- [ ] Dialog copy review — draft EN + FR pair per intent before
  build, or during build as a copy-review checkpoint?

## References

- Apple, ["Making actions available to Siri"](https://developer.apple.com/documentation/AppIntents/Making-actions-available-in-Siri)
- Apple, ["AppShortcutsProvider"](https://developer.apple.com/documentation/appintents/appshortcutsprovider)
- Apple, ["Accepting information from users at runtime"](https://developer.apple.com/documentation/appintents/accepting-information-from-users-at-runtime)
- Prior art in repo: `CompleteHabitIntent.swift`, `PickHabitIntent.swift`
- CLAUDE.md SwiftData section — two-process / two-container trap
- CLAUDE.md Testing section — Swift Testing + in-memory container
  pattern
