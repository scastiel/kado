# Research — Day starts at (custom day-rollover hour)

**Date**: 2026-08-10
**Status**: ready for plan
**Related**: [Issue #58](https://github.com/scastiel/kado/issues/58),
`docs/PRODUCT.md` (identity: sober voice, no configuration theatre),
`docs/ROADMAP.md` (v1.0 "Final features"),
prior art: `docs/plans/2026-04/habit-backdate/`

## Problem

A user who goes to bed at 1am still thinks of that hour as "today".
Kadō's Today view has already rolled over at midnight, so logging the
day that just ended costs, **per habit**: long-press → detail →
calendar → pick the day → mark done → back. The one-tap flow — the
thing that makes daily logging survive low motivation — disappears
exactly when motivation is lowest. The practical outcome is that the
habits don't get logged at all.

The fix is a **"Day starts at"** setting: an hour at which the app
rolls over to the next day. Default `00:00` (today's behaviour,
nobody is affected). A user reliably asleep by 4am sets `04:00`;
between midnight and 4am, Today still shows the previous day and one
tap still works.

Done, from the user's side: they change one setting once, and every
"what day is it?" answer in the app — Today, streaks, score, Overview,
widgets, Siri — agrees with their sense of the day.

## Current state of the codebase

### The good news: there is already exactly one seam

Every calculator in `KadoCore` is a **pure function of
`(habit, completions, calendar, reference date)`**. Wall-clock time
enters the domain in only two shapes:

1. **A reference date passed in** — `asOf:` / `on:` / `today:` —
   which is `.now` or `@Environment(\.today)` at every call site.
2. **The date written onto a `CompletionRecord`** at log time.

Nothing inside the calculators reads the clock. That means the offset
does not need to be threaded through `DefaultHabitScoreCalculator`,
`DefaultStreakCalculator`, `DefaultFrequencyEvaluator`,
`OverviewMatrix`, or `DailyValue` at all — they keep bucketing by
`calendar.startOfDay(for: completion.date)` and stay untouched.

### Where "now" actually enters (the full sweep list)

**Reference-date reads** (must become the *logical* now):

| Site | File |
|---|---|
| `\.today` env value + scene-phase rollover check | `Kado/App/KadoApp.swift:15,55,64` |
| Row state / streak / score `asOf: .now` | `Kado/Views/Today/TodayView.swift:153,159,163,318,326` |
| Due-today filter | `TodayView.swift:190,204,210` |
| Score / streak `asOf: .now`, today's counter value | `Kado/Views/HabitDetail/HabitDetailView.swift:155,333,342,350` |
| Matrix trailing edge + per-row metrics | `Kado/Views/Overview/OverviewView.swift:87,103,104` |
| `.future` cutoff, `isDateInToday` ring | `Kado/UIComponents/MonthlyCalendarView.swift:223,158` |
| "Today"/"Yesterday"/"N days ago" labels | `Kado/Views/HabitDetail/CompletionHistoryList.swift:97,98,99` |
| Prefill of today's value | `TimerLogSheet.swift:63`, `CounterLogSheet.swift:72` |
| Widget snapshot `asOf:` (built by the app) | `Packages/…/Widgets/WidgetSnapshotBuilder.swift:11,103` |

**Write paths** (must stamp the *logical* day):

| Site | File |
|---|---|
| `CompletionToggler.toggleToday` / `.setValueToday` | `Packages/…/Services/CompletionToggler.swift:25,60` |
| `CompletionLogger` increment / decrement / set / timer / note | `Kado/Services/CompletionLogger.swift` (all `on date: Date = .now`) |
| `CompleteHabitIntent.apply(now:)` | `Packages/…/Intents/CompleteHabitIntent.swift:49,84` |
| `LogHabitValueIntent.apply(now:)` | `Packages/…/Intents/LogHabitValueIntent.swift` |
| Notification "Complete" action | `Kado/Managers/NotificationManager.swift:156` |
| `HabitRecord.createdAt` default (`everyNDays` anchor) | `KadoSchemaV4.swift:22`, via `NewHabitFormModel.makeRecord()` |
| `archivedAt = .now` | `TodayView.swift:334`, `HabitDetailView.swift:113` |

**Deliberately left on wall-clock time**: `DefaultNotificationScheduler`
(`:51`) — see the notifications decision below.

### Surfaces that need nothing

- **Widgets** render a pre-built `WidgetSnapshot` from the App Group
  JSON. The offset is baked in by the app at build time; the widget
  process never asks what day it is. (`SnapshotTimelineProvider` only
  re-reads the file hourly.)
- **`GetHabitStatsIntent`** reads the same snapshot — inherits the
  offset for free.
- **Apple Watch and Live Activities do not exist yet** (v0.3, not
  started). If the seam lands as one injected value, they inherit it
  when they ship rather than needing a retrofit.

### Settings infrastructure that exists

- No general preferences section yet — `SettingsView` is Sync /
  Notifications / Backup / Support / Tip Jar / Dev mode.
- `DevModeDefaults` is the established pattern for an app-level flag:
  a `nonisolated enum` in `KadoCore` holding the key plus a
  `UserDefaults(suiteName: SharedStore.appGroupID)` accessor, read via
  `@AppStorage(key, store:)`.

## Proposed approach

**One value type, `DayBoundary`, injected through the Environment,
applied at the two seams above — and normalisation on *write*, never
on read.**

```swift
nonisolated public struct DayBoundary: Equatable, Sendable {
    public let calendar: Calendar
    public let startHour: Int          // 0...6, default 0

    /// Midnight of the logical day containing `date`.
    public func startOfDay(for date: Date) -> Date

    /// True when both instants fall in the same logical day.
    public func isDate(_ a: Date, inSameDayAs b: Date) -> Bool

    /// The instant to stamp on a record logged at `date` — same
    /// clock time, shifted onto the logical day's calendar date.
    public func loggingInstant(for date: Date) -> Date

    /// When the next rollover happens (drives the in-app tick and
    /// the "still yesterday" hint).
    public func nextRollover(after date: Date) -> Date
}
```

`startOfDay` is computed calendar-first, never by subtracting seconds:

```swift
let midnight = calendar.startOfDay(for: date)
let rollover = calendar.date(byAdding: .hour, value: startHour, to: midnight)!
return date < rollover
    ? calendar.date(byAdding: .day, value: -1, to: midnight)!
    : midnight
```

With `startHour == 0` this is byte-for-byte `calendar.startOfDay`, so
the default path is provably unchanged.

### Why normalise on write, not on read

This is the load-bearing decision, and it is what satisfies the
issue's "must not retroactively re-bucket stored completions."

- **On read** (keep storing `.now`, bucket by logical day everywhere)
  means a completion logged at 01:00 under `00:00` reads as *that*
  day, and silently becomes the *previous* day the moment the user
  sets `04:00`. History rewrites itself. Rejected.
- **On write** (stamp the logical day at log time) means a stored
  record carries its day permanently. Changing the setting changes
  nothing that already happened — no migration, no recompute, no
  schema change. Every read path keeps its plain
  `startOfDay(completion.date)` and is not touched.

`loggingInstant` preserves the wall-clock *time* and shifts only the
*calendar date*: logging at 02:15 on Aug 11 with a 4am rollover stores
`Aug 10 02:15`. Nothing in the app displays a completion's time
(`CompletionHistoryList` formats `"EEE MMM d"`), so no UI changes; the
single-record-per-logical-day invariant holds because dedup runs
through the same `isDate(_:inSameDayAs:)`.

### Key components

- **`DayBoundary`** (`Packages/KadoCore/Sources/KadoCore/Services/`):
  pure struct, injected `Calendar`, same shape as `CompletionToggler`.
  No protocol — there is nothing to mock; a different `startHour` *is*
  the test double.
- **`DayStartDefaults`** (`KadoCore`): key + App Group suite, mirroring
  `DevModeDefaults`.
- **`\.dayBoundary` Environment entry** alongside the existing
  `\.calendar` and `\.today`. `KadoApp` builds it from `@AppStorage`
  and re-derives `\.today` from it.
- **`DayStartSection`** in Settings: an hour `Picker` + explanatory
  footer.
- **Pre-rollover hint on Today** — see open questions.

### Data model changes

**None.** No `@Model` change, no `KadoSchemaV5`, no migration, and
critically **no CloudKit Production schema deploy** (the manual step
that cost two App Store reviews in issue #52). The setting lives in
`UserDefaults`; completions keep their existing shape.

### UI changes

- **Settings** — new section: `Picker` "Day starts at" over
  midnight…6 AM, locale-formatted (`.formatted(.dateTime.hour())`),
  with a footer covering both the behaviour and the
  "changing this doesn't move anything you've already logged"
  reassurance.
- **Today** — a hint while the wall clock is past midnight but before
  the rollover (see open question 1).
- **Habit detail calendar** — the "today" ring follows the logical day.

### Tests to write

Business logic, so tests land before implementation.

`DayBoundaryTests`:
- `@Test("startHour 0 matches Calendar.startOfDay exactly")`
- `@Test("02:00 with a 4am boundary resolves to the previous day")`
- `@Test("04:00 exactly resolves to the new day")` (boundary inclusive)
- `@Test("03:59:59 with a 4am boundary is still the previous day")`
- `@Test("Spring-forward day in Europe/Paris keeps a 4am boundary")`
- `@Test("Fall-back day maps both 02:00 instants to the same logical day")`
- `@Test("loggingInstant preserves clock time and moves the date back")`
- `@Test("Changing startHour never changes startOfDay of a stored date")`
  — the anti-re-bucketing guarantee, asserted directly.

Integration:
- `@Test("Toggling at 23:00 then 01:00 hits one record")` — the
  single-record-per-logical-day invariant across a wall-clock midnight.
- `@Test("CompleteHabitIntent before the rollover completes yesterday")`
- `@Test("Widget snapshot's trailing matrix day is the logical day")`
- `@Test("Reminders still schedule on wall-clock days under a 4am boundary")`
- Existing suites (`HabitScoreCalculatorTests`, `StreakCalculatorTests`,
  `OverviewMatrixTests`, `FrequencyEvaluatorTests`) must pass unchanged
  — they are the proof the calculators weren't disturbed.

## Alternatives considered

### Alternative A: day switcher on the Today view

- Idea: a control that shifts the whole Today list back one day.
- Why not: still an extra tap every night, and it fixes only the
  *list*. Streak, score, Overview and widgets keep their midnight
  boundary, so the surfaces disagree with each other — the exact
  failure the issue calls out. Cheap and complementary later; not a
  substitute.

### Alternative B: post-midnight grace banner

- Idea: after midnight, offer "still finishing yesterday?".
- Why not: it's a prompt, not a rule — it interrupts, it has to be
  answered every night, and it says nothing about day boundaries
  anywhere else in the app. Against Kadō's "sober, no emotional
  pressure" voice.

### Alternative C: infer intent from logging time

- Idea: notice the user logs at 1am and silently attribute to
  yesterday.
- Why not: behavioural inference the user never asked for, invisible
  and unpredictable, and wrong for anyone genuinely up early.

### Alternative D: persist a `dayKey` column on `CompletionRecord`

- Idea: store both the true timestamp and the logical day it belongs
  to; read by `dayKey`.
- Why not: the most principled option, but it requires a `KadoSchemaV5`
  bump, the full 7-step schema checklist, a **manual CloudKit
  Production deploy**, and rewriting every read site. It buys only the
  wall-clock timestamp of a log — which no surface displays. Revisit
  if a "time of day you log" feature ever appears.

### Alternative E: shift the `Calendar`'s time zone

- Idea: hand every service a `Calendar` whose `timeZone` is offset by
  −N hours.
- Why not: breaks DST, breaks every user-visible date formatter, and
  poisons `Weekday` derivation. Discarded on sight.

## Risks and unknowns

- **Sweep completeness.** One missed `.now` and two surfaces disagree
  — the failure mode the issue explicitly wants avoided. Mitigated by
  the exhaustive table above and by the fact that every calculator
  already takes its reference date as a parameter.
- **`isDateInToday` / `isDateInYesterday`** are wall-clock helpers used
  in `CompletionHistoryList` and `MonthlyCalendarView`; they have no
  `DayBoundary` equivalent and must be replaced by hand.
- **Transition moment.** If the user changes the setting *while inside*
  the affected window, Today flips back a day immediately. Anything
  they already logged that night stays on the day it was written. This
  is correct, but surprising without the hint — argues for open
  question 1 being a "yes".
- **Setting is device-local.** iPhone and iPad each need it set. Two
  devices disagreeing causes no corruption (a completion lands on one
  day and both devices read it there), just a mild surprise. Syncing
  it would need `NSUbiquitousKeyValueStore` — deferred.
- **Widget staleness across a rollover** is pre-existing: the snapshot
  is only rebuilt on mutation or launch, so a widget can show
  yesterday's "today" until the app is opened. The offset makes this
  no worse, but a rollover-aware refresh would be a real improvement.
  Out of scope; worth its own issue.

## Open questions

All resolved 2026-08-10; carried into `plan.md` as decisions.

- [x] **1.** Today shows a quiet inline caption during the window —
      "Still Sunday · rolls over at 4 AM" — not a section-header
      rename and not silence.
- [x] **2.** Picker range is midnight…6 AM.
- [x] **3.** Reminders stay on wall-clock time. The notification's
      Complete action still writes to the logical day.
- [x] **4.** `createdAt` / `archivedAt` stamp the logical day, so a
      habit created at 2am is due that same night and `everyNDays`
      anchors where the user expects.
- [x] **5.** The app ticks Today over at the rollover while
      foregrounded. Not optional once the caption exists — otherwise
      "rolls over at 4 AM" is still on screen at 4:01.

## References

- Issue #58 — original request and alternatives
- `docs/plans/2026-04/habit-backdate/` — closest prior art; same
  "one derived day-semantics change, many call sites" shape
- `CLAUDE.md` § Dates and calendars — day arithmetic goes through
  `Calendar`, services take an injected one, tests pin to UTC and to
  `Europe/Paris` for DST
- `CLAUDE.md` § SwiftData — schema-bump checklist (the cost avoided by
  normalising on write)
