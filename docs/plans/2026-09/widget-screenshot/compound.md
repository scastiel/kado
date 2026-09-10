# Compound — Widget screenshot for the App Store listing

**Date**: 2026-09-09
**Status**: complete
**Research**: [research.md](./research.md)
**Plan**: [plan.md](./plan.md)
**Branch / PR**: `feature/widget-screenshot`

## Summary

The listing's third screenshot now shows Kadō's widgets — the three
Home Screen families and the four Lock Screen widgets on a dark card
— assembled from the widgets themselves rather than photographed off
a Home Screen. The widget views moved into `KadoCore` so the app can
draw them; a Debug-only gallery lays them out at true size on the
screenshot seed; XCUITest photographs each tile by element; and the
framing script composes the tiles per canvas. Two things changed
between plan and reality: the gallery's layout was reshaped by the
Dynamic Island, and the tiles ended up photographed once, on the
iPhone, instead of per device. The headline lesson: **when a
screenshot pipeline's "raw" artifact is a tile rather than a screen,
capture it once at the highest scale you have and let the composition
step scale down — never up.**

## Decisions made

- **Assembly over a Home Screen photograph**: a real Home Screen is
  mostly not Kadō (wallpaper, other apps' icons, dock), and XCUITest
  cannot add a widget to one from inside the app.
- **Tiles as the raw capture, composition in the frame**: layout
  iterates with `make frames` in seconds; the alternative (compose in
  SwiftUI, photograph the whole thing) costs a simulator run per
  language per device for every nudge.
- **Widget views move to `KadoCore`, not dual target membership**:
  one compiled copy, `public` API, and it is where "anything
  extensions need to compile" already lives. `KadoMark` goes into a
  package asset catalog (`Image("KadoMark", bundle: .module)`).
- **Strings stay in the two target catalogs**: SwiftUI's `Text("…")`
  resolves against `Bundle.main` even from a package, and the app's
  catalog already carried the widget keys. No package catalog needed.
- **Element screenshots, not `ImageRenderer`**: real screen pixels at
  device scale with the app's fonts, assets and language; no
  offscreen-renderer gaps to discover.
- **Lock widgets rendered `.vibrant` on a dark card**:
  `widgetRenderingMode` is settable (verified in the SDK's
  `swiftinterface`), and `.colorScheme(.dark)` makes the paper/sage
  tokens resolve to their night values — a lock-screen look without
  inventing a palette.
- **Third position**: the results page shows three thumbnails, and
  widgets are a differentiator. `03`–`06` became `04`–`07` with
  `git mv`, verified byte-identical through `make frames`.
- **No new build for 1.9**: nothing here changes what a user sees;
  build 17 stays and the seven screenshots went straight onto the
  version record.

## Surprises and how we handled them

### The Dynamic Island reshaped the gallery

- **What happened**: the first gallery ignored the safe area to fit
  four rows (170/170/170/382 = 924pt) on a 956pt screen. The
  simulator paints the Dynamic Island *over* the app, so the medium
  tile would have been photographed with a black pill in its corner.
  Inside the safe area there are 860pt, and four rows don't fit.
- **What we did**: made the lock card a tall tile (186×230) beside the
  small one, so `170 + 8 + 186` equals the medium's 364 and the
  gallery is 806pt. That 364-wide column is exactly what the phone
  canvas composes — the constraint produced the layout.
- **Lesson**: a screenshot gallery must stay inside the safe area
  even when it "doesn't need to"; and when tiles are captured by
  element, design the gallery as the composition's building blocks,
  not as the composition.

### iPad tiles at 2× would have been upscaled onto the iPad canvas

- **What happened**: the plan captured tiles per device. The iPad's
  came out at 2× (728px medium); its canvas needs ~1650px of them —
  a 1.5× upscale next to pixel-exact device frames.
- **What we did**: tiles moved up to `screenshots/<locale>/03-widgets/`
  and the widgets pass runs on the iPhone only. Both canvases draw the
  3× tiles at 0.94× and 1.03×.
- **Lesson**: when a capture is reused across canvases, take it once
  at the highest scale available and only ever scale down. The
  locale-level folder is the structural expression of that rule.

### The seed's hero doesn't fit the Lock Screen card

- **What happened**: "Morning meditation" truncates to "Morning
  medi…" on the 172pt rectangular widget, exactly as it would for a
  real user. Honest, and the wrong thing to lead a listing with.
- **What we did**: the picked widgets show the first *completed* habit
  whose name is ≤ 14 characters — "Running" / "Course à pied" in both
  languages. The inline line dropped to `.footnote` with a little
  `minimumScaleFactor` for "4 sur 6 faites aujourd'hui".
- **Lesson**: a marketing fixture is chosen for how it reads, and the
  rule for choosing it belongs in code with a comment, not in a
  hand-edit of the seed.

### `snapshot_ui` cannot see accessibility containers

- **What happened**: XcodeBuildMCP's hierarchy dump flattens
  `.accessibilityElement(children: .contain)` containers, so the tile
  identifiers never showed. The plan listed it as a verification.
- **What we did**: trusted the real check — XCUITest's
  `app.otherElements[id]` — which found all four tiles on the first
  run.
- **Lesson**: `snapshot_ui` verifies leaves; for a container
  identifier, the UI test is the only honest probe.

## What worked well

- **Verifying the two load-bearing SDK claims before designing**
  (`widgetRenderingMode` settable, `widgetFamily` not) — two greps of
  the `swiftinterface`, and no mid-build pivot.
- **`--passes widgets`** paid for itself immediately: every iteration
  on the lock card was one short test per language instead of a
  half-hour set, and the six committed screens never churned.
- **The shared `canvas` helper** in the frame script: extracting
  ground + headline into one function meant an assembly and a device
  frame line up in the strip by construction.
- **Looking at the strip, not the shot.** The thumbnail row of
  `01 02 03 04` was the check that mattered; the assembly read as one
  set at first render.

## For the next person

- `WidgetTileMetrics` (in `WidgetGalleryView.swift`) and the `Tile` /
  `Assembly` tables in `Scripts/frame-screenshots.swift` carry the
  **same numbers** — 364×170, 170×170, 364×382, 186×230, a 22pt
  corner. Change one, change both. The gap between tiles is the
  frame's (16pt), not the gallery's (8pt): the gallery only has to
  keep tiles from overlapping in a crop.
- The gallery is `#if DEBUG` and reachable only with
  `-uiTestRun -uiTestWidgetGallery`. It seeds through the same
  idempotent `UITestSupport.seedProductionIfRequested`, so it does not
  race the app's own seed task.
- A tile attachment is `NN-name--part`; `name-screenshots.py --self-test`
  pins the routing. Tiles land under the *locale*, not the device.
- The lock card's picked habit is the first completed one with a name
  ≤ 14 characters. If the seed changes, check what it picks.
- The Home Screen's Tinted and Clear appearances cannot be shown this
  way — they flatten in WidgetKit's render server, not in SwiftUI.
- `make frames` regenerates the site's six raw copies; the site does
  not get the assembly (there is no raw equivalent). Open question,
  carried.

## Generalizable lessons

- **[→ CLAUDE.md]** Already added: the widgets shot is assembled, and
  how. The "tiles once, at 3×, scale down only" rule is in the same
  bullet.
- **[→ CLAUDE.md, candidate]** A screenshot-driving gallery must stay
  inside the safe area: the simulator paints the Dynamic Island over
  the app, so a crop that touches the top edge carries a black pill.
- **[→ CLAUDE.md, candidate]** `snapshot_ui` flattens accessibility
  containers; an identifier on a `.contain` element is only visible to
  XCUITest.
- **[local]** The lock card's `.footnote` inline line and the ≤ 14
  character pick.

## Metrics

- Tasks completed: 7 of 7
- Commits: 10 (research, plan, 7 tasks + plan tick)
- Files touched: 91 (40 of them `git mv` renames)
- Tests added: `testCaptureWidgetTiles` (UI), `name-screenshots.py
  --self-test`; 566 unit tests unchanged and green

## References

- `docs/app-store/README.md` — "The widgets shot is an assembly".
- `WidgetKit.swiftinterface` (iOS 26.5 SDK) — `widgetRenderingMode`
  `{ get set }`, `widgetFamily` `{ get }`.
- HIG, Widgets — sizes per device:
  https://developer.apple.com/design/human-interface-guidelines/widgets#Specifications
