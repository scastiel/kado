# Research — Home widget layout clipping

**Date**: 2026-11-02
**Status**: implementation proposed; runtime validation still required
**Scope**: Investigate the iPhone medium and iPad large widget clipping in the user's screenshots, check upstream reports, and identify storage-conscious validation options. No app changes or builds in this investigation.

## Observed problem

- iPhone: the medium widget's Today header touches/is cut by the top edge; the final habit chip intersects the bottom edge. Long names truncate horizontally, but the vertical overflow is the defect.
- iPad: the weekly widget's heading is mostly above its visible bounds and its fifth habit's cells are cut off below. The screenshot uses Clear appearance; monochrome rendering alone is expected in that mode.
- Screenshots inspected in Downloads: `Screenshot 2026-11-02 at 10.30.39 PM.png` and `Screenshot 2026-11-02 at 10.30.56 PM.png` (actual filenames contain a narrow no-break space before PM).
- Subsequent About screenshots confirm iPhone 14 / iOS 27.2 and iPad mini (6th generation) / iPadOS 27.2. App version, Display Zoom and text size are still unknown. No device serials or other identifiers are reproduced here.

## Upstream findings

Checked the upstream issue and pull-request listings, including closed items, against current upstream main (`21bad65`, also local HEAD). Both listing requests returned fewer items than their requested limits.

