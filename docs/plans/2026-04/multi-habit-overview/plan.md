# Plan — Multi-habit overview

**Date**: 2026-04-17
**Status**: in progress
**Research**: [research.md](./research.md)

## Summary

Add an **Overview** tab that renders a habits × days matrix with
score-tinted cells, each habit carrying its own color. The branch
bundles a schema V2 migration adding `Habit.color` and `Habit.icon`
(v0.1 ROADMAP items that are load-bearing for the matrix's visual
identity). Cells are tinted by EMA score (gradient opacity); tapping
a cell surfaces an inline popover with that day's completion detail.

## Decisions locked in

- **Cell encoding**: gradient opacity on habit color (0 = empty,
  1 = full color)
- **Schema scope**: bundled — one branch covers `Habit.color` +
  `Habit.icon` + the matrix
- **Default day window**: 30 days, scrolls left into past
- **Tap behavior**: inline popover showing that day's completion
- **Day order**: newest-on-right, initial scroll anchored at today
- **Icon picker**: curated shortlist (~30 common habit icons), not
  searchable SF Symbol grid
- **Color palette**: 8 semantic named colors adapting to dark mode
  (exact palette locked in Task 1)

## Progress

- [x] Task 1: HabitColor palette + icon catalog
- [x] Task 2: Schema V2 — color + icon fields
- [x] Task 3: Color + icon pickers in habit forms
- [x] Task 4: Color + icon surface in existing views
- [x] Task 5: OverviewMatrix tests (red)
- [x] Task 6: OverviewMatrix implementation (green)
- [ ] Task 7: Matrix UI primitives
- [ ] Task 8: OverviewView + tab integration
- [ ] Task 9: Cell tap popover
- [ ] Task 10: Accessibility + multi-size polish

## Task list

### Task 1: HabitColor palette + curated icon catalog

**Goal**: foundation primitives the rest of the tasks depend on.

**Changes**:
- `Kado/Models/HabitColor.swift` — enum, 8 cases (e.g. `.red`,
  `.orange`, `.yellow`, `.green`, `.mint`, `.teal`, `.blue`,
  `.purple`), each resolving to a semantic `Color` adaptive to dark
  mode. `Codable`, `Sendable`, `nonisolated` (Codable conformance
  used off MainActor by SwiftData encoders).
- `Kado/Models/HabitIcon.swift` — namespace with
  `static let curated: [String]` (~30 SF Symbols: `book.fill`,
  `figure.walk`, `dumbbell.fill`, `moon.zzz.fill`, `cup.and.saucer.fill`,
  `drop.fill`, `figure.mind.and.body`, …).

**Tests**:
- `@Test("HabitColor all cases resolve to a non-clear Color")`
- `@Test("HabitIcon.curated has no duplicate symbol names")`
- `@Test("HabitIcon.curated has >= 20 entries")`

**Commit**: `feat(habit): HabitColor palette and curated icon shortlist`

---

### Task 2: Schema V2 — color + icon fields

**Goal**: persist color and icon on `HabitRecord` with clean migration.

**Changes**:
- `Kado/Models/Schema/KadoSchemaV2.swift` — mirror V1 models; add
  `color: HabitColor = .blue` and `icon: String = "circle"` to
  `HabitRecord`. Both defaulted (CloudKit shape).
- `Kado/Models/Schema/KadoMigrationPlan.swift` — append
  `.lightweight(fromVersion: KadoSchemaV1.self, toVersion: KadoSchemaV2.self)`
  to `stages`.
- Value-type `Habit` snapshot gains `color`, `icon`.
- Update `HabitRecord.snapshot` and any `init(from snapshot:)` paths.

**Tests**:
- `KadoTests/CloudKitShapeTests.swift` — still green (new props
  respect optional-or-defaulted + non-unique invariants).
- `@Test("Habits migrated from V1 inherit default color and icon")`
  (via in-memory container seeded with V1 data, migrated to V2).

**Commit**: `feat(schema): add color and icon to Habit via V2 migration`

---

### Task 3: Color + icon pickers in habit forms

**Goal**: let users pick color + icon when creating or editing.

**Changes**:
- `Kado/UIComponents/HabitColorPicker.swift` — swatch grid, selected
  state visible.
- `Kado/UIComponents/HabitIconPicker.swift` — icon grid from
  `HabitIcon.curated`, tinted with the currently-selected color.
- `Kado/ViewModels/NewHabitFormModel.swift` — add `color`, `icon`
  with defaults (`.blue`, `"circle"`).
