# Plan — Widget habit selection

**Date**: 2026-09-07
**Status**: ready to build
**Research**: none — planned directly from the request, so the assumptions below carry the weight research usually would.

## Summary

The three home widgets each show whatever the snapshot hands them: the small and medium tiles take every habit due today, the large one takes every active habit, and each truncates to a hard-coded limit. Which habits you see is therefore an accident of sort order. This adds a per-widget configuration so the user picks the habits each placed widget shows, and settles the capacities at five (small), eight (medium) and five (large) — the large one drops from six.

## Decisions locked in

These were judgement calls, not things the request settled. Each is cheap to reverse; flagged here and in the PR so they can be.

- **Per placed widget, not one global setting.** "Customization settings to widgets" reads as the platform's own widget-edit sheet (long-press → Edit Widget), which is where iOS users look for this. It also means two small widgets can show different habits, which a global setting could not.
- **An empty selection shows everything, as today.** A freshly added widget has no pick yet and must not render blank, so "no selection" means "all of them, up to the limit" rather than "none".
- **The user's pick order is the display order.** Selecting habits deliberately implies an order; honouring it hands the user widget-level ordering for free, independent of the app's sort order.
- **The Today widgets still only show what's due.** A picked habit that isn't due today stays absent from the small and medium tiles — they exist for tap-to-complete, and a row you cannot act on would be noise. The large tile is a weekly grid and shows every pick.
- **One `SelectHabitsIntent` for all three families, not three intents.** Originally justified as "AppIntents has no max-count on an array parameter, so the cap is enforced at render time either way" — which was wrong, and corrected during build: `@Parameter(size: [IntentWidgetFamily: IntentCollectionSize])` caps the picker per family, on a single intent, from iOS 18. The one-intent shape survives, for a better reason than the one it was chosen for.
- **Selection filtering is a free struct in KadoCore**, not view code — it is conditional business logic, so it gets tests (`CLAUDE.md`, Testing § Philosophy).

## Task list

### Task 1: Selection logic + limits, tests first

**Goal**: A pure, tested function that turns (snapshot, picked ids, limit) into the rows a widget should draw.

**Changes**:
- `Packages/KadoCore/Sources/KadoCore/Widgets/WidgetHabitSelection.swift` — `todayRows(from:selecting:limit:)` and `matrixRows(from:selecting:limit:)` over a shared generic pick.
- `WidgetHabitLimit` — `small = 5`, `medium = 8`, `large = 5` in one greppable place.

**Tests / verification** (`KadoTests/WidgetHabitSelectionTests.swift`, written first):
- Empty selection returns everything, truncated to the limit.
- A selection returns exactly the picked rows, in pick order, not snapshot order.
- Ids with no matching row (deleted, archived, not due today) are dropped rather than leaving a hole.
- A selection longer than the limit truncates to the limit.
- A duplicate id yields one row.

**Commit**: `feat(widget): add habit-selection filtering with per-family limits`

---

### Task 2: The configuration intent and its timeline provider

**Goal**: Give the home widgets an intent to configure and a provider that reads it.

**Changes**:
- `Packages/KadoCore/Sources/KadoCore/Services/Intents/SelectHabitsIntent.swift` — `WidgetConfigurationIntent` with `@Parameter var habits: [HabitEntity]?`. `HabitEntity` and its snapshot-backed query already exist for the lock widgets and need no change.
- `Packages/KadoCore/Sources/KadoCore/Widgets/SelectedSnapshotProvider.swift` — `AppIntentTimelineProvider` emitting `SelectedSnapshotEntry` (snapshot + picked ids), mirroring `PickedSnapshotProvider`.

**Tests / verification**: entry plumbing is trivial; covered by Task 1's tests plus the build. No new suite.

**Commit**: `feat(widget): add the habit-selection configuration intent`

---

### Task 3: Move the three home widgets onto it

**Goal**: The widgets read the configuration and honour the new capacities.

**Changes**:
- `TodayGridSmallWidget`, `TodayProgressMediumWidget`, `WeeklyGridLargeWidget` — `StaticConfiguration` → `AppIntentConfiguration`, limits from `WidgetHabitLimit` (large 6 → 5), rows through `WidgetHabitSelection`.
- `KadoWidgets/Resources/Localizable.xcstrings` — the three `description` strings gain the capacity, with FR.
- `PreviewSnapshots` / `#Preview`s — add a picked-subset preview per family.

**Tests / verification**: `make test`, full-scheme build clean, plus the manual widget-edit check below.

**Commit**: `feat(widget): let each home widget show the habits you pick`

## Risks and mitigation

- **`StaticConfiguration` → `AppIntentConfiguration` on an unchanged `kind`.** Widgets already on a user's Home Screen get a default-initialised intent, which means an empty selection — which by the decision above means "show everything", i.e. exactly what they showed before. So the migration is invisible if the fallback is right, and this is the reason the fallback has to be "all" rather than "none". Verify by installing over an existing build with a widget already placed.
- **Intent strings are not localized.** KadoCore has no string catalog, so `PickHabitIntent`'s title and parameter names already ship in English in the French build. The new intent inherits that hole rather than widening it; adding a package catalog touches every existing intent and belongs in its own change. Noted as a follow-up, not fixed here.
- **`HabitEntityQuery` reads the App Group snapshot.** If the snapshot is stale or missing, the picker offers nothing. Pre-existing for the lock widgets; the app rebuilds the snapshot on every mutation.
- ~~**Capacity vs. selection mismatch.** Nothing stops the user picking eight habits and putting them on a small tile. The extra three are trimmed silently; the widget's description states the number up front.~~ **This shipped and was wrong.** Accepting it as a documented limitation was the mistake — silently discarding a choice the UI accepted is a bug, not a trade-off. Fixed during build with the per-family `size:` cap; the render-time `prefix(limit)` stays as defence for widgets configured before the cap existed.

## Open questions

- [ ] Should a picked-but-not-due habit appear greyed on the Today widgets instead of vanishing? Decided "vanishes" for now; the lock widgets' `pickedHabit` fallback shows the alternative exists if this feels wrong in use.
- [ ] Is five the right large-widget capacity now that each row also carries a streak and score? Taken as given from the request.

## Out of scope

- The lock-screen widgets, which already pick a single habit through `PickHabitIntent`.
- Any in-app Settings surface — configuration lives in the widget-edit sheet.
- Localizing the AppIntents strings in KadoCore (see risks).
