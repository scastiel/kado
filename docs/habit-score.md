# Habit Score — Technical spec

Specification document for the **habit score** algorithm, Kadō's
signature feature (philosophically borrowed from Loop Habit Tracker,
reimplemented in Swift).

---

## Intent

The habit score expresses the **strength of a habit** over time, as
a number between 0.0 and 1.0.

Unlike a binary streak ("N consecutive uninterrupted days"), the
score is:
- **continuous**: a gradual value between 0 and 1
- **resilient**: a missed day doesn't reset to zero
- **cumulative**: a long history of completions resists accidents
  better than a young habit
- **forgetful**: very old performance weighs less than recent
  performance

This is philosophically aligned with the idea that a habit is a
**behavior reinforced over time**, not a fragile lifeline that must
"never be broken."

---

## Algorithm: Exponential Moving Average (EMA)

### Base formula

For each consecutive day since the habit's creation:

```
score[n] = (1 - α) × score[n-1] + α × value[n]
score[0] = 0
```

Where:
- `α` (alpha) is the **smoothing factor**, typically between 0.03 and
  0.07. Starting value recommended: **α = 0.05**.
- `value[n]` is the day's performance:
  - `1.0` if the habit was due and completed
  - `0.0` if the habit was due and missed
  - **skip the day** (no update) if the habit wasn't due (e.g.
    "Mondays only" habit on a Tuesday)

### Interpretation of α

- High `α` (0.1+): very reactive score, drops fast after a miss,
  rises fast after completion. Fast feedback but volatile.
- Low `α` (0.02): stable score, slow to move. Strength harder to
  gain and lose.
- `α = 0.05` gives a half-life of about 14 days: a missed day loses
  half its impact after ~2 weeks.

### Range and normalization

- Raw score is in `[0, 1]`.
- Shown to the user as a percentage (0% — 100%) or via a qualifier:
  *Weak* / *Building* / *Strong* / *Rock solid* by thresholds to be
  defined in UX.

---

## Special cases

### Non-daily frequency habits

For a habit like "3 times a week," calculation happens **per day of
the window**, not per week. Two possible approaches:

**Option A (recommended)**: evaluate score only on days where the
habit was "due" per the user's schedule.

- Schedule `.daysPerWeek(3)`: the system considers the 3 days where
  the user actually did (or should have done) the habit, spread over
  7 rolling days.
- Schedule `.specificDays([.mon, .wed, .fri])`: only Monday,
  Wednesday, Friday are evaluated. Other days are skipped.

**Option B (to test)**: keep a daily score but adapt `value[n]` to
weight — more complex, less intuitive for the user. **Don't
implement in MVP.**

### Value habits (counter / timer)

A "Drink 8 glasses of water" habit has a numeric target. We
calculate a **ratio**:

```
value[n] = min(1.0, achieved / target)
```

So 6 glasses out of 8 gives `value = 0.75`, which partially
contributes to the score. Exceeding target doesn't give more than
1.0 (no over-reward).

### Negative habits ("don't smoke")

Invert: `value[n] = 1.0` if the user avoided the behavior, `0.0` if
they had it. No algorithm change, just semantics in the input.

### Backfill (marking a habit retroactively)

The score must be **recalculated from the beginning** when a past
completion is modified. No naive incremental update, because
changing `value[k]` affects `score[k], score[k+1], ..., score[now]`.

Optimization: cache the calculated score in DB per day, invalidate
from the modified date toward now. To do when performance becomes a
problem, not before.

### Newly created habits

A habit with only 3 days of history will have a low score even at
100% completion, because the score starts at 0 and takes time to
climb. This is **intended**: a young habit isn't strong, no matter
the apparent streak.

Don't "cheat" by starting the score at anything other than 0.

### Archiving

An archived habit keeps its score at the moment of archiving. No
continuous calculation after archiving. If reactivated, calculation
resumes from the last active day.

---

## Envisioned Swift API

### Protocol

