# Compound — Paper/sage re-skin: polish follow-up

**Date**: 2026-04-19
**Status**: complete
**Plan**: [plan.md](./plan.md)
**Branch / PR**: `feature/reskin-polish` → [#18](https://github.com/scastiel/kado/pull/18)

## Summary

Shipped the three planned polish items (dark app icon, branded launch
screen, 稼 働 · in operation footer) plus two walkthrough-surfaced
bugs (empty-state CTA + paper surface on Today/Overview, `daysPerWeek`
vanishing-row regression) and a cosmetic "Today → Scheduled" section
rename. The scope doubled mid-PR because the walkthroughs kept
surfacing small UX friction the re-skin PR hadn't caught. Headline
lesson: **three Xcode/toolchain specifics silently did the wrong
thing** (fake `INFOPLIST_KEY_UILaunchScreen_*` keys, `qlmanage`
flattening alpha, `FrequencyEvaluator.isDue` returning false for a
just-completed day), each requiring a diagnosis + pivot.

## Decisions made

- **Launch storyboard, not declarative Info.plist keys**: fell back to
  `LaunchScreen.storyboard` + `INFOPLIST_KEY_UILaunchStoryboardName`
  once `INFOPLIST_KEY_UILaunchScreen_BackgroundColor` / `_Image` were
  confirmed to be non-real build settings.
- **`rsvg-convert` for icon rasterization**: replaced `qlmanage -t -s`
  after discovering the latter flattens transparent pixels to opaque
  white, visible as a white ring on iOS's superellipse-masked icon.
- **Full-bleed SVG fills (no `rx=40`)**: let iOS's icon mask be the
  sole source of corner radius; our own rounded rect clipped inside
  the mask and produced a visible notch.
- **`Text(verbatim:)` + `accessibilityLabel`**: kanji are brand art,
  not a translatable phrase; localization happens only on the
  VoiceOver label.
- **`daysPerWeek` fix scoped to TodayView, not `FrequencyEvaluator`**:
  adding a `completedToday` check to `isDue` broke
  `DefaultNotificationScheduler.daysPerWeekSaturated`. Moved the
  "should I show this row?" OR into a new TodayView helper; evaluator
  semantics stay pure.
- **Empty state upgrades shipped in same PR**: the "three polish
  items" scope turned out to cover the same surfaces as the walkthrough
  empty-state feedback (Today, Overview), and splitting would have
  been ceremony for the sake of ceremony.

## Surprises and how we handled them

### `INFOPLIST_KEY_UILaunchScreen_BackgroundColor` is not a real key

- **What happened**: set `INFOPLIST_KEY_UILaunchScreen_BackgroundColor`
  and `_Image` in the project; `build_run_sim` succeeded without a
  warning; the cold-launch splash stayed iOS-default white. Generated
  `Info.plist` showed an empty `UILaunchScreen` dict.
- **What we did**: grepped Apple docs, confirmed the only real key in
  that family is `INFOPLIST_KEY_UILaunchScreen_Generation = YES` (which
  enables iOS's auto splash, not a customizable one). Switched to a
  full `LaunchScreen.storyboard` + `INFOPLIST_KEY_UILaunchStoryboardName`.
- **Lesson**: `INFOPLIST_KEY_*` names under `GENERATE_INFOPLIST_FILE`
  are typo-tolerant — Xcode doesn't validate the RHS against a known
  schema. If the generated plist doesn't reflect the change,
  cross-check against Apple's official settings reference before
  building more around a fake key.

### `qlmanage -t -s 1024` flattens alpha

- **What happened**: dark-mode home-screen icon rendered a visible
  white halo around the warm-dark background, because the rasterizer
  baked transparent pixels to opaque white. Same issue on the splash
  mark: a white square around the ensō.
- **What we did**: `brew install librsvg`, switched to
  `rsvg-convert -b 'rgba(0,0,0,0)'`. Also changed the SVGs to fill
  the full 180×180 rect with the background gradient (removed
  `rx=40`) so iOS's own superellipse mask is the only rounding source.
- **Lesson**: macOS ships `qlmanage` for free but it's a preview
  tool, not an SVG toolchain — use `rsvg-convert` (or `librsvg`
  bindings) for anything that needs alpha preserved. Documented in
  this PR but not yet promoted to `CLAUDE.md`.

### `FrequencyEvaluator.isDue` returns false the moment a `daysPerWeek` habit saturates

- **What happened**: checking off a "3× per week" habit on Monday
  (bringing the trailing-7-day window to the target) made the row
  vanish instantly because `isDue` returned false. The user saw their
  just-logged completion disappear.
- **What we did**: first attempt patched `isDue` to OR in
  `completions.contains { sameDay(today) }`. That broke
  `DefaultNotificationSchedulerTests.daysPerWeekSaturated` because
  the scheduler uses the evaluator to decide whether to post a
  reminder — we want **no** reminder after quota is hit. Reverted and
  added a narrower `isDueTodayOrCompletedToday` helper local to
  TodayView.
- **Lesson**: `FrequencyEvaluator.isDue` carries two different
  questions that the v0.2 roadmap never separated — "should we nudge
  the user?" (scheduler) and "should we show this row?" (view). When
  both read the same predicate, fixes at the engine layer break
  whichever of the two cares about pure quota semantics. View-layer
  helpers are the right place for the UI-only OR.

### Section header "Today" read as redundant with the nav title

- **What happened**: user flagged on walkthrough that "Today" inside
  a view titled "Today" is noise.
- **What we did**: renamed to "Scheduled". "Not scheduled today"
  stays in the second section header — the juxtaposition now reads as
  Scheduled / Not scheduled today rather than Today / Not scheduled
  today.
- **Lesson**: section headers should never echo the navigation title.
  Not generalizable beyond "check for this on future multi-section
  screens."

## What worked well

- **Small commits per logical unit**: nine commits across three
  originally-planned + five walkthrough-scoped changes meant the
  diagnosis of each bug left a clean revert surface. `git log`
  between the branch cut and tip tells a readable story.
- **Walk-through-driven scope expansion**: letting the walkthrough
  feedback expand the PR was the right call here; the fixes were
  co-located in the same files the polish tasks touched, so splitting
  into a second PR would have mostly produced merge conflicts.
- **`Text(verbatim:)` + `accessibilityLabel`**: clean, minimal
  pattern for non-translatable brand art. Reusable for any future JP
  decorative text.
- **Plan doc kept the project-scoped decisions legible**: even after
  scope grew mid-PR, the original plan + this compound together form
  a readable record.

## For the next person

- **Launch screen edits require a storyboard change**, not a project
  setting change. The active splash is `Kado/LaunchScreen.storyboard`
  and it holds its own fallback copy of the paper-50 sRGB values
  inline (line 70, `<namedColor name="LaunchBackground">`). The
  asset catalog's `LaunchBackground.colorset` overrides at runtime,
  but if `kadoPaper50` ever shifts, both need to move together.
- **Icon rasterization goes through `rsvg-convert`**, not `qlmanage`.
  Command shape used for this PR:
  `rsvg-convert -w 1024 -h 1024 -b 'rgba(0,0,0,0)' input.svg -o output.png`.
- **TodayView's "show this row" predicate is
  `isDueTodayOrCompletedToday`**, not just `FrequencyEvaluator.isDue`.
  The two have deliberately diverged. Scheduler and score calculator
  still use `isDue` directly and that's intentional.
- **`Text(verbatim:)` in `Localizable.xcstrings`**: the 稼 働 · in
  operation literal does **not** show up in the string catalog and
  that's correct — `verbatim:` bypasses the `LocalizedStringKey`
  path. Don't add a catalog entry for it; the only translatable piece
  is `"Kadō — in operation"` on the `accessibilityLabel`.
- **`LaunchMark.imageset` is a static PNG** (not a PDF template), so
  it doesn't tint via asset-catalog rendering. Light + dark variants
  are shipped separately.

## Generalizable lessons

- **[→ CLAUDE.md]** `INFOPLIST_KEY_*` build settings are
  typo-tolerant. Any new key you add under `GENERATE_INFOPLIST_FILE`
  must be verified against Apple's reference, or by inspecting the
  generated `Info.plist`; Xcode won't warn. (First bit: real keys
  include `INFOPLIST_KEY_UILaunchStoryboardName`; fake keys include
  `INFOPLIST_KEY_UILaunchScreen_BackgroundColor` and `_Image`.)
- **[→ CLAUDE.md]** `qlmanage -t -s <N>` flattens transparent pixels
  to opaque white. For SVG → PNG with alpha preserved, use
  `rsvg-convert -b 'rgba(0,0,0,0)'` (install via `brew install librsvg`).
- **[→ CLAUDE.md]** When two consumers read the same predicate and
  one fixes a UX bug by weakening it, put the weaker version at the
  caller, not in the engine. `FrequencyEvaluator.isDue` +
  `TodayView.isDueTodayOrCompletedToday` is the canonical split.
- **[→ CLAUDE.md]** Empty states that live behind a "no data yet"
  fork must receive the same background/chrome modifiers as the
  populated branch. Apply the paper surface at the `content` level,
  not inside the `if records.isEmpty { ... } else { List { ... } }`
  else arm only. Also: every primary empty state should include a
  CTA to create the first record.
- **[local]** Section headers shouldn't echo the navigation title.
- **[local]** Tinted app-icon variant deferred to v1.0 — still
  iOS-auto-generated.

## Metrics

- Tasks completed: 3 planned + 5 walkthrough-scoped + 1 rename = 9
- Commits on branch: 9
- Files touched: ~20 (most asset/xcstrings; 3 Swift view files)
- Tests added: 0 (view-layer and asset changes; scheduler + evaluator
  regression tests already in place and remained green)

## References

- PR #17 (the initial re-skin, merged 2026-04-19) —
  `docs/plans/2026-04/paper-sage-reskin/compound.md`
- Apple Info.plist settings reference:
  `Build Settings → Packaging → INFOPLIST_KEY_*`
- `librsvg` (MIT): `brew install librsvg`
