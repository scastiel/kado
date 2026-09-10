# Plan — Widget screenshot for the App Store listing

**Date**: 2026-09-09
**Status**: done
**Research**: [research.md](./research.md)

## Summary

A seventh App Store screenshot that shows Kadō's widgets, assembled
from the widgets themselves rather than photographed off a Home Screen.
The widget views move into `KadoCore` so the app can render them; a
Debug-only gallery lays them out at true size on the screenshot seed;
the UI test photographs each tile by element; and the framing script
composes the tiles on the paper ground under a headline, the way it
frames the other six. The shot goes **third**, so it is one of the
thumbnails the results page shows.

## Decisions locked in

- Position `03-widgets`; `03`–`06` become `04`–`07`.
- All three Home Screen widgets plus a lock card carrying the four
  Lock Screen widgets, rendered in `.vibrant` on a dark tile.
- Headline: EN `Your habits,\non every screen`; FR
  `Tes habitudes,\nsur tous tes écrans`.
- Tiles are the raw captures; the composition is the frame's job, so
  layout iterates with `make frames`.
- The views move to `KadoCore/Widgets/Views/`, not to a dual-membership
  folder. `KadoMark` moves with them into a `KadoCore` asset catalog.
- No new build for 1.9: nothing in this plan changes what a user sees,
  and screenshots are listing assets, not binary. Build 17 stays.
- The marketing site keeps its six raw captures; whether it gets the
  assembly is a separate decision.

## Task list

### Task 1: Renumber the set to make room ✅

**Goal**: `03` is free, and every reference to the old numbers moves
with the files, so `make frames` regenerates an identical set under
the new names before any new code lands.

**Changes**:
- `KadoUITests/ScreenshotTests.swift` — attachment names `03-overview`
  → `04-overview`, `04-new-habit` → `05-new-habit`, `05-settings` →
  `06-settings`, `06-today-dark` → `07-today-dark`; the doc comment.
- `docs/app-store/captions.json` — keys and `_darkFrames`.
- `git mv` under `docs/app-store/screenshots/`,
  `docs/app-store/marketing/` (both locales × both devices) and
  `docs/screenshots/iphone-67-appstore/{en,fr}/`.
- `README.md`, `site/index.html`, `site/fr/index.html` — the `<img>`
  names.
- `docs/app-store-connect.md` — the numbered shot list.
- `docs/app-store/README.md`, `Scripts/screenshots.sh` — "01–05 / 06"
  wording.

**Tests / verification**:
- `make frames` then `git status` shows no pixel change — the framed
  files under their new names are byte-identical to the moved ones.
- `make listing-check` passes with 6 screenshots per set.

**Commit message (suggested)**:
`chore(app-store): renumber the screenshot set to make room for a widgets shot`

---

### Task 2: Move the widget views into KadoCore ✅

**Goal**: the app target can compile every widget view; the extension
keeps only its `Widget` configurations, bundle and previews.

**Changes**:
- New `Packages/KadoCore/Sources/KadoCore/Widgets/Views/` holding
  `TodayGridSmallView`, `TodayProgressMediumView`,
  `WeeklyGridLargeView` (with its private row/cell helpers),
  `LockCircularView`, `LockRectangularView`, `LockInlineView`,
  `LockDayProgressView`, `HabitWidgetCell`, `WidgetMetricsChip`,
  `TodayEmptyPlaceholder` — each `public` with a `public init`.
- `KadoWidgets/*.swift` shrink to the `Widget` struct and `#Preview`s.
- `KadoMark` → `Packages/KadoCore/Sources/KadoCore/Resources/Media.xcassets/`,
  referenced as `Image("KadoMark", bundle: .module)`; removed from
  `KadoWidgets/Assets.xcassets`.
- Strings stay where they are: `Text("…")` resolves in `Bundle.main`
  from a package too, and both catalogs already carry the keys.

**Tests / verification**:
- `build_sim` — app and extension both compile, no new warnings.
- `test_sim` — the unit suite, including `LocalizationCoverageTests`
  and `WidgetPaletteTests`, unchanged.
- Open one widget `#Preview` in Xcode, or trust the build: the previews
  reference the views through the `Widget`, so a broken move fails to
  compile rather than to render.
- Install on the simulator and add the Daily Progress lock widget once
  — the mark must still draw from its new bundle.

**Commit message (suggested)**:
`refactor(widget): move the widget views into KadoCore`

---

### Task 3: A Debug-only widget gallery ✅

**Goal**: launched with `-uiTestWidgetGallery`, the app shows every
widget at its Home Screen / Lock Screen size on the screenshot seed,
each tile addressable by identifier.

**Changes**:
- `Kado/Support/UITestSupport.swift` — `Argument.widgetGallery`,
  `showsWidgetGallery` (with the release stand-in returning `false`,
  like `suppressesNameAutoFocus`).
