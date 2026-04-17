# Streak — Technical spec

Specification for the **streak** metric: Kadō's binary companion
to the habit score, answering "how many consecutive due days have
I completed."

---

## Intent

The streak expresses **unbroken consistency** on a habit's
schedule. Unlike the score, which is continuous and forgiving,
the streak is a sharp signal: it either grows or resets.

Two streak values are surfaced:

- **Current streak**: consecutive "due days" ending at today where
  the habit was completed.
- **Best streak**: the longest such run across the habit's full
  history.

Both live on the detail view. The streak is intentionally *not*
shown on Today — see [today-view research](plans/2026-04/today-view/research.md)
for the decision.

---

## Definitions

### "Due day"

A calendar day on which the habit's frequency considers it
scheduled:

- `.daily` → every day from `createdAt` to today.
- `.specificDays(Set<Weekday>)` → only the listed weekdays.
- `.everyNDays(N)` → every Nth day starting from `createdAt`.
- `.daysPerWeek(N)` → **every day is potentially due**; the unit
  of streak counting is the *week*, not the day (see below).

### "Completed" on a day

Any `Completion` record whose `date` falls within the day (local
calendar). Value is ignored for streak purposes — presence is
what counts. This matches the score calculator's treatment.

For `.negative` habits, "completed" inverts: the day counts as
*good* when there is **no** completion record. A negative habit's
streak is days-without-the-behavior.

### "Grace day" (today only)

Today doesn't break the current streak if it's a due day that
hasn't been completed **yet**. Rationale: a user opening the
detail view at 9am shouldn't see their streak break just because
the day hasn't finished. Past due-and-missed days break
normally.

---

## Current streak algorithm

```
streak = 0
day = today
loop:
  if day is before createdAt: stop
  if day is a due day for this habit:
    if completed(day) or (day == today and not yet completed):
      streak += 1
      day = day - 1
      continue
    else:
      stop
  else:
    day = day - 1
    continue
```

The grace-day clause only applies to today itself. Yesterday and
earlier must be completed (or inverted-negative) to count.

---

## Best streak algorithm

Walk the habit's full history from `createdAt` to today (or
`archivedAt`, whichever is earlier), tracking the current run:

```
best = 0
run = 0
for day in createdAt...endDate:
  if day is a due day:
    if completed(day) or day is today-grace:
      run += 1
      best = max(best, run)
    else:
      run = 0
```

By construction, `best ≥ current` always holds.

---

## Per-frequency semantics

### `.daily`
Every day since `createdAt` is a due day. Streak = consecutive
completed days ending today.

### `.specificDays(Set<Weekday>)`
Non-matching weekdays are *skipped* — they don't count toward or
against the streak. A Mon/Wed/Fri habit completed every Mon, Wed,
Fri for three weeks has a current streak of 9.

### `.everyNDays(N)`
Due days are `createdAt`, `createdAt + N`, `createdAt + 2N`, …
Non-due days are skipped. A miss on a due day breaks the streak.

### `.daysPerWeek(N)`
Counted in **weeks**, not days. A week "counts" if ≥ N
completions fall in it. Streak is consecutive qualifying weeks
ending in the current week. The current week is a grace week: it
doesn't break the streak until it ends, even if fewer than N
completions have landed so far.

Rationale: `.daysPerWeek(3)` means "3 of any 7 days" — asking the
user to pick *which* 3 defeats the flexibility. The week-granular
streak matches the semantics.

### Negative habits
Inverts "completed": a day counts when there is **no**
completion. The streak is days-without-the-tracked-behavior. All
frequency rules still apply — a `.specificDays` negative habit
only considers the listed weekdays.

---

## Archived habits

If `archivedAt` is set, the streak is computed as of that date,
not `.now`. This preserves the final streak value for history
without letting archived habits "bleed" through time.

---

## Edge cases

- **No completions ever**: current 0, best 0.
- **Habit created today, not yet completed**: current 0, best 0
  (today is a grace day but nothing to count yet).
- **Habit created today, completed today**: current 1, best 1.
- **Future completion records** (dates after today): ignored. The
  view-layer `Date.now` is the cutoff.
- **`.daysPerWeek` with N = 0**: invalid input, treat as
  non-applicable; streak returns 0.
- **`.everyNDays` with N = 0**: invalid, same treatment.

---

## Non-goals

- The streak doesn't carry partial-completion credit from counter
  or timer values. Any completion on a due day counts — the
  "quality" of the completion lives in the score, not the streak.
- No "freeze days" / skip-day allowances in v0.1. The grace day
  is the only leniency.
- No weekly/monthly streak views in v0.1 — the pair current/best
  is it.

---

## Implementation notes

Service shape matches `HabitScoreCalculating`:

```swift
protocol StreakCalculating: Sendable {
    func current(for habit: Habit, completions: [Completion], asOf date: Date) -> Int
    func best(for habit: Habit, completions: [Completion], asOf date: Date) -> Int
}
```

`asOf` defaults to `.now` at call sites but is injectable for
tests. The service accepts value-type `Habit` / `[Completion]`,
not `HabitRecord`, matching the score and frequency services.

Calendar is injected, defaulting to `.current`. Day comparisons
go through `Calendar.isDate(_:inSameDayAs:)` or
`calendar.startOfDay(for:)`, never raw seconds.

Tests pin to UTC Gregorian for determinism plus a Europe/Paris
run for DST coverage, matching the other services.

---

## References

- [habit-score.md](habit-score.md) — companion spec; complementary
  metric with different semantics.
- [plans/2026-04/habit-detail-view/research.md](plans/2026-04/habit-detail-view/research.md)
  — the detail view PR that introduces the service.
- Loop Habit Tracker streak logic — reimplemented loosely;
  specifically, the grace-day convention is not in Loop but is a
  deliberate deviation for iOS ergonomics.
