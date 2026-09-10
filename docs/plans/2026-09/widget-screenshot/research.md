# Research — Widget screenshot for the App Store listing

**Date**: 2026-09-09
**Status**: draft
**Related**: `docs/app-store/README.md`, `docs/plans/2026-04/widgets/`,
`docs/plans/2026-09/daily-completion-reward/` (the Daily Progress lock
ring), #69 (the screenshot pipeline)

## Problem

The listing has six screenshots and none of them shows a widget. Kadō
ships seven — three on the Home Screen, four on the Lock Screen — and
the last two releases were largely about them (#73, #76, and 1.9's
Daily Progress ring). A reader deciding between habit trackers on the
results page never learns they exist.

A widget shot should **not** be a photograph of a Home Screen. A real
one carries a wallpaper, a page of other apps' icons, a dock, and a
status bar, none of which is Kadō's, and adding widgets to the
simulator's Home Screen through XCUITest is the most fragile thing the
suite could do. What the shot needs is an **assembly**: the widgets
themselves, rendered at their true size, arranged on the listing's own
paper ground under a headline, the way the other six frames are drawn.

"Done" is a seventh framed image in every locale and device folder
under `docs/app-store/marketing/`, produced by `make screenshots` like
the others, restyled by `make frames` like the others, and uploaded by
`make listing` without special handling.

## Current state of the codebase

### The pipeline

- `Scripts/screenshots.sh` boots a simulator per device, pins language,
  appearance and status bar, runs one `ScreenshotTests` method per
  appearance pass, exports the attachments, and hands them to
  `Scripts/name-screenshots.py`, which names each file after its
  attachment and **hard-fails any PNG that isn't the device canvas**
  (1320×2868 / 2064×2752).
- `Scripts/frame-screenshots.swift` (AppKit) walks
  `screenshots/<locale>/<device>/*.png`, and for each draws the
  paper→sage gradient, the Fraunces headline from `captions.json`, and
  the capture inside a device bezel. The device is the only layout it
  knows. `_darkFrames` picks the dark palette per shot.
- `Scripts/site-screenshots.sh` downsizes the *raw* iPhone captures for
  getkado.app. It globs `*.png` in the device folder.
- `KadoUITests/ScreenshotTests.swift` launches the app with
  `-uiTestRun -uiTestSeedForScreenshots` (`ScreenshotSeed`'s four months
  of authored history, in the run's language) and photographs whole
  screens with `app.screenshot()`.

### The widgets

- Every widget view lives in the **extension target only**
  (`KadoWidgets/`, a synchronized folder whose one member is
  `KadoWidgetsExtension`). Each family has its own view type
  (`TodayGridSmallView`, `TodayProgressMediumView`,
  `WeeklyGridLargeView`, `LockCircularView`, `LockRectangularView`,
  `LockInlineView`, `LockDayProgressView`) plus `HabitWidgetCell`,
  `WidgetMetricsChip` and `TodayEmptyPlaceholder`. ~700 lines of
  view code; the `Widget` configurations and `#Preview`s are the rest.
- Everything they *read* is already in `KadoCore`: `WidgetSnapshot`,
  `SnapshotEntry`, `PickedSnapshotEntry`, `WidgetPalette`,
  `WidgetSnapshotBuilder.build(from:)` (which produces a snapshot from
  any `ModelContext` — no App Group file needed).
- Views read `@Environment(\.widgetRenderingMode)` and route colours
  through `WidgetPalette`. **None reads `\.widgetFamily`.**
- The container background (`Color.kadoBackgroundSecondary`, or
  `.clear` for lock widgets) is applied in the `Widget` configuration,
  not in the view. Outside WidgetKit `.widgetAccentable()` and
  `.widgetURL` are no-ops.
- `LockDayProgressView` draws `Image("KadoMark")`, an asset that exists
  only in `KadoWidgets/Assets.xcassets`.
- Strings: the app's `Localizable.xcstrings` already carries 28 of the
  widget catalog's 30 keys (the two missing are the Daily Progress
  widget's configuration name and description, which stay in the
  extension). SwiftUI's `Text("…")` resolves against `Bundle.main`
  even from a package, so a view compiled into the app finds its
  strings in the app catalog.

### Verified against the SDK (`WidgetKit.swiftinterface`, iOS 26.5)

