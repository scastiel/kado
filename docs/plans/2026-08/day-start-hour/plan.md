# Plan — Day starts at (custom day-rollover hour)

**Date**: 2026-08-10
**Status**: done — all tasks complete
**Research**: [research.md](./research.md)
**Issue**: [#58](https://github.com/scastiel/kado/issues/58)

## Summary

Add a **"Day starts at"** setting (midnight…6 AM, default midnight)
that moves the hour at which Kadō rolls over to the next day, so
someone logging at 1am keeps the one-tap Today flow instead of
back-filling each habit through the calendar.

The whole feature is one value type — `DayBoundary` — injected through
the SwiftUI Environment and applied at the only two places wall-clock
time enters the domain: the **reference date** passed to the
calculators, and the **date stamped** on a new completion. Because the
day is fixed at write time, changing the setting never re-buckets
anything already logged. No `@Model` change, no `KadoSchemaV5`, no
CloudKit Production deploy.

## Decisions locked in

- **Normalise on write, never on read.** A completion carries its
  logical day permanently; the setting only answers "which day is it
  *now*". This is what makes "must not retroactively re-bucket stored
  completions" true by construction rather than by care.
- **No schema change.** The setting lives in `UserDefaults` (App Group
  suite, mirroring `DevModeDefaults`). Explicitly avoids the manual
  CloudKit Production schema deploy that cost two App Store reviews.
- **Calculators are not touched.** `DefaultHabitScoreCalculator`,
  `DefaultStreakCalculator`, `DefaultFrequencyEvaluator`,
  `OverviewMatrix` and `DailyValue` keep bucketing by
  `calendar.startOfDay(for: completion.date)`. Their existing test
  suites passing unchanged is the proof.
- **`DayBoundary` is a plain struct, not a protocol.** Nothing to
  mock — a different `startHour` *is* the test double. Follows the
  `CompletionToggler` pattern CLAUDE.md prescribes.
- **Picker range is midnight…6 AM**, hours only, no minutes.
- **Reminders stay on wall-clock time.** 9 PM means 9 PM. The
  notification's *Complete* action writes to the logical day, so the
  tick lands on the day Today is showing.
- **`createdAt` / `archivedAt` stamp the logical day**, so a habit
  created at 2am is due that same night and the `everyNDays` cycle
  anchors where the user expects.
- **Today shows a quiet inline caption** during the pre-rollover
  window: "Still Sunday · rolls over at 4 AM".
- **Today ticks over at the rollover while foregrounded** — required,
  not optional, once the caption exists.
- **The setting is device-local.** iCloud-syncing it is deferred.

## Task list

Tasks 1–2 are TDD (business logic). Tasks 3–10 each leave the app
compiling and green.

### ✅ Task 1: `DayBoundary` tests

**Goal**: Pin the day-resolution semantics before any implementation
exists.

**Changes**:
- `KadoTests/DayBoundaryTests.swift` (new)
- `KadoTests/Helpers/TestCalendar.swift` — add a `Europe/Paris`
  calendar and DST-boundary anchors alongside the existing `utc`

**Tests**:
- `startHour 0` is byte-identical to `Calendar.startOfDay` across a
  full day of instants
- 02:00 with a 4am boundary → previous day
- 04:00 exactly → new day (boundary inclusive)
- 03:59:59 → previous day
- 23:59 → same day
- spring-forward day in `Europe/Paris` keeps the 4am boundary
- fall-back day maps both 02:00 instants to one logical day
- `loggingInstant` preserves clock time, moves the calendar date back
- `loggingInstant` is the identity when `startHour == 0`
- **changing `startHour` never changes `startOfDay(storedDate)`** —
  the anti-re-bucketing guarantee, asserted directly
- `nextRollover(after:)` lands on the right instant either side of the
  boundary

**Verification**: `test_sim` — all new tests fail (red).

**Commit**: `test(day-boundary): specify logical-day resolution`

---

### ✅ Task 2: `DayBoundary` implementation

**Goal**: Make Task 1 green.

**Changes**:
- `Packages/KadoCore/Sources/KadoCore/Services/DayBoundary.swift` (new)

`nonisolated struct DayBoundary: Equatable, Sendable` holding
`calendar: Calendar` and `startHour: Int` (clamped `0...6`), exposing
`startOfDay(for:)`, `isDate(_:inSameDayAs:)`, `loggingInstant(for:)`,
`nextRollover(after:)`. All arithmetic via `Calendar` — no
`addingTimeInterval`, per CLAUDE.md.

**Verification**: `test_sim` green; existing suites untouched.

**Commit**: `feat(day-boundary): add logical-day resolution service`

---

### ✅ Task 3: Persistence + Environment plumbing

**Goal**: Make the setting readable everywhere, with nothing yet
consuming it.

**Changes**:
- `Packages/KadoCore/Sources/KadoCore/DayStartDefaults.swift` (new) —
  key `kado.dayStartHour`, App Group suite, `allowedHours = 0...6`,
  mirroring `DevModeDefaults`
- `Kado/App/EnvironmentValues+Services.swift` — `@Entry var dayBoundary: DayBoundary`
- `Kado/App/KadoApp.swift` — `@AppStorage` the hour, build the
  boundary, inject it

**Tests**: `DayStartDefaultsTests` — default is 0 when unset, values
outside `0...6` clamp, isolated suite per test.

**Verification**: `build_sim` clean; behaviour identical (nothing
reads it yet).

**Commit**: `feat(settings): persist and inject the day-start hour`

---

### ✅ Task 4: Logical "today" through the app

**Goal**: Every reference-date read asks `DayBoundary`, not the clock.
This is the task that makes Today, streaks, score and Overview agree.

**Changes**:
- `KadoApp.swift` — derive `\.today` from
  `dayBoundary.startOfDay(for: .now)`; the `scenePhase → .active`
  rollover check compares logical days
- `TodayView.swift` — `asOf: .now` → `asOf: today` (5 sites); the
  due-today filter and the completed-today check use
  `dayBoundary.isDate(_:inSameDayAs:)`
- `HabitDetailView.swift` — `asOf:`, `todayCounterValue`
- `OverviewView.swift` — matrix trailing edge and per-row metrics
- `MonthlyCalendarView.swift` — `.future` cutoff, "today" ring
  (replaces `isDateInToday`)
- `CompletionHistoryList.swift` — Today / Yesterday / N-days-ago
  (replaces `isDateInToday` / `isDateInYesterday`)
- `TimerLogSheet.swift`, `CounterLogSheet.swift` — today's prefill

**Tests**: `HabitRowState.resolve` under a 4am boundary at 02:00
resolves against the previous day.

**Verification**: `test_sim`; `screenshot` on iPhone 17 Pro with the
sim clock at 02:00 and the boundary at 4am — Today shows the previous
day's list.

**Commit**: `feat(today): resolve the current day through DayBoundary`

---

### ✅ Task 5: Logical day on write

**Goal**: A completion logged at 2am lands on the day Today is
showing.

**Changes**:
- `CompletionToggler.swift` / `CompletionLogger.swift` — callers pass
  `dayBoundary.loggingInstant(for: .now)` instead of `.now`
  (defaults stay `.now`, so past-day editing from the calendar is
  unaffected — it already passes an explicit day)
- `TodayView.swift`, `HabitDetailView.swift`, `TimerLogSheet.swift`,
  `CounterLogSheet.swift` — pass the logging instant
- `NewHabitFormModel.makeRecord()` — stamp `createdAt`
- `TodayView.archive` / `HabitDetailView.archive` — stamp `archivedAt`

**Tests**:
- toggling at 23:00 then again at 01:00 (4am boundary) mutates **one**
  record — the single-record-per-logical-day invariant across a
  wall-clock midnight
- a completion written at 02:00 buckets to the previous day under
  `startOfDay`
- with `startHour == 0` every write is byte-identical to today's

**Verification**: `test_sim`.

**Commit**: `feat(logging): stamp completions with the logical day`

---

### ✅ Task 6: App Intents, notification actions, widget snapshot

**Goal**: Siri, the notification banner and the widgets agree with
Today.

**Changes**:
- `CompleteHabitIntent.perform()` / `LogHabitValueIntent.perform()` —
  pass the logical now (the `apply(now:)` cores already take it as a
  parameter, so no signature churn)
- `NotificationManager.handleComplete` — same
- `WidgetSnapshotBuilder.build(asOf:)` — the app passes the logical
  now; `rebuildAndWrite` reads the stored hour

*Not changed*: `DefaultNotificationScheduler` stays on wall-clock
time. `GetHabitStatsIntent` and the widget process read the pre-built
snapshot and inherit the offset for free.

**Tests**:
- `CompleteHabitIntent.apply` with a pre-rollover `now` completes the
  previous day
- widget snapshot's trailing matrix day is the logical day
- **`DefaultNotificationScheduler` still schedules on wall-clock days**
  under a 4am boundary — the explicit "we decided this" regression

**Verification**: `test_sim`.

**Commit**: `feat(intents): honor the day boundary in intents and widgets`

---

### ✅ Task 7: Settings section

**Goal**: The user can actually set it.

**Changes**:
- `Kado/Views/Settings/DayStartSection.swift` (new) — `Picker` over
  midnight…6 AM, locale-formatted via `.formatted(.dateTime.hour())`,
  footer covering the behaviour *and* "changing this doesn't move
  anything you've already logged"
- `SettingsView.swift` — insert above `NotificationsSection`
- Previews: default, 4 AM selected, Dark, Dynamic Type XXXL

**Verification**: `build_sim`; `screenshot` light + dark; VoiceOver
reads the picker and footer.

**Commit**: `feat(settings): add the Day starts at picker`

---

### ✅ Task 8: Pre-rollover caption on Today

**Goal**: The state is never surprising.

**Changes**:
- `Kado/Views/Today/TodayDayCaption.swift` (new) — renders only when
  `startHour > 0` and the wall-clock day differs from the logical day
- `TodayView.swift` — caption above the first section

Copy: "Still {weekday} · rolls over at {hour}". Sober, factual, no
emotional pressure — no "don't break your streak!" framing.

**Verification**: `screenshot` with the sim clock at 02:00; caption
absent at 10:00 and absent entirely at `startHour == 0`.

**Commit**: `feat(today): show the still-yesterday caption before rollover`

---

### ✅ Task 9: Foreground rollover tick

**Goal**: At 4:00:00 with the app open, Today flips and the caption
disappears without a relaunch.

**Changes**:
- `KadoApp.swift` — a `Task` sleeping until
  `dayBoundary.nextRollover(after: .now)` that bumps `\.today` and
  reschedules; cancelled and rebuilt when the hour setting changes

**Verification**: sim clock set 60s before the boundary, app
foregrounded, observe the flip.

**Commit**: `feat(today): roll the day over in place at the boundary`

---

### ✅ Task 10: Localization + docs

**Goal**: Ship-ready.

**Changes**:
- `Kado/Resources/Localizable.xcstrings` — hand-author EN + FR for the
  Settings row, footer, hour labels and the Today caption
  (`.xcstrings` is source, not a build artifact, under `xcodebuild`).
  FR conventions: `tu`, `habitude` feminine, "série" for streak — you
  are final arbiter on the wording.
- `docs/ROADMAP.md` — note the setting under v1.0 final features

**Verification**: `LocalizationCoverageTests` passes.

**Commit**: `feat(i18n): localize the day-start setting`

## Integration checkpoints

| Boundary | Risk | Handling |
|---|---|---|
| **SwiftData** | none | no `@Model` change, no migration, no CloudKit deploy |
| **CloudKit** | two devices with different hours | benign — a completion lands on one day and both devices read it there. Documented, not defended against. |
| **App Group** | widget reads a stale snapshot across a rollover | pre-existing (true at midnight today); the offset doesn't worsen it. Separate issue. |
| **UserNotifications** | reminder scheduling accidentally shifts | Task 6 adds an explicit regression test that it does *not* |
| **App Intents** | a second container | untouched — both intents keep using `ActiveContainer.shared` |

## Notes during build

Kept for the compound stage.

- **Task 2 — clamping split.** The plan had `DayBoundary` clamp to
  `0...6`. Implemented as `0...23` on `DayBoundary` (any hour is
  mathematically valid) with `0...6` owned by `DayStartDefaults`, which
  is what the picker offers. Widening the range later is now a one-line
  change with no effect on day resolution.

- **Task 2 — `bySettingHour`, not hour addition.** Adding `startHour`
  hours to midnight overshoots by the skipped hour on a spring-forward
  day. `date(bySettingHour:matchingPolicy:.nextTime)` finds the wall
  clock reading instead, and falls forward when that reading doesn't
  exist at all (02:00 on 2026-03-29 in Paris). Both cases are pinned by
  tests.

- **Task 4 — smaller than planned, for a good reason.** Stored
  completion dates keep plain `calendar.startOfDay` bucketing, and
  `\.today` is already a plain calendar midnight, so most sites needed
  only `.now` → `today` rather than a `DayBoundary` call. The rule that
  fell out: **`dayBoundary` answers "what day is it now"; `calendar`
  buckets an already-stored date.** Applying the boundary to a stored
  date is the read-normalisation design we rejected.

- **Task 6 — `generatedAt` was quietly becoming midnight.** The builder
  set `generatedAt: reference`, and `reference` is now the logical day's
  midnight. Nothing reads the field today, so it was set to the true
  `.now` rather than left as a trap for the first consumer.

- **Task 8 — the screenshot caught two bugs the tests could not.**
  `setLocalizedDateFormatFromTemplate("EEEE")` negotiated down to the
  abbreviated weekday ("Still Sun"), fixed by using
  `Weekday.localizedFull` per the project convention. And formatting
  `nextRollover` rendered the instant in the *device's* time zone, so a
  UTC boundary at 04:00 displayed as "00:00". Both now have regressions
  in `DayStartPresentationTests`, and the hour label is shared with the
  Settings picker via `DayStartHourLabel` so the two can't disagree.

- **The post-sweep grep found three more.** The plan's mitigation earned
  its place. `DayColumnHeader` (Overview's highlighted column) and
  `WeeklyGridLargeWidget` both used `isDateInToday`, which matches *no*
  column between midnight and the rollover. The widget now derives
  "today" from `snapshot.matrixDays.last` rather than reading the
  setting — self-consistent with the snapshot it renders. `DevModeSeed`
  was also seeding against wall-clock days.

- **Not verified on device.** The FR rendering of the two Settings
  footers and the Today caption. XcodeBuildMCP has no tap primitive on
  this machine (no `idb` installed), so Settings can't be reached in the
  simulator; EN was pixel-checked through a temporary render harness,
  and repeated attempts to launch under an FR locale failed to
  foreground. FR strings are covered by `LocalizationCoverageTests`; the
  wording needs a native-speaker pass regardless.

## Verification

- `test_sim`: **412 passing**, up from a 362 baseline. No pre-existing
  test was modified.
- `build_sim`: clean for `Kado` and `KadoWidgetsExtension`, and for
  iPad Air 13-inch (M4) — no new warnings.
- Pixel-checked on iPhone 17 Pro: the Settings section in its default
  state, and the 4 AM state (picker value, non-default footer, Today
  caption) through a temporary render harness.


## Risks and mitigation

- **A missed `.now`.** Two surfaces silently disagree. The research
  doc's call-site table is exhaustive as of today's `HEAD`; after Task
  6, re-grep `startOfDay`, `inSameDayAs`, `isDateInToday` and `asOf:`
  and confirm every remaining hit is either a stored-date bucketing
  (correct) or a test.
- **Regression for the 99% on midnight.** Every task carries a
  `startHour == 0` assertion, and the untouched calculator suites are
  the backstop.
- **Caption copy feels chatty.** It's one secondary-styled line, only
  in the window, only when the setting is non-default. If it reads
  wrong on device, cut it — Task 8 is independently revertible.
- **Sim clock testing is fiddly.** `simctl` time manipulation is
  unreliable; the real coverage is the unit tests, which inject the
  reference date directly. Screenshots are for layout, not logic.

## Open questions

None blocking. Deferred by choice:

- [ ] iCloud-sync the setting via `NSUbiquitousKeyValueStore` so
      iPhone and iPad agree without setting it twice.
- [ ] Rollover-aware widget refresh (`.after(nextRollover)` instead of
      hourly) — fixes a pre-existing staleness bug; own issue.

## Out of scope

- Minute-level rollover (03:30). Hours only.
- A Today day-switcher. Complementary, not a substitute — see
  research Alternative A.
- Any change to the score, streak or frequency algorithms.
- Apple Watch and Live Activities: not built yet. They inherit the
  seam when they ship because it's one injected value.
- Re-bucketing or migrating existing completions. Explicitly never.
