# Compound — Widget habit selection

**Date**: 2026-09-07
**Status**: complete
**Plan**: [plan.md](./plan.md)
**Branch / PR**: `worktree-widget-large-metrics` — [#76](https://github.com/scastiel/kado/pull/76)

## Summary

Two changes landed together: per-habit streaks and scores on the large widget, then a habit picker on all three home widgets (capacities 5 / 8 / 5). The plan held — three tasks, three commits, no pivots — but two consequences of selection were not in it and had to be found by reasoning about the resulting UI rather than by a failing test: the medium widget's progress summary and the "All done" empty state both quietly start lying once the tile stops showing everything. The headline lesson is that **a filter added to a view invalidates every aggregate and every empty state that view already had**, and neither shows up as a compile error.

## Decisions made

- **Per placed widget, not one global app setting**: "customization settings to widgets" is the platform's own widget-edit sheet, and it lets two small widgets differ, which a global setting cannot.
- **An empty pick shows everything**: a new widget starts there, so the fallback has to be what the widget did before there was a pick — this is also what makes the `StaticConfiguration` → `AppIntentConfiguration` migration invisible.
- **A non-empty pick matching nothing shows nothing**: opposite meaning to an empty pick, even though the two look alike in the data. Falling back to "everything" here would fill the tile with the habits the user explicitly excluded.
- **Pick order is display order**: choosing habits is an ordering gesture too, and honouring it hands the user widget-level ordering for free.
- **One `SelectHabitsIntent`, not one per family**: AppIntents has no max-count on an array parameter, so each capacity is applied at render time regardless; the number the user needs is stated in each widget's own localized gallery description, which is per-family already.
- **Selection is a free struct in KadoCore, not view code**: conditional business logic, so it gets tests (`CLAUDE.md`, Testing § Philosophy).
- **The flame folds onto the secondary weight under the tint**: keeping orange there would be silently `.primary` at full strength, reading a step *louder* than the percentage it is meant to rank beside.

## Surprises and how we handled them

### A filter breaks the aggregate above it

- **What happened**: the medium widget prints `N / M done` from `snapshot.completedToday` / `.totalDueToday`. Once the grid below it showed a picked subset, the header was summarising habits the tile deliberately hides — "2 / 9 done" over three visible rows.
- **What we did**: `WidgetHabitSelection.progress` counts the pick when there is one and the whole day when there isn't, so an unpicked widget still reports all twelve habits even though it can only draw eight.
- **Lesson**: when you narrow what a view renders, walk every number and every empty state on that view. The compiler is silent and so are the tests, because both were correct before.

### "All done" is a claim, not a layout

- **What happened**: both Today widgets fall back to a checkmark and "All done" when there are no rows. With a pick, "no rows" also means "none of your picks are due today" — while five other habits are still owed.
- **What we did**: `TodayEmptyPlaceholder` takes an `isFilteredOut` flag and the large widget's placeholder took the same treatment; a pick that matches nothing gets its own glyph and wording.
- **Lesson**: an empty state asserts *why* it is empty. Adding a second way to be empty means adding a second empty state, or the first one starts lying.

### A computed preview fixture mints new ids every access

- **What happened**: `PreviewSnapshots.populated` was a computed `static var` that built its habits with fresh `UUID()`s. A `pickedTodayIDs` derived from it named habits that were not in the snapshot the preview then rendered, so the "picked" previews would all have shown the *empty* placeholder — and looked plausible doing it.
- **What we did**: made `populated` a stored `static let`.
- **Lesson**: a preview fixture containing generated identity must be stored, not computed, the moment anything references it twice.

### "AppIntents has no max-count on an array parameter" was simply false

- **What happened**: the plan recorded, as a locked-in decision and then as an accepted risk, that nothing could stop a user picking eight habits for a five-habit tile. That belief shaped the design. The author placed a widget, picked more than five, and reported it — correctly, as a bug.
- **What we did**: read the AppIntents `.swiftinterface` out of the SDK. `@Parameter(title:size:)` takes either an `IntentCollectionSize` or, better, a `[IntentWidgetFamily: IntentCollectionSize]` — a *per-family* cap on a single intent, available from iOS 18.0, exactly the project's deployment target. Three lines, and the picker enforces 5 / 8 / 5 itself.
- **Lesson**: two lessons, and the second is the bigger one. (1) Grep the SDK's `.swiftinterface` before asserting an API doesn't exist; it is on disk, it is authoritative, and it takes a minute. (2) **"The UI accepts a choice it then discards" is a bug, not a trade-off.** It was written down twice as a known limitation and neither writing made it acceptable. A documented silent data loss is still silent data loss.

### The toolchain claim was checkable without tapping anything

- **What happened**: the load-bearing assumption was that an array `@Parameter` of `AppEntity` renders as a multi-select in the widget-edit sheet. XcodeBuildMCP has no tap primitives, so there was no way to open that sheet.
- **What we did**: read the generated `Metadata.appintents/extract.actionsdata` out of the built `.appex`. It shows the intent under `com.apple.link.systemProtocol.WidgetConfiguration` with `valueType.array.wrapper.memberValueType.entity` and `dynamicOptionsSupport: 1`.
- **Lesson**: AppIntents compiles a declarative manifest into the bundle. Reading it is a genuine smoke test for intent shape — cheaper and more certain than a screenshot.

## What worked well

- Tests before the implementation for `WidgetHabitSelection`. The stale-id and duplicate-id rules were written down as expectations first, and both fell out of the same generic `pick` without special-casing.
- Splitting into additive commits — logic, then intent, then the rewiring that uses both. Each of the first two leaves the tree compiling with nothing referencing them, so the diff is reviewable in the order it was reasoned about.
- Reusing `HabitEntity` and `HabitEntityQuery` untouched. The lock widgets had already solved "let the user pick a habit from the App Group snapshot"; the home widgets needed only the plural.

## For the next person

- **`WidgetHabitSelection.pick` distinguishes "no pick" from "pick matched nothing" deliberately.** They differ by one `guard` and they are opposites. If you refactor it into a single filter expression you will collapse them.
- **The empty-pick fallback is load-bearing for the configuration migration.** Widgets already on a Home Screen get a default-initialised intent when `StaticConfiguration` becomes `AppIntentConfiguration`. If "empty" ever stops meaning "everything", those widgets go blank on upgrade.
- **The capacities are in `WidgetHabitLimit` and also, in words, in three localized gallery descriptions.** Changing a number means changing the EN and FR strings too, or the widget promises one thing and does another.
- **The small and medium tiles filter `snapshot.today`, which only holds habits due or logged today.** A picked habit that isn't due is absent by construction, not by a filter you can find.

## Generalizable lessons

- **[→ CLAUDE.md]** Narrowing what a view renders invalidates every aggregate and every empty state on that view, and neither the compiler nor the existing tests will say so. Walk them explicitly.
- **[→ CLAUDE.md]** A SwiftUI preview fixture that generates identity (`UUID()`) must be a stored `static let`, not a computed `static var`, as soon as anything derives from it — a computed one hands each caller a different set of ids and the preview fails in a way that looks like a plausible state.
- **[→ CLAUDE.md]** AppIntents shape can be verified without UI automation by reading `Metadata.appintents/extract.actionsdata` from the built product. Useful precisely because XcodeBuildMCP can't tap — and strong enough to assert on in a unit test, which is how the picker cap is now pinned to the render limit.
- **[→ CLAUDE.md]** Before recording "the framework can't do X", grep the SDK's `.swiftinterface` (`$(xcrun --sdk iphonesimulator --show-sdk-path)/System/Library/Frameworks/<F>.framework/Modules/<F>.swiftmodule/arm64-apple-ios-simulator.swiftinterface`). It is authoritative, it is on disk, and it takes a minute. The claim "AppIntents has no max-count on an array parameter" survived a plan, a build and a PR description before one grep disproved it.
- **[→ CLAUDE.md]** A UI that accepts a choice and then silently discards it is a bug, never an accepted trade-off — writing it down in a plan's Risks section does not make it one.
- **[local]** The lock widgets' `PickHabitIntent` / `PickedSnapshotProvider` pair is the template for the plural version; keep the two shaped alike.

## Metrics

- Tasks completed: 3 of 3
- Tests added: 10 (`WidgetHabitSelectionTests`) + 3 across the metrics work
- Commits: 5
- Files touched: 15

## References

- [#63](https://github.com/scastiel/kado/issues/63) — why widgets address habits by `UUID` and snapshot to value types.
- `Packages/KadoCore/Sources/KadoCore/Services/Intents/PickHabitIntent.swift` — the single-habit prior art.
