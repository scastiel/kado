# Plan — Daily completion reward

**Date**: 2026-09-09
**Status**: done
**Research**: [research.md](./research.md)
**Compound**: [compound.md](./compound.md)

## Summary

Reward the moment the last habit scheduled for today is completed:
confetti over whatever screen the user is on, plus a lock-screen
circular widget that shows *completed / scheduled* as a closing ring.
The "day just became complete" edge is detected once, in the snapshot
rebuild every completion path already runs through, so Today rows,
Detail, log sheets, notification actions and Siri all celebrate the
same way. No schema or snapshot-shape change.

## Decisions locked in

- The all-done rule is `total > 0 && completed == total`, in one
  place (`DayProgress.isComplete`), shared by the celebration, the
  review-prompt milestone and the widget.
- Detection lives in `WidgetSnapshotBuilder.rebuildAndWrite` (the
  funnel), through a pure `DayCompletionTracker` and a process-scoped
  `@Observable` `DayCompletionCelebration.shared`.
- The tracker fires only on a *same-day* incomplete→complete edge. The
  first observation and any change of logical day are baselines. Dev
  mode swaps reset it.
- Confetti replays if the day is un-ticked and re-ticked (no
  once-per-day gate). Open question carried below.
- No extra haptic: the row control already fires `.success`.
- `reduceMotion` replaces the particles with a static caption that
  fades. A VoiceOver announcement is posted either way.
- The confetti overlay hangs off `ContentView`, above the tab view.
- The widget is a **new** `accessoryCircular` kind
  (`dev.scastiel.kado.widget.lockDayProgress`); the per-habit circular
  widget is untouched. Numbers always ("5/5" when done), "–" when
  nothing is due.
- Confetti colours: the eight `HabitColor` hues plus `Color.kadoSage`.
  Literal colours are acceptable here — they are the habit palette,
  not new UI chrome.

## Task list

### Task 1: `DayProgress` value type (tests first) ✅

**Goal**: one home for the completed / scheduled pair and the all-done
rule.

**Changes**:
- `Packages/KadoCore/Sources/KadoCore/Models/DayProgress.swift` —
  `nonisolated public struct DayProgress: Hashable, Sendable` with
  `completed`, `total`, `isComplete`, `fraction`, `static let empty`.
- `WidgetSnapshot.dayProgress` computed property.
- `TodayView.checkMilestones` builds a `DayProgress` from the due rows
  and uses `isComplete` (fixes the empty-schedule false positive).
- `KadoTests/DayProgressTests.swift`.

**Tests / verification**:
- 0/0 not complete; 3/3 complete; 2/3 not; fraction 0 for empty,
  clamped to 1; snapshot mirror.
- `test_sim` green.

**Commit message (suggested)**: `feat(core): add DayProgress with the shared all-done rule`

---

### Task 2: `DayCompletionTracker` + `DayCompletionCelebration` (tests first) ✅

**Goal**: detect the same-day incomplete→complete edge at the funnel.

**Changes**:
- `Packages/KadoCore/Sources/KadoCore/Services/DayCompletionTracker.swift`
  — pure `nonisolated public struct`, `record(_:on:) -> Bool`,
  `reset()`.
- `Packages/KadoCore/Sources/KadoCore/Services/DayCompletionCelebration.swift`
  — `@MainActor @Observable public final class`, `static let shared`,
  `private(set) var celebrationCount: Int`, `observe(_:on:)`,
  `reset()`.
- `WidgetSnapshotBuilder.rebuildAndWrite` computes the logical day
  once, builds, writes, then
  `DayCompletionCelebration.shared.observe(snapshot.dayProgress, on: day)`.
  Doc comment explains why the funnel is the right place.
- `KadoApp.onChange(of: isDevMode)` calls
  `DayCompletionCelebration.shared.reset()` before the reload.
- `KadoTests/DayCompletionTrackerTests.swift`.

**Tests / verification**:
- The eight tracker cases listed in research.
- `test_sim` green; `build_sim` clean.

**Commit message (suggested)**: `feat(core): detect the moment the day becomes complete`

---

### Task 3: `ConfettiView` ✅

