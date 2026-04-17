---
# Compound — New Habit form

**Date**: 2026-04-17
**Status**: complete
**Research**: [research.md](./research.md)
**Plan**: [plan.md](./plan.md)
**Branch / PR**: [feature/new-habit-form](https://github.com/scastiel/kado/pull/5)

## Summary

Shipped the habit creation flow: toolbar "+" on Today presents a
modal `NewHabitFormView` sheet driven by an `@Observable`
`NewHabitFormModel`. Sheet covers name + 4-way frequency picker +
4-way type picker with conditional param rows. Save inserts the
`HabitRecord` and dismisses. Scope matches the research — no icon,
color, reminder, or `createdAt` editing. **Headline: the plan
landed verbatim (zero pivots), the `@Observable` threshold call
from the Today-view compound held up, and the known XcodeBuildMCP
destination flake revealed a new root cause (`OS:latest` not
matching concrete sim versions like `26.4.1`).**

## Decisions made

- **`@Observable NewHabitFormModel` (ViewModel warranted)**: this
  is exactly the case the Today-view compound carved out — multiple
  mutable fields, cross-field validation, and a `build()` that
  composes enum cases with associated values. The alternative
  (8 `@State` vars + scattered validation) would have duplicated
  the assembly logic between `.disabled(!isValid)` and the save
  action. CLAUDE.md's ViewModel threshold rule earned its keep.
- **Per-kind draft params as separate stored properties**:
  `daysPerWeek`, `specificDays`, `everyNDays`, `counterTarget`,
  `timerTargetMinutes` each live independently. Toggling
  `frequencyKind` or `typeKind` doesn't wipe a partially-entered
  variant — predictable UX, one regression test guards it.
- **`FrequencyKind` / `HabitTypeKind` plain enums beside the
  Codable `Frequency` / `HabitType`**: `Picker` needs a
  `Hashable` tag without associated values. Two tiny enums in
  the model are cleaner than trying to derive tags from the
  domain types.
- **Timer stored as seconds, edited as minutes**: `HabitType` is
  canonical (seconds); the form layer converts once in
  `type`/`build()`. One regression test guards the 60x.
- **Trailing toolbar Save, disabled until `isValid`**: matches
  Reminders / Calendar / Shortcuts. No inline "fix this" errors at
  MVP — disabled button is the discoverable cue.
- **Sheet inherits the `modelContainer`**: no explicit propagation
  needed in the `.sheet {}` closure. SwiftUI environment threading
  works as expected.
- **`@FocusState` autofocus on the name field**: one line
  (`.onAppear { nameFocused = true }`) handles it.
- **Haptic on save via `.sensoryFeedback(.success, trigger: saveTick)`**:
  an `Int` counter bumped in the save branch. No first-render
  spurious trigger observed.
- **`WeekdayPicker` as a reusable `UIComponents/` component**:
  will be reused for edit mode, notification schedules, and
  wherever we let users pick weekday subsets.
- **Mon-Sun display order for EN**: locale-aware ordering deferred
  — good enough for v0.1 with EN-only strings.

## Surprises and how we handled them

### Destination flake returned, shutdown/boot didn't clear it

- **What happened**: `test_sim` via XcodeBuildMCP failed with
  `Unable to find a destination matching { platform:iOS Simulator, OS:latest, name:iPhone 17 Pro }`
  — the same pattern documented in CLAUDE.md from the previous
  feature. Applied the documented workaround
  (`xcrun simctl shutdown all && boot`), but it didn't clear the
  error this time. Ran `xcodebuild -showdestinations` and found
  the real OS is `26.4.1` — the sim updated since we last
  ran. The MCP tool sends `OS:latest`, xcodebuild apparently
  can't always map `latest` to `26.4.1`.
- **What we did**: Ran `xcodebuild` via Bash directly with an
  explicit `OS=26.4.1` destination. Tests ran green (76/76).
  Updated CLAUDE.md's workaround section to document the
  pinned-OS escalation after the shutdown/boot path.
- **Lesson**: When the simulator runtime has a minor version bump
  (`26.4` → `26.4.1`), the MCP tool's `OS:latest` default can
  become stale. The three-step escalation (boot cycle → pinned
  OS `xcodebuild` → DerivedData clean) now lives in CLAUDE.md.

### Live end-to-end flow testing blocked without idb/Appium

- **What happened**: The PR adds a sheet that presents on tap, but
  XcodeBuildMCP in this configuration exposes no UI automation
  tool (tap, type, dismiss). `snapshot_ui` prints the hierarchy
  but can't interact. The plan's verification step for Task 5
  ("tap +, fill name, Save, verify persistence") had no path.
- **What we did**: Relied on `NewHabitFormModelTests` (12 cases
  covering every validity predicate + every build() projection)
  plus SwiftUI previews (3 permutations of the form). Screenshot
  confirms the "+" button renders correctly. Accepted the
  end-to-end gap; the user verifies interactively by opening
  Simulator.app manually.
- **Lesson**: Until XcodeBuildMCP gains tap/type primitives (or
  we install `idb`), end-to-end sheet flows are
  preview-plus-unit-test territory. That's a reasonable MVP
  tradeoff — the sheet wiring is standard SwiftUI, and the
  model validation is the bit worth exhaustive regression
  coverage.

## What worked well

- **Plan landed verbatim**: zero pivots during build. The
  research's 6-question resolution step settled every decision
  before any code. Five code commits, each matched one task.
- **`@Observable` with per-kind stored properties**: the
  "non-destructive kind switch" invariant was the one non-obvious
  UX detail, and the plan called it out. The test
  (`kindToggleIsNonDestructive`) codifies it — future refactors
  that collapse draft state into a single associated-value enum
  would trip the test immediately.
- **Composition of two tiny picker enums + source-of-truth
  Codable enums** made the view code read linearly:
  `Picker("Repeats", selection: $model.frequencyKind) { Text… .tag(.daily) … }`
  then `switch model.frequencyKind { … }` for the conditional row.
  No coercion between domain and view types.
- **Previews covering both default state and 2 pre-filled
  permutations** without needing a `ModelContainer` (form doesn't
  read from the context until Save) — previews are cheap,
  pre-fills exercise the conditional rendering paths that default
  state can't.
- **Build notes section in `plan.md`** again earned its keep —
  the destination-flake debugging got recorded as it happened,
  not reconstructed here.

## For the next person

- **`NewHabitFormModel` has two enum declarations**
  (`FrequencyKind`, `HabitTypeKind`) that mirror the domain
  enums' case names but without associated values. They exist
  solely to be `Picker.tag` values. When you add a new
  `Frequency` case (e.g. `.monthlyOnDate`), you MUST add it to
  both `Frequency` AND `FrequencyKind` — the model's
  `frequency` computed property's `switch` will catch it with a
  compiler error; the `Picker` won't.
- **Timer minutes → seconds conversion** lives in exactly one
  place: `NewHabitFormModel.type`. Don't duplicate the `* 60` at
  call sites. `HabitType.timer(targetSeconds:)` is canonical.
- **`@Bindable var model: NewHabitFormModel`** requires iOS 17+.
  `@ObservedObject` equivalent is not needed — `@Observable`
  classes work with `@Bindable` for mutable bindings into
  children.
- **Name is trimmed** in `trimmedName` and `build()`, not at
  text-field `onChange`. The user sees their raw input while
  typing; trimming happens on save. Intentional.
- **Save calls `try? modelContext.save()`** and swallows failure.
  In-memory contexts can't fail; file-backed ones can on
  disk-full, permission issues, or iCloud sync conflicts. MVP
  tradeoff: the alternative (toast on failure) belongs in a
  post-MVP error-surfacing pass, not here.
- **Entry point lives in TodayView's toolbar**. When the habit
  list tab splits into Today + All Habits (post-v0.1), the "+"
  moves to the All Habits tab — Today stays read-only.
- **`WeekdayPicker` doesn't adapt to locale first-day**. Mon-Sun
  is baked in. When French ships, revisit.

## Generalizable lessons

- **[→ CLAUDE.md]** Already promoted: the `OS:latest` →
  pinned-version workaround for XcodeBuildMCP destination
  resolution (see Known limitations section).
- **[→ CLAUDE.md]** When a domain enum has associated values and
  the UI needs to present it as a `Picker`, pair it with a
  case-only "kind" enum at the ViewModel layer. Store the
  associated-value params as separate properties so toggling the
  kind is non-destructive. Pattern: `NewHabitFormModel`'s
  `FrequencyKind` + `daysPerWeek`/`specificDays`/`everyNDays`
  triple. Worth a bullet under SwiftData / domain types
  conventions if it recurs.
- **[local]** The "per-kind draft params" pattern has one test
  (`kindToggleIsNonDestructive`) guarding the invariant. When
  refactoring, don't collapse without updating or re-deriving
  that test.
- **[local]** `@Bindable` + `.sheet { NewHabitFormView(model: NewHabitFormModel()) }`
  creates a fresh model per sheet presentation. Good default —
  sheets are modal, state shouldn't persist across dismissals.

## Metrics

- Tasks completed: 5 of 6 (Task 6 polish skipped, as in previous
  feature)
- Tests added: 12 (`NewHabitFormModelTests`)
- Total test count: 64 → 76 (76/76 green)
- Commits on branch: 9 (3 docs, 5 build, 1 CLAUDE.md update)
- Files added: 3 source + 1 test + 3 docs
- Files modified: 2 source (TodayView, CLAUDE.md)
- Net diff: +922 / -5 across 8 files (of which ~487 lines are
  plan/research/compound docs)
- Mid-build pivots: 0
- Plan revisions during build: 0

## References

- [@Observable](https://developer.apple.com/documentation/observation)
- [@Bindable](https://developer.apple.com/documentation/swiftui/bindable)
- [SwiftUI Form](https://developer.apple.com/documentation/swiftui/form)
- [@FocusState](https://developer.apple.com/documentation/swiftui/focusstate)
- [today-view compound](../today-view/compound.md) — source of the
  ViewModel-threshold rule that shaped this PR's architecture.
- [swiftdata-models compound](../swiftdata-models/compound.md) —
  the composite-Codable-enum constraint we dodged here by storing
  kind-plus-params separately rather than serializing directly.
