# Research — Daily completion reward

**Date**: 2026-09-09
**Status**: ready for plan
**Related**: [widgets research](../../2026-04/widgets/research.md),
[widgets compound](../../2026-04/widgets/compound.md),
[day-start-hour compound](../../2026-08/day-start-hour/compound.md),
`docs/ROADMAP.md` (Widgets, Rollover-aware widget refresh)

## Problem

Kadō marks a habit done with a filled pill and a haptic, and then
nothing. Finishing the *whole* day — the last scheduled habit ticked —
looks exactly like finishing the first one. The app has no moment that
says "that's everything, well done", and no glanceable place outside
the app that shows how close the day is to that moment.

Two pieces, both asked for explicitly:

1. **A confetti animation** the instant every habit scheduled for
   today is complete.
2. **A lock-screen "button" widget** (the round `accessoryCircular`
   family) showing today's progress as *completed / scheduled*.

"Done" from the user's side: tick the last due habit anywhere (Today
row, Detail, a log sheet, a widget tap, Siri), see confetti over
whatever screen they are on; glance at the lock screen and read
"3/5" in a ring that closes when the day is done.

## Current state of the codebase

### Where completions happen, and the one funnel they share

Every in-app mutation ends with `WidgetReloader.reloadAll(using:)`
(`Kado/App/WidgetReloader.swift`), and the two App Intents call the
same pair directly. All of them run
`WidgetSnapshotBuilder.rebuildAndWrite(using:)`
(`Packages/KadoCore/.../Widgets/WidgetSnapshotBuilder.swift:173`),
which already computes `completedToday` and `totalDueToday` for the
logical day, using the *same* `isDueOrLogged` rule as the Today tab.

Call sites: `TodayView` (toggle, ± counter, +5m, archive, reorder),
`HabitDetailView` ×8, `CompletionHistoryList`, `TimerLogSheet`,
`CounterLogSheet`, `NewHabitFormModel`, `BackupSection`,
`NotificationManager` (notification actions), `KadoApp` (launch seed,
day-start-hour change, dev-mode swap, day rollover),
`CompleteHabitIntent`, `LogHabitValueIntent`.

That funnel is the right place to detect "the day just became
complete": it sees every path, it runs *after* the save, and it is
independent of `@Query` timing.

### The existing "all done" predicate

`TodayView.checkMilestones(for:)` (`TodayView.swift:408-429`) already
re-snapshots `sections.due` after a save and records
`.allHabitsComplete` for the review prompt when every row is
`.complete`. Two limits:

- `allSatisfy` on an empty `due` is `true`, so a day with nothing
  scheduled qualifies.
- It only runs from Today's own actions. Detail, log sheets, Overview
  and the intents never reach it.

### Widgets

`KadoWidgets/` already ships three lock-screen widgets:

| Widget | Family | Shows |
|---|---|---|
| `LockRectangularWidget` | rectangular | one picked habit (name, streak, score bar) |
| `LockCircularWidget` | circular | one picked habit's ring |
| `LockInlineWidget` | inline | "3 of 5 done today" |

So the inline family already has the day's count; the circular one is
per-habit. The request is a **second circular widget** for the day.
The snapshot fields it needs (`completedToday`, `totalDueToday`) exist,
so no JSON shape change and no decoding-compatibility work.

Widget conventions to respect: `StaticConfiguration` +
`SnapshotTimelineProvider`, `.containerBackground(.clear, for: .widget)`
for accessory families, `.widgetAccentable()` on the content, string
catalog at `KadoWidgets/Resources/Localizable.xcstrings` (hand-authored,
FR required by `LocalizationCoverageTests`), previews from
`PreviewSnapshots`. New files under `KadoWidgets/` auto-enroll
(synchronized folder). The widget target is pinned to iOS 26.4.

### Animation and haptics