- `Kado/Support/WidgetGalleryView.swift` (`#if DEBUG`) — state enum
  `loading` / `loaded(WidgetSnapshot)`; on appear, seeds through
  `UITestSupport.seedProductionIfRequested` (idempotent) and builds
  with `WidgetSnapshotBuilder.build(from:)`; then a `VStack` of:
  - medium (364×170), small (170×170) beside the lock card, large
    (364×382), each on `RoundedRectangle(cornerRadius: 22,
    style: .continuous)` filled `Color.kadoBackgroundSecondary`;
  - the lock card (364×170, dark rounded tile): inline on top,
    Daily Progress ring, per-habit ring (first seeded habit) and the
    rectangular widget below, under
    `.environment(\.widgetRenderingMode, .vibrant)` and
    `.environment(\.colorScheme, .dark)`; accessory frames 76×76 and
    172×76.
  - `.statusBarHidden()`, paper ground, no chrome.
- `Kado/App/KadoApp.swift` — root shows `WidgetGalleryView` instead of
  `ContentView` when the flag is set, inside the same modifiers.
- `Shared/AccessibilityID.swift` — `enum Screenshot` with
  `widgetSmall`, `widgetMedium`, `widgetLarge`, `lockCard`, applied to
  each tile as a leaf (`.accessibilityElement(children: .contain)` is
  fine; the identifier must sit on the tile, not on a container of
  tiles).
- `#Preview` for the gallery on `PreviewSnapshots`-like data, light
  and dark.

**Tests / verification**:
- `build_run_sim` with `-uiTestRun -uiTestResetState
  -uiTestSeedProduction -uiTestSeedForScreenshots -uiTestWidgetGallery`
  and `screenshot`: five tiles visible, seeded habit names, lock
  widgets monochrome. Check the `Gauge` capacity ring draws in-app and
  that the vibrant palette reads on the dark card — the two risks the
  research flagged.
- `snapshot_ui` shows the four identifiers.
- Both simulators: iPhone 17 Pro Max and iPad Pro 13" (the tiles only
  need to fit; the composition is not judged here).

**Commit message (suggested)**:
`feat(screenshots): add a Debug-only widget gallery for the listing`

---

### Task 4: Photograph the tiles ✅

**Goal**: `make screenshots` writes
`screenshots/<locale>/<device>/03-widgets/{medium,small,large,lock}.png`
beside the six captures, and a partial run can refresh only them.

**Changes**:
- `KadoUITests/KadoUITestCase.swift` — `launchApp(widgetGallery:)`.
- `KadoUITests/ScreenshotTests.swift` — `testCaptureWidgetTiles`:
  launch with the gallery flag, `assertReached` the medium tile, then
  one `XCTAttachment(screenshot: element.screenshot())` per tile,
  named `03-widgets--medium` etc.
- `Scripts/name-screenshots.py` — a name of the form `NN-name--part`
  lands at `NN-name/part.png` and skips the canvas check. A self-check
  of the routing at the bottom of the file, run when invoked with
  `--self-test`, so the rule has a test without a test framework.
- `Scripts/screenshots.sh` — passes become a list (`light`, `dark`,
  `widgets`), each with its test case and appearance; `--passes`
  selects a subset, and a subset run does **not** `rm -rf` the
  destination, so refreshing the tiles keeps the six captures.

**Tests / verification**:
- `python3 Scripts/name-screenshots.py --self-test`.
- `Scripts/screenshots.sh --languages en --devices iphone-6.9 --passes
  widgets --no-site` writes four tiles into the existing `en-CA`
  folder and touches nothing else; the tiles are the device scale
  (3× → medium 1092×510).
- Then the full run for both languages and devices.

**Commit message (suggested)**:
`feat(screenshots): photograph the widget tiles`

---

### Task 5: Compose the assembly in the frame ✅

**Goal**: `make frames` turns `03-widgets/` into a framed
`03-widgets.png` on every canvas, under the headline, in the set's
own idiom.

**Changes**:
- `Scripts/frame-screenshots.swift`:
  - the tree walk treats a directory among the shots as an assembly
    keyed by its name;
  - `Profile` gains an `assembly` layout: a point-to-pixel scale
    (chosen so the medium tile spans about the device's screen width
    fraction), the corner radius in points (22), the gap, and the
    arrangement — medium across the top, small beside the lock card,
    large below, centred, starting at the same `screenTop` a device
    would;
  - each tile is drawn clipped to its rounded rect over the bezel
    shadow the device already uses (a little softer: these are tiles,
    not a phone);
  - a missing tile fails the run, like a missing caption does.
- `docs/app-store/captions.json` — `03-widgets` in both locales.

**Tests / verification**:
- `make frames`, then look at `marketing/en-CA/iphone-6.9/03-widgets.png`
  and the iPad one, and the French pair for the headline's fit.
  Iterate on the numbers here; this is where the shot is designed.
- `make listing-check` — 7 screenshots per set, all at the canvas.
- Side-by-side with `01` and `02` at thumbnail size: the strip has to
  read as one set.