- `Kado/Views/Habit/NewHabitFormView.swift` and any Edit form — wire
  in both pickers. Picker rows follow the `Picker`-over-assoc-value
  pattern already used for Frequency (see CLAUDE.md).
- Localization: picker labels, accessibility labels.
- Previews: each color represented; icon grid at Dynamic Type XXXL.

**Tests**:
- `NewHabitFormModelTests` — defaults hold; setting color/icon
  round-trips into the saved Habit.

**Commit**: `feat(habit-form): pick color and icon when creating a habit`

---

### Task 4: Color + icon surface in existing views

**Goal**: every habit-display surface uses the new fields.

**Changes**:
- `Kado/UIComponents/HabitRowView.swift` — leading glyph = `habit.icon`,
  tinted by `habit.color`.
- `Kado/UIComponents/MonthlyCalendarView.swift` — completed cells
  tint to `habit.color` instead of `.accentColor` (other states
  unchanged).
- `Kado/Services/DevModeSeed.swift` — set a distinct color + icon on
  each seeded habit; bump completion density so previews look alive.

**Tests**:
- No new unit tests; visual via previews + `screenshot`.
- Dev mode preview shows 5 distinctly-colored rows.

**Commit**: `feat(habit-display): surface color and icon in rows and calendar`

---

### Task 5: OverviewMatrix tests (red)

**Goal**: pin the matrix service contract before implementing.

**Changes**:
- `KadoTests/OverviewMatrixTests.swift` — tests for the free struct:
  - rows one-per-non-archived-habit, sorted by createdAt
  - archived habits excluded
  - cell is `.future` beyond today
  - cell is `.notDue` when `FrequencyEvaluator` says not due
  - cell is `.scored(s)` where `s` matches `scoreHistory` on due days
  - empty habit list → empty matrix

**Verification**: `test_sim` — new tests fail (expected).

**Commit**: `test(overview): OverviewMatrix service contract (red)`

---

### Task 6: OverviewMatrix implementation (green)

**Goal**: make Task 5 green.

**Changes**:
- `Kado/Services/OverviewMatrix.swift` — free struct with
  `static func compute(habits, completions, dayRange, calendar, scoreCalculator, frequencyEvaluator) -> [MatrixRow]`
- Types: `MatrixRow(habit, days: [DayCell])`,
  `DayCell { case future, notDue, scored(Double) }`.
- Memoizes per-habit `scoreHistory` call; non-due days read through
  from the score history (carries forward).

**Verification**: `test_sim` — all green.

**Commit**: `feat(overview): OverviewMatrix service`

---

### Task 7: Matrix UI primitives

**Goal**: cell + header + row components.

**Changes**:
- `Kado/UIComponents/MatrixCell.swift` — takes `DayCell` +
  `HabitColor`. `.scored(s)` renders habit color at
  `max(0.08, s)` opacity (floor preserves perceptibility at low
  scores). `.notDue` is a faint tertiary fill. `.future` is empty.
- `Kado/UIComponents/DayColumnHeader.swift` — `Weekday.localizedShort`
  letter on top, day-of-month number below.
- `Kado/UIComponents/MatrixRowView.swift` — habit icon + name +
  `LazyHStack` of `MatrixCell`s.
- Previews across state space + full palette.

**Tests**:
- `@Test("MatrixCell scored opacity equals max(floor, score)")`

**Commit**: `feat(overview): matrix cell, header, and row components`

---

### Task 8: OverviewView + tab integration

**Goal**: shipping the Overview tab.

**Changes**:
- `Kado/Views/Overview/OverviewView.swift` — `@Query` for
  non-archived habits; derive `dayRange` (last 30 days); call
  `OverviewMatrix.compute`; render sticky-left habit column +
  horizontally-scrollable day region (`ScrollView(.horizontal)` +
  `LazyHStack`). Initial offset anchored at today's column.
- `Kado/App/ContentView.swift` — third tab between Today and
  Settings.
- Empty state: `ContentUnavailableView` when no habits.
- Localization: "Overview" tab label, empty state strings.
- Previews: populated, empty, dark, iPad Air, Dynamic Type XXXL.

**Verification**:
- `build_sim` clean.
- `screenshot` iPhone 17 Pro (light + dark), iPad.

**Commit**: `feat(overview): add Overview tab with habits × days matrix`

---

### Task 9: Cell tap popover

**Goal**: tapping a cell inspects that day.

**Changes**:
- Attach `.popover` to each cell with
  `.presentationCompactAdaptation(.popover)` so iPhone keeps the
  popover presentation rather than sheeting.