No `Canvas`, `TimelineView` or particle code exists anywhere. Motion
tokens are `KadoMotion.base/fast/slow` (calm ease-outs). Haptics are
SwiftUI `.sensoryFeedback(.success, …)` on the row controls — every
completion already buzzes once. `reduceMotion` is read in `TodayView`
and `TipJarView` with the `withAnimation(reduceMotion ? nil : …)`
pattern. The Tip Jar deliberately chose *no* confetti
(`docs/plans/2026-07/tip-jar/plan.md:25`); this feature is the user's
explicit call to add one for the day-complete moment only.

### Day boundary

`\.today` (env) and `rebuildAndWrite` both resolve the logical day via
`DayStartDefaults.boundary().startOfDay(for: .now)`. `KadoApp`
re-runs `WidgetReloader.reloadAll` at the day edge and when the
day-start hour changes, so the funnel is told about day changes too.

### Tests and tooling

- Unit patterns: `WidgetSnapshotBuilderTests` (in-memory container),
  `ReviewPromptServiceTests` (throwaway `UserDefaults` suite),
  `HabitRowStateTests`.
- UI: `KadoUITests` with `KadoUITestCase` (`launchApp`, `tapTab`,
  `todayRows`, `capture`). XcodeBuildMCP has no tap primitive, so an
  XCUITest is the only way to photograph the confetti.
- `Shared/AccessibilityID.swift` holds identifiers, leaves only.

## Proposed approach

### Key components

- **`DayProgress`** (KadoCore, `Models/`): `completed`, `total`,
  `isComplete` (`total > 0 && completed == total`), `fraction`.
  Exposed as `WidgetSnapshot.dayProgress` (computed, not stored) and
  used by the Today milestone check, so the "all done" rule has one
  home.
- **`DayCompletionTracker`** (KadoCore, `Services/`): pure value type.
  `record(_ progress: DayProgress, on day: Date) -> Bool` returns
  `true` exactly when the observation is *same day as the previous
  one, previous incomplete, this one complete*. First observation and
  any day change are baselines and never fire. `reset()` clears.
- **`DayCompletionCelebration`** (KadoCore): `@MainActor @Observable`
  process-scoped `shared` (same shape as `ActiveContainer`) wrapping
  the tracker; bumps `celebrationCount` when the tracker fires.
  `WidgetSnapshotBuilder.rebuildAndWrite` feeds it — the funnel above
  — so intents and every view path are covered without per-site work.
  `KadoApp` resets it before a dev-mode swap.
- **`DayCompletionCelebrationModifier`** (app, `Views/`): applied on
  `ContentView`, observes `celebrationCount`, overlays `ConfettiView`
  for ~3 s (non-interactive, ignores safe area) and posts a VoiceOver
  announcement. Under `reduceMotion`: no particles, a static "All done
  for today" caption that fades in and out.
- **`ConfettiView`** (app, `UIComponents/`): `TimelineView(.animation)`
  + `Canvas`; ~120 particles in closed-form physics (position from
  elapsed time, no integration state), habit-colour palette plus sage,
  seeded generator so previews are stable.
- **`LockDayProgressWidget`** (widget target): kind
  `dev.scastiel.kado.widget.lockDayProgress`, `.accessoryCircular`,
  `Gauge(value: fraction)` in `.accessoryCircularCapacity` style with
  "3/5" centred; "–" when nothing is due. Registered in the bundle
  after the existing lock widgets.

### Data model changes

None. No schema bump, no snapshot field added.

### UI changes

- Confetti overlay above the whole tab view (so Detail, Overview and
  intent-driven completions all celebrate).
- New lock-screen circular widget; existing widgets untouched.
- `TodayView.checkMilestones` uses `DayProgress.isComplete`, which
  also stops the empty-schedule false positive.

### Tests to write

- `@Test("0/0 is not complete")`, `@Test("3/3 is complete")`,
  `@Test("2/3 is not complete")`, `@Test("fraction is 0 for an empty
  day and clamps to 1")`, `@Test("WidgetSnapshot.dayProgress mirrors
  its counts")`.