**Goal**: a self-contained, previewable particle burst.

**Changes**:
- `Kado/UIComponents/ConfettiView.swift` — `TimelineView(.animation)`
  + `Canvas`; ~120 particles; closed-form position from elapsed time
  (gravity, drag-free drift, sine sway, spin, fake 3D flip via x
  scale); fade over the last 20%; seeded RNG; `static let duration`.
- Previews: light, dark.

**Tests / verification**:
- Previews compile; `build_sim` clean. Visual check comes with Task 5.

**Commit message (suggested)**: `feat(today): add a confetti view`

---

### Task 4: celebrate on `ContentView` ✅

**Goal**: play the confetti (or the reduced-motion caption) when the
celebration count changes.

**Changes**:
- `Kado/Views/DayCompletionCelebrationModifier.swift` — reads
  `@Environment(\.dayCompletionCelebration)`, `.onChange(of:
  celebrationCount)` starts a run keyed by count; overlay
  (`allowsHitTesting(false)`, `ignoresSafeArea`) removed after
  `ConfettiView.duration`; `reduceMotion` → caption pill; posts
  `AccessibilityNotification.Announcement`.
- `EnvironmentValues+Services.swift` — `@Entry var
  dayCompletionCelebration: DayCompletionCelebration = .shared`.
- `ContentView` — `.dayCompletionCelebration()`.
- `Shared/AccessibilityID.swift` — `Celebration.caption`.
- `Kado/Resources/Localizable.xcstrings` — "All done for today" (EN /
  FR "Tout est fait pour aujourd'hui").

**Tests / verification**:
- `LocalizationCoverageTests` green; `build_sim` iPhone + iPad clean.

**Commit message (suggested)**: `feat(today): celebrate with confetti when the day is complete`

---

### Task 5: UI test and screenshot ✅

**Goal**: prove the edge fires end to end and photograph it.

**Changes**:
- `KadoUITests/DayCompletionCelebrationTests.swift` — launch with a
  reset, empty store; create one habit through the sheet; tap the
  row's pill (trailing coordinate); assert the caption element
  appears; `capture`.
- `Shared/AccessibilityID.swift` — `NewHabit.saveButton` if the sheet
  has no identifier on Save yet.

**Tests / verification**:
- `make e2e` green; screenshot attachment exported and eyeballed.

**Commit message (suggested)**: `test(e2e): cover the day-complete celebration`

---

### Task 6: lock-screen day-progress widget ✅

**Goal**: the circular ring with "completed/scheduled".

**Changes**:
- `KadoWidgets/LockDayProgressWidget.swift` — `StaticConfiguration`
  + `SnapshotTimelineProvider`, `.accessoryCircular`,
  `Gauge(value:)` `.accessoryCircularCapacity`, `Text` "3/5"
  (monospaced digits), "–" when `total == 0`, `.widgetAccentable()`,
  accessibility label reusing "%lld of %lld habits done today" /
  "No habits due today".
- `KadoWidgetsBundle` — register after `LockInlineWidget`.
- `KadoWidgets/Support/PreviewSnapshots.swift` — `allDone` fixture.
- `KadoWidgets/Resources/Localizable.xcstrings` — display name
  "Daily Progress", description, and the "%lld/%lld" label key, with FR.
- Previews: partial, complete, empty.

**Tests / verification**:
- `LocalizationCoverageTests` green; `build_sim` (widget target builds
  with the app) clean.
- Manual: add the widget to a lock screen on device, check Clear /
  Tinted.

**Commit message (suggested)**: `feat(widget): add a lock-screen ring with today's completed / scheduled count`

---

### Task 7: docs ✅

**Goal**: roadmap and plan bookkeeping.

**Changes**:
- `docs/ROADMAP.md` — note the celebration and the new lock widget.
- This plan: checkboxes, notes during build.
- `compound.md`.

**Commit message (suggested)**: `docs: record the daily completion reward`

## Risks and mitigation

- **Spurious confetti after a dev-mode swap or a day-start change** →
  reset before the swap; a day change is a baseline by construction.
  Covered by tracker tests.