**Commit message (suggested)**:
`feat(app-store): compose the widget tiles into the third frame`

---

### Task 6: Documentation ✅

**Goal**: the pipeline's own docs describe assemblies, and the
"widgets are not captured" note is retired.

**Changes**:
- `docs/app-store/README.md` — the three passes, `--passes`, "Adding
  a shot" gains an "or an assembly" paragraph, the tile naming rule.
- `docs/app-store-connect.md` — the shot list, and the paragraph that
  says widgets can't be photographed.
- `CLAUDE.md` App Store section — one line on assemblies if the rule
  is not obvious from the README.

**Commit message (suggested)**:
`docs(app-store): describe the widget assembly`

---

### Task 7: Ship it to 1.9 ✅

**Goal**: the seven framed screenshots replace the six on the 1.9
version record.

**Changes**: none in the repo.

**Tests / verification**:
- `python3 Scripts/appstore.py screenshots --dry-run` lists 7 uploads
  and 6 deletions per set.
- `make listing ARGS=…` or `appstore.py screenshots --yes`, then check
  the order in App Store Connect.

## Risks and mitigation

- **Lock widgets don't read right in-app** (no system backing, `Gauge`
  track colour). Mitigation: the card draws its own translucent
  backing per widget (`Circle().fill(.white.opacity(0.12))`), which is
  what the system does; if `.vibrant` still looks wrong, fall back to
  `.fullColor` with `.colorScheme(.dark)` and note it in compound.
- **Element screenshots include neighbours** if tiles overlap or a
  shadow spills. Mitigation: the gallery draws no shadows and spaces
  tiles by 16pt; the script adds shadows.
- **Renumbering breaks a link** somewhere not grepped. Mitigation:
  Task 1's grep list is in the plan; `site/` builds from
  `docs/screenshots/`, and a broken `<img>` is visible on the next
  Pages deploy.
- **The move changes a widget's rendering** (a `private` becoming
  `public`, a `Bundle.main` string that used to be found). Mitigation:
  `build_sim` + adding each widget on the simulator once after Task 2.

## Notes during build

- **Task 3**: the first gallery ignored the safe area to fit four
  170/170/170/382 rows in 956pt — and the simulator paints the Dynamic
  Island *over* the app, so the medium tile would have been
  photographed with a black pill in its corner. Staying inside the
  safe area left 860pt, which four rows don't fit. Fix was a layout
  change, not a smaller gallery: the lock card became a tall tile
  (186×230) beside the small one, so `170 + 8 + 186` lines up with the
  medium's 364 and the gallery is 806pt. That column is also what the
  phone canvas composes, so the constraint improved the frame.
- **Task 3**: the seed's hero, "Morning meditation", truncates on the
  172pt rectangular Lock Screen card exactly as it would for real.
  The picked widgets now show the first *completed* habit whose name
  fits (≤ 14 characters) — "Running" / "Course à pied" in both
  languages. `.footnote` for the inline line, with `minimumScaleFactor
  0.75`, was needed for "4 sur 6 faites aujourd'hui".
- **Task 3**: XcodeBuildMCP's `snapshot_ui` flattens accessibility
  containers, so it never shows the tile identifiers. The real check
  was XCUITest's `app.otherElements[id]` in Task 4, which found all
  four on the first run.
- **Task 4 → 5**: the iPad's own tiles came out at 2× (728px for the
  medium) and the iPad canvas needs ~1650px of them. Rather than
  upscale 1.5× beside pixel-exact device frames, the tiles moved up to
  `screenshots/<locale>/03-widgets/` and are photographed **once, on
  the iPhone, at 3×**; both canvases compose from those at 0.94× and
  1.03×. The plan had assumed per-device tiles.
- **Task 4**: the six existing screens were *not* re-photographed —
  `--passes widgets` was used for all four combinations, which
  exercised the subset mode and kept the committed captures (taken
  Sep 5) rather than churning them for a four-day-newer calendar.
- **Task 5**: `.accessibilityElement(children: .contain)` +
  `.accessibilityIdentifier` on the tile is the right shape:
  `XCUIElement.screenshot()` crops to it at device scale, corners
  included, and the frame re-clips at 22pt × scale.
- **Task 5**: the iPad arrangement right-aligns the 170pt small tile
  with the 186pt lock card so the silhouette is a rectangle; the
  16pt gap between tiles is about the Home Screen's own.

## Open questions

- [ ] Should getkado.app show the assembly (it would need the framed
      image, not a raw capture, on its strip)? Carried forward — the
      site keeps its six raw captures.
- [x] Uploaded to 1.9 as soon as the frame landed: seven per set, in
      both locales, replacing the six.

## Out of scope

- iPad-native widget sizes; the iPad canvas uses the same tiles at the
  profile's scale.
- Photographing widgets on a real Home Screen.
- A new build. Build 17 ships 1.9.
- The tinted / clear Home Screen appearances — those render in
  WidgetKit's render server and cannot be reproduced in-app.