- No matching clipping/height-adaptation report or pending layout fix found.
- [PR #73](https://github.com/scastiel/kado/pull/73), merged September 7, fixes invisible text under Clear/Tinted. Relevant history, but not a vertical layout fix. Its description explicitly requires real Home Screen visual verification.
- [Issue #97](https://github.com/scastiel/kado/issues/97) / [PR #101](https://github.com/scastiel/kado/pull/101) fix the widget extension's deployment target. That caused absent widgets, not these clipped widgets.
- [Issue #98](https://github.com/scastiel/kado/issues/98) / [PR #106](https://github.com/scastiel/kado/pull/106) add actual Home Screen selection tests. These are not full-capacity layout assertions.
- [Issue #149](https://github.com/scastiel/kado/issues/149) remains open for completing habits without opening the app; unrelated to clipping.

## Code evidence and likely cause

Paths below are relative to the repository root.

- `Packages/KadoCore/Sources/KadoCore/Widgets/Views/TodayProgressMediumView.swift`: header plus a two-column `LazyVGrid`, up to eight habits/four rows, fixed gaps and a zero-minimum spacer. It does not select a layout based on available height.
- `.../Views/HabitWidgetCell.swift`: scalable caption text plus 5pt vertical padding on each side. Natural row height therefore grows with text size.
- `.../Views/WeeklyGridLargeView.swift`: up to five habit blocks, 10pt inter-block gaps, 4pt inner gaps, 14pt weekday stripe and 22pt cell-stripe frames. It measures width, not available vertical space. Matrix cells can themselves be 26pt tall inside the 22pt stripe, a separate inconsistency to fix.
- `Packages/KadoCore/Sources/KadoCore/Widgets/WidgetHabitSelection.swift`: family-only limits (5/8/5), independent of actual bounds or text size.
- `Kado/Support/WidgetGalleryView.swift`: the marketing gallery uses 364×170pt medium and 364×382pt large tiles, with assumed 16pt margins. It explicitly does not use iPad-native dimensions.
- `KadoUITests/HomeScreenWidgetTests.swift`: selection assertions use two picked habits. They do not assert that full-capacity content stays within the tile; its family detection also assumes iPhone-like widths.

Apple documents different bounds for the same widget family. Examples: medium iPhone 338×158pt versus the gallery's 364×170pt; large iPad device sizes as small as 260×260pt, with others at 272, 288 or 300pt square. The current five-block weekly layout needs roughly 300pt before outer content margins at ordinary text sizes. Enlarged text further increases demand.

**Assessment**: strong source-level evidence for content exceeding the vertical budget on smaller widget bounds, consistent with both screenshots. Not yet reproduced in a running development build; the exact role of device settings is unconfirmed. Merely adding a clip or disabling margins would mask rather than solve it.

## Recommended fix direction

1. Fit the medium grid and weekly blocks to the actual content proposal. Prefer measured SwiftUI layout / `ViewThatFits` variants over device-model branches.
2. Compress padding, spacing and matrix-cell height where necessary; ensure the stripe's layout height matches its rendered cells. Protect the header and readable habit labels.
3. Keep the advertised capacity where a readable compact layout permits. At very large accessibility sizes, agree on an explicit fallback instead of silently hiding picked habits or shrinking text without bounds.
4. Preserve the existing `WidgetPalette` and accentable/background modifier ordering. Clear/Tinted rendering is a separate concern with prior regressions.
5. Add full-capacity fixtures at compact iPhone and iPad sizes, long EN/FR names, mixed binary/counter/timer and not-due rows, and larger text. Validate selection order, summaries and empty states if visible capacity changes.
6. Verify actual Home Screen widgets in full colour and Clear/Tinted. In-app gallery captures or green unit tests alone cannot establish WidgetKit rendering correctness.

No persistence, CloudKit schema or habit-data changes should be needed.

## Low-storage testing options

Measured available disk space: **23 GiB** on the Data volume. Xcode is selected, with iOS/device and simulator SDKs listed as 27.2, but `simctl list runtimes` returns no installed runtimes. SDK availability is not runtime availability. The tooling check automatically initialized Xcode's bundled simulator tooling; no simulator runtime was deliberately downloaded, and no build ran.

- **Physical iPhone/iPad**: avoids the simulator OS download, though build outputs and device support still consume space. Requires compatible Xcode/device OS, Developer Mode and provisioning. This checkout uses the upstream developer's team, bundle IDs, iCloud container and App Group; a contributor needs their own correctly configured identifiers/capabilities, not just their Apple Account selected. Use a separate app identity and back up/export real habits before any installation experiments.
- **Free Apple Account caveat**: simple on-device apps are possible, but this project's CloudKit/push/App Group entitlements are not a drop-in Personal Team build. A separately scoped local-only UI harness could test layout with fixtures; it would not validate the complete widget/data path. Do not promise that changing the signing team alone works.
- **Maintainer TestFlight build**: propose the patch upstream and ask for a signed test build. No simulator or personal paid membership needed for the tester; maintainer cooperation required. Export data first, especially when testing a replacement build of the real app.
- **Single simulator runtime**: one compatible iOS runtime can serve both iPhone and iPad simulated devices. Prefer Apple-silicon-only over Universal on this Mac; download/install needs several GB plus installation headroom and device/build data. Check Xcode Components' actual size before deciding; 23 GiB is not a guarantee of a comfortable install. Avoid parallel test clones. iOS previews also generally need an appropriate runtime.
- **Remote macOS CI**: compile/test on a hosted Mac and retain screenshots/results, avoiding local simulator storage. This repository currently has only a Pages workflow, so this would be new setup. CI simulator products cannot simply be installed on a physical iPhone; device installs still need signing.

Immediate workaround worth trying without a development build: choose fewer habits in Edit Widget (e.g. no more than six on medium, three/four on weekly). This should reduce height demand but is unverified and not the permanent fix. If larger text or zoom is enabled, temporarily comparing default settings may help isolate the trigger; don't require changing accessibility preferences as the solution.

## Open questions

- [x] Models/OS: iPhone 14 / iOS 27.2, iPad mini 6 / iPadOS 27.2.
- [ ] Installed Kadō version?
- [ ] Any nondefault text size, Display Zoom or relevant Home Screen settings?
- [ ] Access to a paid Apple Developer team, or preference for maintainer TestFlight / remote simulator validation?
- [ ] At accessibility sizes where every picked habit cannot fit readably, what explicit compact/fallback presentation is acceptable?

## Implementation handoff

- Reports: [#151](https://github.com/scastiel/kado/issues/151), [#152](https://github.com/scastiel/kado/issues/152).
- The user requested a proposed fix and maintainer notification, and authorized uploading widget screenshots. Only widget crops are published; About screenshots and unrelated Home Screen content stay private.
- The proposal keeps all rows in measured regular/compact variants and falls back to an explicit open-app hint if those cannot fit at the selected text size. See [plan.md](./plan.md) for verification requirements and build results.

## References

- [Apple HIG: Widgets — dimensions and appearances](https://developer.apple.com/design/human-interface-guidelines/widgets)
- [Apple: Downloading and installing additional Xcode components](https://developer.apple.com/documentation/xcode/downloading-and-installing-additional-xcode-components)
- [Apple: Developer account overview and Personal Team limits](https://developer.apple.com/help/account/basics/about-your-developer-account)
- [Apple: Supported capabilities (iOS), by membership](https://developer.apple.com/help/account/reference/supported-capabilities-ios)
- [Apple: Configuring app groups](https://developer.apple.com/documentation/xcode/configuring-app-groups)