- `EnvironmentValues.widgetRenderingMode` is `{ get set }` — the app
  can render a lock-screen view in `.vibrant`.
- `EnvironmentValues.widgetFamily` is `{ get }` only. Irrelevant here
  because no view branches on it, but it rules out a single "render
  family X" entry point.
- `Gauge` accessory styles are available to apps since iOS 16, so
  `LockDayProgressView`'s `.accessoryCircularCapacity` draws in-app.
  Worth a smoke test on the first build rather than an assumption.

## Proposed approach

Capture **tiles**, compose in the **frame**. The app grows a
Debug-only gallery screen that lays out every widget view at its real
Home Screen / Lock Screen size on the seeded data; the UI test
photographs each tile by element; the framing script arranges the
tiles on the paper ground under the headline. The raw tree keeps the
tiles as the source of truth, so the layout is a `make frames`
iteration (seconds), not a simulator run (minutes) — the same reason
the frame is a second pass today.

### Key components

- **`KadoCore/Widgets/Views/`** — the seven widget views plus
  `HabitWidgetCell`, `WidgetMetricsChip`, `TodayEmptyPlaceholder` move
  here and become `public`. The `Widget` configurations, the bundle,
  `PreviewSnapshots` and the `#Preview`s stay in `KadoWidgets/`. This
  is the one structural change: the app needs to *compile* the views,
  and `KadoCore` is where "anything extensions need to compile" already
  lives. Moving `KadoMark` into a `KadoCore` asset catalog
  (`Image("KadoMark", bundle: .module)`) comes with it, so the app and
  the extension draw the same file.
- **`Kado/Support/WidgetGalleryView.swift`** (`#if DEBUG`) — shown
  instead of `ContentView` when launched with `-uiTestWidgetGallery`.
  Builds a `WidgetSnapshot` with `WidgetSnapshotBuilder.build(from:)`
  on the seeded context, then lays out:
  - the medium, small and large views at iPhone point sizes (364×170,
    170×170, 364×382) on a `RoundedRectangle(cornerRadius: 22,
    style: .continuous)` of `Color.kadoBackgroundSecondary` — the
    container background the `Widget` would have supplied;
  - a "lock card": a dark rounded tile carrying the inline widget, the
    Daily Progress ring, the per-habit ring and the rectangular widget,
    under `.environment(\.widgetRenderingMode, .vibrant)` and
    `.colorScheme(.dark)`, so they read as they do on a Lock Screen
    rather than in full colour;
  - one accessibility identifier per tile
    (`AccessibilityID.Screenshot.widgetMedium` …), on the tile as a
    leaf.
  Status bar hidden; the tiles only have to fit the screen, not look
  composed — the composition is the script's job.
- **`ScreenshotTests.testCaptureWidgetTiles`** — launches with the
  gallery flag, waits for the medium tile, and adds
  `app.otherElements[id].screenshot()` per tile as attachments named
  `07-widgets--medium`, `07-widgets--small`, `07-widgets--large`,
  `07-widgets--lock`. Element screenshots are real screen pixels at
  the device scale, with the app's fonts, assets and language — none
  of `ImageRenderer`'s gaps.
- **`Scripts/screenshots.sh`** — a third pass, `widgets`, in the light
  appearance, alongside `light` and `dark`.
- **`Scripts/name-screenshots.py`** — an attachment named
  `NN-name--part` lands at `NN-name/part.png` and skips the canvas
  size check; everything else is unchanged.
- **`Scripts/frame-screenshots.swift`** — a device folder entry that is
  a *directory* is an assembly: read its tiles, lay them out per
  profile (medium across the top, small beside the lock card, large
  below; tile widths in points × the profile's scale; corners clipped
  at the same 22pt radius; the bezel shadow reused), then the headline
  as usual. The captions key is the directory name, `07-widgets`.
  Layout numbers live in `Profile`, next to the device's.
- **`captions.json`** — `07-widgets` in both locales.
- **`Scripts/site-screenshots.sh`** — the `*.png` glob already skips
  the directory, so the site set stays at six until someone decides
  what it should show (see open questions).

### Data model changes

None.

### UI changes

None visible to users. The gallery is `#if DEBUG` and reachable only
by launch argument, like `ScreenshotSeed`.

### Tests to write

- `@Test("name-screenshots routes NN-name--part into a folder and
  skips the size check")` — pure Python; a unit-style check inline in
  the script's `__main__` or a small `pytest`-free assertion block, in
  keeping with "no dependencies".
