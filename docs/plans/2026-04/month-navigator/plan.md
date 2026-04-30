# Plan — Month navigator

**Date**: 2026-04-29
**Status**: done
**Research**: [research.md](./research.md)

## Summary

Add month navigation to the habit detail calendar so users can browse
past months. Chevron buttons flank the month title; tapping the title
resets to the current month. Month changes animate with a directional
slide. Backward navigation is unlimited; forward navigation stops at
the current month.

## Decisions locked in

- Navigation lives inside `MonthlyCalendarView` — any consumer that sets `navigable: true` gets it for free.
- `month` becomes `@Binding var month: Date`; `navigable: Bool` toggles navigation visibility.
- Tap month title → reset to current month.
- Slide animation matching chevron direction on month change.
- Dismiss any open day-edit popover on month change.
- Convenience init (read-only callers) keeps `month: Date` signature via `.constant()` wrapper, no navigation shown.

## Task list

### ~~Task 1: Add month navigation to MonthlyCalendarView~~ ✅

**Goal**: Turn the static month header into a navigable one with
chevron buttons, bounds, animation, and tap-to-reset.

**Changes**:
- `Kado/UIComponents/MonthlyCalendarView.swift`:
  - Change `var month: Date = .now` → `@Binding var month: Date`
  - Add `var lowerBound: Date? = nil`
  - Replace `monthHeader` with a conditional layout:
    - When `lowerBound` is nil: current plain `Text` (backward compat)
    - When `lowerBound` is set: `HStack` with `chevron.left` button,
      tappable month title, `chevron.right` button
  - Previous button: `calendar.date(byAdding: .month, value: -1, to: month)`;
    disabled when displayed month contains `lowerBound`
  - Next button: `calendar.date(byAdding: .month, value: 1, to: month)`;
    disabled when displayed month is current month
  - Tap title: set `month = .now`
  - On any navigation: set `selectedDay = nil` to dismiss popovers
  - Add `.transition(.asymmetric(...))` or `.animation` keyed on month
    for directional slide
  - Update the `EmptyView` convenience init: accept `month: Date = .now`,
    pass `.constant(month)` to the binding, leave `lowerBound` nil
  - Update all previews for the new init signature

**Tests / verification**:
- Previews compile and render correctly
- `build_sim` passes

**Commit message (suggested)**: `feat(calendar): add month navigation to MonthlyCalendarView`

---

### ~~Task 2: Wire month navigation in HabitDetailView~~ ✅

**Goal**: Connect the new navigation to the habit detail screen.

**Changes**:
- `Kado/Views/HabitDetail/HabitDetailView.swift`:
  - Add `@State private var displayedMonth: Date = .now`
  - Pass `month: $displayedMonth` to `MonthlyCalendarView`
  - Compute `lowerBound` from
    `habit.snapshot.effectiveStart(completions:calendar:)`
    and pass it

**Tests / verification**:
- `build_sim` passes
- Navigate to a habit detail → chevrons appear
- Navigate backward → see previous month
- Navigate past `effectiveStart` → left chevron disabled
- Current month → right chevron disabled
- Tap month title → returns to current month

**Commit message (suggested)**: `feat(detail): wire month navigation in HabitDetailView`

---

### ~~Task 3: Localization (EN + FR)~~ ✅

**Goal**: Add catalog entries for the new accessibility labels and any
visible strings.

**Changes**:
- `Kado/Resources/Localizable.xcstrings`:
  - `"Previous month"` — accessibility label for left chevron
    (FR: `"Mois précédent"`)
  - `"Next month"` — accessibility label for right chevron
    (FR: `"Mois suivant"`)

**Tests / verification**:
- `LocalizationCoverageTests` passes
- `build_sim` passes

**Commit message (suggested)**: `feat(l10n): add month navigator translations (EN + FR)`

---

### Task 4: Visual verification

**Goal**: Confirm the feature looks correct on light/dark, iPhone/iPad.

**Changes**: none (verification only)

**Verification**:
- `screenshot` on iPhone sim — light mode, current month
- `screenshot` on iPhone sim — dark mode, navigated to past month
- Verify disabled chevron state visually
- Check Dynamic Type XXXL doesn't clip the header

**Commit message (suggested)**: n/a (no code changes)

## Risks and mitigation

- **Animation jank with popover dismissal**: dismissing the popover
  and animating the month transition simultaneously might look odd.
  Mitigation: set `selectedDay = nil` *before* updating `month`, or
  use `withAnimation` only on the month change so the popover
  dismisses instantly.
- **Convenience init breakage**: changing `month` to `@Binding`
  affects the memberwise init. Mitigation: the `EmptyView`
  convenience init wraps the plain `Date` in `.constant()`, so
  existing read-only callers are unaffected.

## Open questions

None — all resolved during research.

## Notes during build

- **Tasks 1–3** shipped in a single commit — the feature is small
  enough that splitting would have been artificial. All three files
  (`MonthlyCalendarView`, `HabitDetailView`, `Localizable.xcstrings`)
  are tightly coupled.
- No surprises; the `@Binding` change was clean and the convenience
  init wrapped in `.constant()` with no call-site breakage.
- Visual verification limited: XcodeBuildMCP tap primitives are not
  enabled, so the habit detail screen could not be reached in the
  simulator. Build + 318 tests pass. Manual verification by the user
  is needed.

## Out of scope

- Swipe gesture for month navigation (future polish)
- `TabView(.page)` infinite-scroll approach (over-engineered for now)
- Month navigation on the Overview matrix (separate feature)
