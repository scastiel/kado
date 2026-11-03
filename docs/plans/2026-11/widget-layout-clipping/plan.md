# Plan — Home widget layout clipping

**Date**: 2026-11-02
**Status**: in progress
**Research**: [research.md](./research.md)
**Issues**: [#151](https://github.com/scastiel/kado/issues/151), [#152](https://github.com/scastiel/kado/issues/152)

## Scope and decisions

The user requested upstream reports and a proposed patch. Affected devices are iPhone 14 / iOS 27.2 and iPad mini 6 / iPadOS 27.2, confirmed from About screenshots. App version, text size and zoom remain unknown; they do not block a bounds-adaptive proposal.

- Use `ViewThatFits(in: .vertical)` to choose natural-height regular/compact presentations, not device-model branches or blanket text-size caps.
- Preserve all picked rows and progress/empty-state semantics in every grid variant.
- If readable rows cannot fit, explicitly direct the user to open Kadō rather than silently dropping picked habits.
- Keep the palette and accentable/background ordering unchanged.
- No persistence, signing, identifiers, dependencies or capability changes.
- No simulator download. Attempt a compile-only unsigned device-SDK build; do not install it. Actual Home Screen verification stays blocked and the PR stays draft.

## Tasks

- [x] File separate medium/weekly reports.
- [x] Add measurable medium layout variants with configurable cell padding and an eager grid.
- [x] Add weekly variants with compact gaps/cells, natural-height weekday labels and matching cell/stripe heights.
- [x] Add localized open-app fallback in both catalogs; flag proposed French copy for maintainer review.
- [x] Add eight-row mixed fixtures and compact-device, dark, large-text and French previews. Previews are not a substitute for WidgetKit verification.
- [x] Run deployment/catalog/static checks and attempt compilation without a runtime. These UI-only changes introduce no business calculations requiring test-first implementation.
- [ ] Upload widget-only screenshot crops, open a draft PR from the contributor fork and notify the maintainer with explicit validation gaps.

## Required maintainer/device validation

- iPhone 14 medium with 0, 1, 2, 7 and 8 habits; five-row small widget unchanged.
- iPad mini 6 weekly with 0, 1 and 5 habits; also larger iPhone/iPad tiles.
- EN/FR, long names, counters/timers, picked not-due rows, Dynamic Type through accessibility sizes.
- Real Home Screen full colour, Clear/Tinted, light/dark and iPad orientation changes.
- Existing selection/progress/empty-state tests and localization coverage.

## Notes during build

- The preview named “Eight habits” currently has only five today rows. Add a separate full-capacity fixture rather than changing every existing preview's pick assumptions.
- The user subsequently authorized screenshot uploads; upload only widget crops, never About screens or unrelated Home Screen content.
- The new French string is explicitly `needs_review` in both catalogs, not presented as native-reviewed copy.
- An unsigned device-SDK build succeeded without a simulator (`xcodebuild build -sdk iphoneos -destination 'generic/platform=iOS' -jobs 1 CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO`). This is compilation only; do not install this unsigned build or claim visual verification. Deployment floor and source-catalog coverage checks also passed.