- `@Test("First observation is a baseline and never fires")`,
  `@Test("Same day, incomplete then complete fires once")`,
  `@Test("Staying complete does not fire again")`,
  `@Test("Dipping and completing again fires again")`,
  `@Test("A new day is a baseline even when already complete")`,
  `@Test("After the new-day baseline, completing fires")`,
  `@Test("reset() forgets the previous observation")`,
  `@Test("An empty day never fires")`.
- UI (`KadoUITests`): create one habit from an empty state, tick it,
  assert the "All done for today" element appears; capture a
  screenshot for the visual check.
- `LocalizationCoverageTests` covers the new catalog keys.

## Alternatives considered

### Alternative A: trigger from `TodayView` with `onChange` on derived state

- Idea: compute `isComplete` from `@Query` rows and celebrate on the
  false→true edge.
- Why not: `@Query`'s first population can itself be a false→true edge
  (confetti on launch when today's habits are already done), the view
  is not on screen when a Detail or intent completes the day, and it
  duplicates a rule the snapshot builder already runs.

### Alternative B: trigger only from Today's own action methods

- Idea: extend `checkMilestones` with a celebration call.
- Why not: misses Detail, log sheets, Overview, notification actions
  and Siri. The funnel covers all of them for the same cost.

### Alternative C: once-per-day persisted gate

- Idea: remember the last celebrated day in `UserDefaults`.
- Why not (for now): un-ticking and re-ticking is user-initiated and
  replaying is what Streaks does; adding a sixth habit later and
  finishing it deserves a second celebration. Cheap to add later —
  see Open questions.

### Alternative D: SpriteKit emitter for the confetti

- Idea: `SKEmitterNode` in a `SpriteView`.
- Why not: a second framework for one three-second effect; `Canvas`
  with closed-form motion is ~100 lines, pure SwiftUI, and trivially
  previewable.

### Alternative E: change the existing circular widget

- Idea: make `LockCircularWidget` show the day when no habit is picked.
- Why not: users who configured it keep their per-habit ring; a new
  `kind` leaves them alone and the gallery lists both clearly.

## Risks and unknowns

- **Spurious celebrations on non-user changes.** Backup import, the
  notification-action path, or a CloudKit merge could complete the day
  without a tap. The tracker fires on those too. Acceptable — they are
  real completions — but dev-mode swaps and day-start changes are
  guarded (reset / new-day baseline).
- **Intent before launch seed.** If `CompleteHabitIntent` runs before
  `KadoApp`'s launch `.task` seeds the tracker, that tap is recorded
  as the baseline and not celebrated. A miss, never a false positive.
- **Widget staleness across the day boundary** is pre-existing
  (roadmap: "Rollover-aware widget refresh"); the new ring inherits
  it. Out of scope.
- **`.accented` / `.vibrant` rendering.** `Gauge` accessory styles are
  system-drawn and adapt; still verify on a device lock screen.
- **Canvas cost.** 120 particles at 60 fps for 3 s is negligible, but
  the overlay must be removed from the hierarchy when done, not left
  paused.

## Open questions

- [ ] Replay confetti when the day is un-ticked and re-ticked
      (current design: yes), or once per logical day per device?
- [ ] Add a distinct haptic to the celebration? The row already fires
      `.success`; a second one would double-buzz. Current design: none.
- [ ] Should the circular ring show a checkmark instead of "5/5" once
      complete? Current design: numbers always, ring closes.

## References

- [`Gauge` accessory styles](https://developer.apple.com/documentation/swiftui/gaugestyle/accessorycircularcapacity)
- [`TimelineView` + `Canvas`](https://developer.apple.com/documentation/swiftui/canvas)
- [Accessory widget families](https://developer.apple.com/documentation/widgetkit/widgetfamily/accessorycircular)
- [`AccessibilityNotification.Announcement`](https://developer.apple.com/documentation/swiftui/accessibilitynotification/announcement)
