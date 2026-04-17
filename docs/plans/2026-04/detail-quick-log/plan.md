---
# Plan — Detail view quick-log + history

**Date**: 2026-04-17
**Status**: ready to build
**Research**: [research.md](./research.md)

## Summary

Detail view gains counter `+/−` controls, a timer "Log session"
sheet, and a scrollable completion history list with
swipe-to-delete. `HabitRowView` updates to show today's value for
counter/timer rows. New `CompletionLogger` service handles the
writes. No data-model changes.

## Decisions locked in

- **`CompletionLogger` mirrors `CompletionToggler`**: concrete
  `@MainActor struct` with injected `Calendar`, no protocol, no
  env injection. Instantiated inline at call sites.
- **Single record per day invariant** holds for counter and
  timer (same as binary). Increment adds to the existing record's
  value; timer replaces.
- **Counter decrement to zero deletes** the record. Keeps "no
  record" ↔ "not completed" bijection.
- **History list**: `LazyVStack` over all completions, sorted
  descending, swipe-to-delete without confirmation.
- **Counter target-reached haptic**: `.success` on the below→at
  transition only.
- **Timer logging**: modal sheet with minute stepper, default
  prefilled from habit's target minutes.
- **No data-model change.** `CompletionRecord.value: Double`
  accommodates both.

## Task list

### Task 1: Red tests for `CompletionLogger`

**Goal**: TDD the new counter/timer/delete operations.

**Changes**:
- `KadoTests/CompletionLoggerTests.swift` (new).

**Cases**:
- `@Test("incrementCounter creates a completion with value 1 when none exists today")`
- `@Test("incrementCounter adds to existing today's value")`
- `@Test("decrementCounter reduces value by 1")`
- `@Test("decrementCounter below 1 deletes the completion")`
- `@Test("decrementCounter when no completion is a no-op")`
- `@Test("logTimerSession creates a completion with value = seconds")`
- `@Test("logTimerSession replaces today's existing completion")`
- `@Test("delete removes the given completion without touching others")`
- `@Test("Day-boundary: incrementing on two consecutive days creates two records")`

**Verification**: `test_sim` fails (symbol missing).

**Commit**: `test(completion-logger): red-state tests for counter/timer logging`

---

### Task 2: Implement `CompletionLogger`

**Goal**: Struct with `Calendar` injection, four methods.

**Changes**:
- `Kado/Services/CompletionLogger.swift` (new):
  ```swift
  @MainActor
  struct CompletionLogger {
      let calendar: Calendar
      init(calendar: Calendar = .current)

      func incrementCounter(for habit: HabitRecord, on date: Date = .now, by delta: Double = 1, in context: ModelContext)
      func decrementCounter(for habit: HabitRecord, on date: Date = .now, in context: ModelContext)
      func logTimerSession(for habit: HabitRecord, seconds: TimeInterval, on date: Date = .now, in context: ModelContext)
      func delete(_ completion: CompletionRecord, in context: ModelContext)
  }
  ```

**Verification**: `test_sim` green.

**Commit**: `feat(completion-logger): support counter/timer logging operations`

---

### Task 3: Update `HabitRowView` to show today's value

**Goal**: Replace `–/8` placeholder with actual today value when
present.

**Changes**:
- `Kado/UIComponents/HabitRowView.swift`:
  - Add `todayValue: Double?` parameter.
  - Counter trailing label: `"\(Int(todayValue ?? 0))/\(Int(target))"`
    when `todayValue != nil`, else `"–/\(Int(target))"`.
  - Timer trailing label: "HH:MM / target" formatted when present.
- `Kado/Views/Today/TodayView.swift`: compute `todayValue` from
  today's completion and pass through.
- Previews: add "counter with today's progress" and "timer with
  today's progress" permutations.

**Verification**: `build_sim` clean; previews render.

**Commit**: `feat(today-row): show today's value for counter and timer habits`

---

### Task 4: Build `CounterQuickLogView`

**Goal**: `−` / value / `+` trio with target-reached haptic.

**Changes**:
- `Kado/UIComponents/CounterQuickLogView.swift` (new):
  - Inputs: `habit: HabitRecord`, `todayValue: Double`,
    `onIncrement`, `onDecrement`.
  - Layout: large Label("\(value)/\(target)") between two circular
    buttons. `−` disabled when `todayValue == 0`.
  - `.sensoryFeedback(.success, trigger: targetReached)` where
    `targetReached` flips to true when `todayValue >= target`.
- Previews: under target / at target / over target / at zero.

**Verification**: `build_sim` clean; previews render.

**Commit**: `feat(counter-quick-log): add counter +/- control with target haptic`

---

### Task 5: Build `TimerLogSheet`

**Goal**: Modal sheet for logging a timer session's minutes.

**Changes**:
- `Kado/Views/HabitDetail/TimerLogSheet.swift` (new):
  - `@Bindable` habit + `@State var minutes: Int` prefilled from
    target.
  - `Form` with a `Stepper("Minutes: \(minutes)", value: $minutes, in: 1...480)`.
  - Toolbar: Cancel / Save (Save calls `CompletionLogger.logTimerSession`).
  - `@Environment(\.dismiss)` + `@Environment(\.modelContext)`.

**Verification**: `build_sim` clean.

**Commit**: `feat(timer-log-sheet): add minute-based timer session logging`

---

### Task 6: Build `CompletionHistoryList`

**Goal**: Scrollable list of completions below the calendar.

**Changes**:
- `Kado/Views/HabitDetail/CompletionHistoryList.swift` (new):
  - Input: `habit: HabitRecord`.
  - Computes sorted-desc completions.
  - `LazyVStack` — each row shows relative date
    (`Today`/`Yesterday`/`N days ago`/formatted), formatted value
    per habit type, swipe-to-delete.
  - Empty state row when history is empty.

**Verification**: `build_sim` clean.

**Commit**: `feat(completion-history): add scrollable completion list for detail view`

---

### Task 7: Wire quick-log + history into `HabitDetailView`

**Goal**: Compose the new components on the detail screen.

**Changes**:
- `HabitDetailView.swift`:
  - Add `CounterQuickLogView` conditionally when
    `habit.type == .counter`.
  - Add "Log a session" button conditionally when
    `habit.type == .timer`, opening `TimerLogSheet` as a sheet.
  - Add `CompletionHistoryList` section at the bottom of the
    scroll.

**Verification**:
- `build_sim` clean; `test_sim` green.
- Manual sim run: create a counter habit → detail → `+` thrice
  → row reflects `3/target`. Create a timer habit → detail →
  "Log session" → saves. Swipe-delete history row → value
  updates.
- `screenshot` the populated detail view.

**Commit**: `feat(habit-detail): wire counter, timer, and history sections`

---

### Task 8: (Optional) polish

Reserved for issues during Tasks 3–7.

## Risks and mitigation

- **`HabitRowView` API change** breaks TodayView's call site:
  Mitigation: Task 3 updates both in one commit.
- **`@Bindable` on `HabitRecord` across multiple components**:
  mutations propagate via SwiftData observation. No explicit
  re-fetch needed.
- **Swipe-to-delete races with optimistic UI**: deleting a
  completion removes it from the list reactively (via the
  `habit.completions` relationship). Should just work.
- **XcodeBuildMCP flake**: OS-pinned `xcodebuild` fallback is
  documented.

## Open questions

None — all resolved in research.

## Out of scope

- Live Activities / real timer start-stop (v0.3).
- Notes / photos on completions (post-v1.0).
- Scrollable past-months calendar (later PR).
- Multi-session timer logging in a single day.
- Editable value on history rows (only delete).