- Popover content: habit name + icon, date formatted long, completion
  value (if any), EMA score that day formatted as percent.
- Localization: popover strings.

**Verification**:
- Manual: tap each state (scored, notDue, future) — popover content
  matches.
- VoiceOver: popover announces when presented.

**Commit**: `feat(overview): tap a cell to inspect that day`

---

### Task 10: Accessibility + multi-size polish

**Goal**: meet the "done" bar.

**Changes**:
- Per-cell accessibility label:
  `"{habit}, {weekday} {day}, {state description}, score {pct}%"`.
- Dynamic Type XXXL: habit-name column gets a max width and wraps.
- iPad: cell size slightly larger if warranted.
- Dark-mode pass on all new views.

**Verification**:
- VoiceOver spot check on iPhone 17 Pro.
- `screenshot` at Dynamic Type XXXL.
- iPad Air M2 (or M4 substitute) screenshot.

**Commit**: `feat(overview): accessibility and multi-size polish`

## Integration checkpoints

- **SwiftData schema change** (Task 2): KadoSchemaV2 is the project's
  first real schema bump. Verify migration locally on a device with
  existing data before merging, even though v0.1 isn't released.
- **CloudKit shape** (Task 2): regression test must pass with new
  fields — both defaulted, neither `.unique`.
- **ContentView tab addition** (Task 8): check that the existing
  Dev-mode container swap (preserves view state across toggle) still
  works with three tabs.

## Risks and mitigation

- **Scope growth**: if the branch balloons past ~1500 lines of diff,
  split at the natural seam between Task 4 and Task 5. Tasks 1-4
  form a valid precursor PR (color/icon for v0.1 displays); Tasks
  5-10 form the matrix PR.
- **Popover UX on iPhone**: SwiftUI popovers default to sheets on
  compact width; we pin them via
  `.presentationCompactAdaptation(.popover)`. If that feels wrong
  for small cells, fall back to a custom inline chip or
  `Menu`-based reveal in Task 9.
- **Score computation cost**: 50 habits × 30 days = 1,500
  evaluations. Memoize inside `OverviewView` with `.task(id:)` keyed
  on habit IDs + date range; don't recompute on scroll.
- **Icon picker height at XXXL**: a 30-icon grid may run tall. Test
  with Dynamic Type XXXL early in Task 3 and cap grid columns to 5
  if needed.

## Open questions

- [ ] **Exact color palette hex values** — resolve at Task 1 by
      visually comparing candidate swatches in a preview.
- [ ] **Exact curated icon list** — resolve at Task 1. 30 is a
      starting target; the shortlist should reflect common habit
      categories (movement, mindfulness, nutrition, learning,
      sleep, hygiene, creative).
- [ ] **Cell opacity floor** (0.08 is a guess) — tune in Task 7
      once cells render against real backgrounds.

## Notes during build

- **Task 2 — SwiftData `@Model` macro rejects shorthand defaults**: writing
  `var color: HabitColor = .blue` triggered "A default value requires a
  fully qualified domain named value" from the macro. Using
  `HabitColor.blue` (fully qualified) satisfies it — though see the
  next note.
- **Task 2 — SwiftData can't round-trip even a plain String-raw-value
  enum on Xcode 26 / iOS 18**. `HabitColor` is just
  `String`-`RawRepresentable` (no associated values), yet the app
  crashed at load with `Could not cast Optional<Any> to Kado.HabitColor`.
  The CLAUDE.md workaround for associated-value enums (store raw blob,
  expose computed accessor) had to be generalized. Pattern in
  `KadoSchemaV2.HabitRecord`: `private var colorRaw: String = "blue"`
  backs `var color: HabitColor { get/set }`.
- **Task 2 — stale dev sandbox broke launch after schema bump**. Prior
  V1-shape sqlite on the sim failed SwiftData's staged migration with
  "unknown model version". Added a wipe-and-retry to
  `DevModeController.buildDevContainer` — valid for the dev sandbox
  (disposable), explicitly NOT applied to the production container.

## Out of scope

- **Aggregate stats** (perfect days, average score across habits):
  a future Stats tab, not this PR.
- **Animated transitions** between tabs.
- **Import/export of color/icon fields**: the CSV/JSON exporters
  are their own v0.2 work; they'll travel with the field but format
  stabilization is separate.
- **Widget reuse of color**: home-screen widgets land later in v0.2.
- **watchOS complication color**: v0.3.