- `ScreenshotTests.testCaptureWidgetTiles` asserts the gallery arrived
  before photographing (as the others do).
- The moved views: no new tests — `WidgetPaletteTests` and the
  snapshot-builder suite already cover what they draw from. The
  extension's `#Preview`s keep working through the `Widget`s.

## Alternatives considered

### Alternative A: one full-canvas assembly rendered in-app

- Idea: the gallery *is* the composition — draws the ground and the
  arrangement itself, at screen size, and the test takes one
  `app.screenshot()`. The frame script gets a "flat" mode that draws
  only the headline over it.
- Why not: every layout tweak is a simulator run per language per
  device, and the gradient would be drawn twice (SwiftUI and AppKit)
  and has to match to the pixel. It also fixes the composition to the
  screen's aspect, which is not the canvas's on iPad. Cheaper to build
  by a day; costlier every time it is touched.

### Alternative B: `ImageRenderer` in a unit test

- Idea: render each view offscreen at 3× from `KadoTests`, no gallery,
  no UI test.
- Why not: `ImageRenderer` skips materials and some system-drawn
  controls, the test bundle has neither the app's string catalog nor
  its assets, and the result would need to be pulled out of an
  `xcresult` anyway. Element screenshots give real pixels for the same
  plumbing.

### Alternative C: photograph the real Home Screen and Lock Screen

- Idea: drive SpringBoard through XCUITest, add the widgets, capture.
- Why not: the most fragile automation available (jiggle mode, the
  widget gallery's search, per-iOS-version layouts), and the picture
  would be a Home Screen, which is exactly what the shot should not be.

### Alternative D: compile the view files into the app by dual membership

- Idea: keep the files in `KadoWidgets/` and add the app target as a
  second member through a synchronized-folder exception set.
- Why not: hand-edited `project.pbxproj`, two compiled copies of every
  view, and the precedent the SwiftData note in `CLAUDE.md` exists to
  discourage. `KadoCore` is the sanctioned place for shared code.

## Risks and unknowns

- **Lock-screen views outside WidgetKit.** `.vibrant` can be set, but
  the system draws the Lock Screen's translucent backing and the
  `Gauge` track itself; in-app the tile may need a hand-drawn backing
  to read right. Smoke-test in the first build.
- **Widget point sizes** are Apple's, per device class, and not
  exposed by API. 364×170 / 170×170 / 364×382 are the documented
  values for the 6.9″ class; the iPad canvas uses the same tiles
  scaled by the profile rather than iPad-native sizes — it is a
  marketing image, not a ruler.
- **Corner radius.** The Home Screen container shape is a continuous
  ~22pt corner on iPhone. Off by a few points it reads as drawn rather
  than photographed, like the bezel note in the frame script says.
- **Moving the views** touches every widget file. Mechanical, but the
  extension's `#Preview`s and `PreviewSnapshots` must still compile,
  and `LocalizationCoverageTests` walks both catalogs — adding a
  string to a moved view means adding it to both, as today.
- **Sixth-vs-seventh position.** App Store Connect orders by file
  name; putting the shot earlier means renaming the others, which the
  pipeline tolerates (`git mv` + `captions.json`) but is a separate
  decision.

## Open questions

- [ ] Position in the set: last (`07`), or earlier — widgets are a
      differentiator and the first three thumbnails are what the
      results page shows.
- [ ] Which widgets: all three Home Screen families plus the lock
      card, or a tighter pick (medium + large + lock).
- [ ] Headline copy, both locales. Draft: EN "Your habits,\non every
      screen" / FR "Tes habitudes,\nsur tous tes écrans".
- [ ] Whether getkado.app gets the assembly (it shows raw captures
      today, and there is no raw equivalent of a composed frame).
- [ ] Ship with 1.9 — the version is in Prepare for Submission, so a
      `make listing` before submitting puts it on this release.

## References

- HIG, Widgets — sizes per device:
  https://developer.apple.com/design/human-interface-guidelines/widgets#Specifications
- WidgetKit `widgetRenderingMode`:
  https://developer.apple.com/documentation/widgetkit/widgetrenderingmode
- `docs/app-store/README.md` — the pipeline this extends.
- `Scripts/frame-screenshots.swift` — where the composition will live.