- **Intent runs before the launch seed** → the tap becomes the
  baseline, no confetti. Documented; no false positive possible.
- **Overlay left in the hierarchy** → keyed by run id and removed on a
  `.task` timer; re-entrant runs restart the timer.
- **Widget invisible under Clear / Tinted** → `Gauge` is system-drawn;
  the label is `.primary`. Verify by hand on device (the suite cannot).

## Open questions

- [ ] Once-per-day gate instead of replaying on re-tick?
- [ ] A distinct celebratory haptic?
- [ ] Checkmark instead of "5/5" in the ring when complete?

## Out of scope

- Rollover-aware widget refresh (pre-existing roadmap item).
- A progress header inside the app's Today list.
- Rectangular / inline variants of the day ring (inline already says
  "3 of 5 done today").
- Streak or score milestones (7-day, 30-day) celebrations.

## Notes during build

- **Task 2**: `#expect(tracker.record(...))` does not compile — the
  macro captures its operands, and a mutating call on a captured `var`
  is an error ("cannot use mutating member on immutable value: '$0'").
  Bind the result to a `let` and expect that.
- **Task 4**: a preview that calls `.modelContainer(_:)` needs
  `import SwiftData` in that file even though the view itself doesn't.
- **Task 5**: a Today row is one combined accessibility element, so
  XCUITest cannot address its pill, and custom accessibility actions
  ("Mark as done") are not reachable from XCUITest either. The test
  taps the row at a normalised offset (`dx: 0.92`), which lands on the
  28pt check circle on both phone widths. Both cases passed first run.
- **Task 5**: the screenshot came out of the result bundle with
  `xcrun xcresulttool export attachments --path build/Logs/Test/<run>.xcresult --output-path <dir>`;
  `manifest.json` maps attachment names to the exported files. That is
  the way to *see* a three-second animation when the tooling has no
  tap primitive.
- **Visual check**: the first burst read a touch small on a 3× screen
  (rects 6–11pt). Bumped to 7–14 × 4–7.5pt and circles 3–5.5pt.
- **After the device run**: a negative habit's `HabitRowState.status`
  is `.complete` when it *slipped*, and the day's tally counted
  `.complete` as done — so a slip counted as a completion (and could
  be the "last habit" that fired the confetti), while an avoided
  "don't" habit counted as not done. Added
  `HabitRowState.isDone(for:)` — done means target met, or no slip for
  a negative habit — and routed the snapshot count and the Today
  milestone through it. Pinned by three row-state tests and a builder
  test.
- **After the device run, on request**: the top-edge rain was rebuilt
  as two party poppers, one per side, firing inward and up. Motion is
  a launch under gravity with linear air drag, solved exactly, so it
  is still closed-form and stateless. Speeds and gravity are tuned in
  phone points and scaled with the shorter screen side, so an iPad
  gets the same burst shape. 220 pieces, a 0–0.18s roll on the
  launch, and the duration went to 3.4s.
- **"Highly unnatural", on the device**: two causes. The overlay's
  `.move(edge: .top)` transition was on the *whole* overlay, so the
  canvas — and every piece — slid downward during the pop; the
  transition now sits on the caption alone and the canvas only fades.
  And the physics: launch speeds of 2200–3400 pt/s with drag 2.4–3.6
  meant every piece reached its extent inside a third of a second
  (a flash, not a flight), then fell at a constant 150–300 pt/s on a
  perfect sine — static snow. Now 1000–1900 pt/s with drag 1.3–2.1
  (arcs visible for ~0.8 s), a fan bunched around a 68° axis, a 0.3 s
  launch roll per side, 320–520 pt/s falls (dots 480–680), and a
  falling-leaf float whose fall speed and tumble share one phase.
  Judged from a 6 fps contact sheet of a simulator recording
  (`xcrun simctl io <udid> recordVideo` around a single
  `test-without-building` run, then `ffmpeg … tile=`) — the only way
  to see *motion* headless.
- **Catalogs**: appended with a small script that dumps with
  `separators=(",", " : ")` so the diff is purely additive and matches
  Xcode's layout; the widget catalog had no trailing newline, so its
  diff shows one cosmetic `}` line.
