# Compound — Widget habit selection

**Date**: 2026-09-07 · second attempt 2026-09-20
**Status**: complete
**Plan**: [plan.md](./plan.md) · **Research**: [research.md](./research.md)
**Branch / PR**: first attempt `worktree-widget-large-metrics` — [#76](https://github.com/scastiel/kado/pull/76), reverted; second attempt `feature/widget-habit-selection` for [#77](https://github.com/scastiel/kado/issues/77)

## Second attempt — what changed and what was learned

The first attempt below was reverted the same evening because the widget extension could not read back a stored pick, and the issue that carried the diagnosis pointed at the KadoCore package as the likely cause with "move the entity into the extension" as the next step. The second attempt did not start by building that. It started by asking what "registered" meant inside AppIntents, and found that nothing was wrong with the code.

### The blocker was the simulator's signature, not the package

- **What happened**: the same `SelectHabitsIntent` — `[HabitEntity]?` in KadoCore, per-family `size:` caps — decoded a stored pick on an iOS 27 simulator as-is, cold extension process and warm. On an iOS 26.5 simulator it decoded to an empty array, and AppIntents' own debug log said why: `linkd` had rejected the extension's request for the entity metadata (`Failed to generate bundleIdentity … Unable to get teamId … Rejecting invalid client due to requiresValidBundle`). Xcode signs simulator builds ad hoc, with no team identifier, and refuses any other identity for the simulator SDK. Re-signing the built products with the keychain's Apple Development identity and reinstalling over the same placed widget: `picked=2`.
- **What we did**: kept every intent and entity in KadoCore, as the project's rule says; added `Scripts/resign-simulator.sh` and made `make run` call it; recorded the trace in `research.md` and the rule in `CLAUDE.md`.
- **Lesson**: **a "not registered" failure in a system framework is a question about the process, not about the module the type is compiled into.** The DTS answers and forum threads that point at Swift packages are describing a different, build-time failure (metadata never extracted); ours had correct metadata and a runtime daemon saying no. Read the daemon's log before restructuring the code — `com.apple.appintents` at `--level debug` said the whole story in one line, and #76 never streamed it.

### The lock-screen picker was never broken

- **What happened**: #77 suspected `PickHabitIntent` had "never persisted either". Hosting its exact code path on a home widget and reading the log showed `picked=1` on iOS 27, and the same `linkd` rejection on an ad-hoc 26.5 build. Production builds are team-signed. Nothing to fix, and the fear that shaped the issue's priority was a simulator artefact.
- **Lesson**: before promoting a suspicion to a production bug, reproduce it under the conditions production runs under — here, a signed build — or at least name the condition that differs.

### The reverted summary miscounted negative habits

- **What happened**: `WidgetHabitSelection.progress` counted a pick's done rows as `status == .complete`. `WidgetSnapshotBuilder` builds the whole-day tally with `HabitRowState.isDone`, where a negative habit's `.complete` is a slip. The picked summary would have said "1 / 1 done" for a "don't" habit the user had just given in on.
- **What we did**: `WidgetTodayRow.isDone`, the rule's widget-side twin; `progress` uses it; a builder test pins `completedToday == today.filter(\.isDone).count` so the two cannot drift.
- **Lesson**: when a view re-derives a number the model already computes, derive it *through the model's rule* — a twin with a name — not by re-reading the raw status.

### Driving the Home Screen without a human

- **What happened**: XcodeBuildMCP has no taps; its bundled `axe` loads on Xcode 27 only through a symlinked shadow `Xcode.app`, and then reads the tree but drops every tap. A throwaway XCUITest against `com.apple.springboard` placed each widget, opened **Edit Widget**, worked the list editor and picked habits, on both runtimes, with the verdict read from the console log. Two traps: `xcodebuild test` sometimes never exits after the suite (the log is complete; kill it), and tapping the status bar does not dismiss the edit sheet — tap the blurred area below it.
- **What we did**: kept the driver out of the suite, per the decision to defer a shipped SpringBoard test; wrote the recipe into `CLAUDE.md`.

### `make test` on an iOS 27.0 simulator

- **What happened**: the unit-test host crashed non-deterministically in whichever SwiftData suite was running (`No eligible connection available`), and `-quiet` reported every remaining test as failed. Green on an iOS 26.5 device, twice.
- **What we did**: ran the suite on 26.5; noted the runtime in `CLAUDE.md`.

### Metrics, second attempt

- Commits: 7 (log line, docs, selection logic, intent + provider, widgets, manifest test, tooling) + this compound.
- Tests added: 15 (`WidgetHabitSelectionTests`) + 5 (`WidgetIntentManifestTests`) + 1 builder invariant; 655 tests in 67 suites green on iOS 26.5.
- Verified by log on iOS 27.0 (ad hoc) and iOS 26.5 (re-signed): small `picked=2`, medium `picked=3`, large `picked=3`, cold extension process; the not-due placeholder; dark mode.

---

## First attempt (2026-09-07), as written

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

### Two pieces tested, the seam between them not

- **What happened**: the selection filter had ten tests and the picker's caps had a manifest test, and the widget still ignored the selection. Nothing covered `HabitEntityQuery.entities(for:)` — the step where AppIntents rebuilds a stored pick — and it had a real defect: it resolved ids against the snapshot's own order, so a pick came back re-sorted into app order, silently undoing "pick order is display order".
- **What we did**: split the pure resolution out as `HabitEntityQuery.resolve(identifiers:in:)` (so a test needn't write into the App Group container the installed app uses) and covered order, misses and the empty case.
- **Lesson**: testing both ends of a pipeline is not testing the pipeline. The untested seam is the one that carries the user's data, and it was invisible precisely because both neighbours were green.

### An empty resolution is indistinguishable from "no pick", and means the opposite

- **What happened**: `entities(for:)` returning `[]` — snapshot unreadable, ids stale — flows upstream as an empty selection, which the widgets read as *show everything*. A pick that fails to resolve doesn't look broken; it looks unconfigured.
- **What we did**: made resolution drop only the ids that miss, so a partial failure reduces the pick rather than erasing it, and pinned the consequence in a named test so the next person meets it in writing.
- **Lesson**: when a fallback means "the opposite of what the user asked for", every path that can silently produce it needs to be enumerated. "Empty means show everything" is convenient for a fresh widget and dangerous for a failed read.

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
