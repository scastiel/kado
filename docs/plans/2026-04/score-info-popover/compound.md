# Compound — Score info popover

**Date**: 2026-04-19
**Status**: complete
**Plan**: [plan.md](./plan.md)
**Branch / PR**: `feature/score-info-popover` — [#19](https://github.com/scastiel/kado/pull/19)

## Summary

Shipped a tappable Score card on the habit detail view that reveals a
plain-English explanation of the EMA-based score. The plan called for
a popover (matching `CellPopoverContent`) but mid-build visual
verification showed the popover adaptation clipping and losing its
backdrop on iPhone once the content exceeded ~3 short lines. Pivoted
to a `.sheet` with `.presentationDetents([.medium])`. Headline lesson:
`.presentationCompactAdaptation(.popover)` is only viable for very
short content on iPhone — reach for a sheet at the first sign of
multiple paragraphs.

## Decisions made

- **Sheet, not popover**: a medium-detent sheet with a drag indicator
  and a nav-bar Done button renders 4 bullets cleanly; the popover
  adaptation did not.
- **Tap the whole Score card**: preserves a single, discoverable
  surface and keeps the `info.circle` hint purely decorative.
- **Streak card stays non-interactive**: "current / best" is
  self-explanatory, no parallel explanation needed.
- **No Weak/Building/Strong ladder**: `docs/habit-score.md` hasn't
  committed to percentile thresholds, so introducing labels would
  anchor the UX prematurely.
- **EN-only catalog entries**: the project's `Localizable.xcstrings`
  has no `fr` locale yet and `knownRegions` lists only `en`/`Base`.
  FR entries will be added under the `translations-catalog` feature.
- **Rename file to match presentation**: `ScoreExplanationPopover`
  → `ScoreExplanationSheet` after the pivot, so the filename
  doesn't lie to future readers.

## Surprises and how we handled them

### Popover clipping on iPhone

- **What happened**: `.presentationCompactAdaptation(.popover)` with
  four paragraph-sized bullets rendered as a speech-bubble-shaped
  popover that clipped the top bullet and the title, with no opaque
  material backdrop — text appeared to float over the monthly
  calendar grid underneath.
- **What we did**: swapped to `.sheet` with a single `.medium` detent
  and a drag indicator. Added a `NavigationStack` + Done button so
  dismissal is obvious at every accessibility size.
- **Lesson**: `CellPopoverContent` works as a popover because it's
  three tight lines. Anything paragraph-sized should start as a
  sheet.

### Catalog is EN-only

- **What happened**: the plan specified EN + FR entries, but
  `Localizable.xcstrings` has no FR locale and the project's
  `knownRegions` lists only `en`/`Base`.
- **What we did**: added EN entries in the existing shape; FR lands
  when the parallel `translations-catalog` plan stands up the FR
  locale.
- **Lesson**: check `knownRegions` + an existing catalog entry before
  promising bilingual strings in a plan.

## What worked well

- **Isolating the view in its own file**: the popover→sheet pivot
  touched only the sheet view and a single modifier in
  `HabitDetailView`. Would have been more invasive if the explanation
  content had been inlined.
- **Extracting `scoreCard` as its own computed property**: kept the
  generic `metricCard` reusable for Streak and localized the button
  wrapping + sheet modifier to one place.
- **Plan-first discipline on a small feature**: the plan was barely
  three tasks, but writing it forced the popover-vs-sheet question
  early. (It still had to be revisited — but caught, not buried.)

## For the next person

- The Score card is now a `Button` with `.buttonStyle(.plain)`; any
  future restyle of the metric cards needs to preserve the tap hit
  area and the `info.circle` hint adjacent to the "Score" label.
- `ScoreExplanationSheet` uses `.presentationDetents([.medium])`
  only — deliberately no `.large`. The content fits comfortably in
  medium at XXXL Dynamic Type. If content grows, add `.large` rather
  than removing medium, so the initial height stays predictable.
- When FR comes online, the six new catalog entries (keyed by their
  English sentence) will need FR translations. Pattern: native French
  phrasing, not machine translation, per `CLAUDE.md`.
- Streak card is intentionally non-interactive. Resist the urge to
  add a parallel explanation sheet — the format ("N / best M") is
  self-documenting.

## Generalizable lessons

- **[→ CLAUDE.md]** `.presentationCompactAdaptation(.popover)` on
  iPhone only renders cleanly for short content (≤3 short lines, as
  in `CellPopoverContent`). For paragraph-sized explanations, use
  `.sheet` with `.presentationDetents([.medium])` and a Done button
  in a `NavigationStack`. The popover adaptation clips and loses its
  backdrop otherwise.
- **[→ CLAUDE.md]** Before promising EN + FR in a plan, confirm the
  project's `knownRegions` and the existing `Localizable.xcstrings`
  actually support FR. Today they don't; strings are currently
  EN-only.
- **[local]** Name the file after what the view *is*, not what the
  plan called it. A post-pivot rename is cheap; a stale filename is
  a small paper-cut for every future reader.

## Metrics

- Tasks completed: 3 of 3 (plus 1 unplanned pivot)
- Tests added: 0 (pure UI affordance)
- Commits on branch: 5
- Files touched: 4 (2 Swift source, 1 catalog, 1 plan doc) + this
  compound doc

## References

- `docs/habit-score.md` — source of the four-bullet distillation.
- `Kado/Views/Overview/CellPopoverContent.swift` — original popover
  pattern we initially copied and then diverged from.