```swift
protocol HabitScoreCalculating {
    /// Calculates a habit's current score from its full history.
    func currentScore(
        for habit: Habit,
        completions: [Completion],
        asOf date: Date
    ) -> Double

    /// Calculates the score for each day in the range, useful for
    /// graphs.
    func scoreHistory(
        for habit: Habit,
        completions: [Completion],
        from startDate: Date,
        to endDate: Date
    ) -> [DailyScore]
}

struct DailyScore {
    let date: Date
    let score: Double  // 0.0 — 1.0
}
```

### Default implementation

```swift
struct DefaultHabitScoreCalculator: HabitScoreCalculating {
    let alpha: Double

    init(alpha: Double = 0.05) {
        self.alpha = alpha
    }

    func currentScore(
        for habit: Habit,
        completions: [Completion],
        asOf date: Date
    ) -> Double {
        let history = scoreHistory(
            for: habit,
            completions: completions,
            from: habit.createdAt,
            to: date
        )
        return history.last?.score ?? 0.0
    }

    func scoreHistory(
        for habit: Habit,
        completions: [Completion],
        from startDate: Date,
        to endDate: Date
    ) -> [DailyScore] {
        // 1. Enumerate days from startDate to endDate
        // 2. For each day:
        //    a. Check if the habit was due (FrequencyEvaluator)
        //    b. If not, skip (score unchanged)
        //    c. If yes, get the completion (or absence)
        //    d. Compute value[n] based on type (binary / counter)
        //    e. Apply EMA: score = (1-α) × prev + α × value
        // 3. Return the full series
    }
}
```

### Parameters

`alpha` is **fixed in the app** at 0.05 for MVP. Not exposed to the
user — it would create more confusion than added value. Could become
a power-user setting later if someone requests it.

---

## Critical tests

These tests must be written **before** implementation, and must
pass before the feature is considered complete.

### Invariants

```swift
@Test("Score is always between 0 and 1")
@Test("Score of empty history is 0")
@Test("Score with no completions ever stays low")
@Test("Score with 100% completion converges toward 1")
```

### Characteristic cases

```swift
@Test("Perfect 30-day streak gives score > 0.75")
@Test("Perfect 100-day streak gives score > 0.95")
@Test("Single missed day after perfect month barely dents score")
@Test("Ten missed days in a row significantly reduce score")
@Test("Score recovers when completions resume")
```

### Frequencies

```swift
@Test("Weekly habit only counts scheduled days")
@Test("Specific days schedule (mon/wed/fri) ignores other days")
@Test("Change of frequency mid-history doesn't break calculation")
```

### Habit types

```swift
@Test("Counter habit with 6/8 target gives partial credit")
@Test("Counter exceeding target caps at 1.0")
@Test("Timer habit uses ratio of achieved/target time")
@Test("Negative habit inverts completion semantic")
```

### Edge cases

```swift
@Test("Habit created today has score near 0 even if completed")
@Test("Archived habit score freezes at archive date")
@Test("Backfilling past completion recalculates from that date forward")
@Test("Timezone change doesn't break score calculation")
@Test("Date crossing DST boundary is handled correctly")
```

---

## Notable differences from Loop

Loop uses a similar algorithm but with a few particularities
documented in its Kotlin code:
- An **initial boost** to help new habits get going.
- Adjustments for low-frequency habits.

**For Kadō, start simple**: pure EMA with α = 0.05. If user testing
shows it's too punishing for young habits, we'll adjust — but never
by copying Loop (license issue), always by re-deriving the approach.

---

## Theoretical references

- Exponential Moving Average: standard concept in signal processing
  and finance, not patented.
- Paper cited by Loop's author in its docs: habit formation research
  suggests that a stable habit takes 66 days on average (Lally et
  al., 2010) — this informs the choice of α ≈ 0.05 (half-life of
  ~14 days gives stabilization toward 60-70 days).

---

## To revisit post-MVP

- Test α = 0.03 vs 0.05 vs 0.07 with real users.
- Consider a "weekly" score for low-frequency habits (e.g. once a
  month) where daily doesn't make sense.
- UX: show the score with a qualifier rather than a percentage to
  avoid number obsession.
