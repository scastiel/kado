# Research — App Store creative assets

**Date**: 2026-10-11
**Status**: ready for plan
**Related**: [Asset best practices](https://developer.apple.com/app-store/asset-best-practices/), `docs/app-store/README.md`, `Scripts/appstore.py`, `Scripts/frame-screenshots.swift`

## Problem

On 2026-10-05 Apple turned on **creative assets** for iOS 27 / iPadOS 27 App Store clients. There are two new optional placements, each a still image or a looping muted video:

- **Product page header**: a wide banner at the top of the product page.
- **Search results asset**: replaces the screenshot strip in search results. Without one, search shows In-App Events, app previews, or the **first three screenshots** (orientation decides how many).

Both are set **per localization** and are reviewed. They can also be approved **standalone** through the new Asset Library, with no new app version.

Kadō has neither. On iOS 27 its product page opens without a header, and search shows screenshots 01–03 as before. That isn't broken, but other listings now open on a branded banner and ours doesn't.

Apple shipped a second change alongside it that affects us more: the **App Asset Library API**. It **deprecates** the `appScreenshotSets` / `appScreenshots` resources that `make listing` uses to upload screenshots. They still work today, so nothing is on fire, but the pipeline is now built on a deprecated surface.

## What Apple asks for (verified against the live account)

These facts come from a read-only probe of `GET /v1/appAssetLibraryRefData` with Kadō's App Manager key, not just from the docs. Where the docs and the live data disagree, the live data wins.

| Placement | Image | Video |
|---|---|---|
| Product page header | 21:9 **3840×1646 PNG** (the help page also says JPEG; the live spec says PNG only) | 21:9 3840×1646, 30/60 fps, **10–30 s** (the docs say 5 s minimum) |
| Search results | 3:2, 1920×1280 → 3840×2560, PNG/JPEG | 3:2, same range, 30/60 fps, 5–30 s |
| **Universal** (both) | 16:9 **5244×2950 PNG**, `universalAsset: true` | none |

- No alpha channel in any image. Videos loop and start muted: search results can't unmute, the product page can.
- Limit: **1 per placement**, on `APP_STORE_VERSIONS`, `CUSTOM_PRODUCT_PAGES` and `PRODUCT_PAGE_OPTIMIZATIONS` alike. The placement group is `DEFAULT_PROFILE` (platform `ANY`). One asset covers iPhone and iPad.
- The asset category is `CREATIVE_ASSETS`, fixed when the asset is reserved. Screenshots are `APP_SCREENSHOTS_AND_PREVIEWS` and can't be reused here.
- Kadō's asset library exists: `GET /v1/apps/6762570244/assetLibrary` → library `6762570244`. The App Manager key `3NJ328MR4F` can read it. Writing needs the same role, so no new key is required.

Apple's design guidance that applies to us:

- **Header**: "a single, clear idea", written for a first-time visitor. No dense collage.
- **Search**: "state the obvious" and "showcase the firsthand experience", meaning real UI.
- **Legibility**: the asset gets cropped differently across surfaces, so keep the focal point centred inside a safe area. Check it with the product page **Preview** tool in App Store Connect. The API has no preview.
- **Text**: "a short phrase that enhances your visual rather than describes it", localized.
- **Avoid**: prices, URLs, ©, awards, Apple accolades, other platforms' logos. Content must suit a 4+ rating.

## Current state of the codebase

- `Scripts/screenshots.sh` + `KadoUITests/ScreenshotTests` capture the raw shots. `Scripts/frame-screenshots.swift` (AppKit, no dependencies) wraps them in the paper/sage frame with a Fraunces headline from `captions.json`. It already **composes assemblies**: `03-widgets` is laid out from tiles, not photographed. Its layout engine fits a fixed portrait canvas per device.
- `Scripts/appstore.py` (918 lines, stdlib + `openssl`) pushes the copy and the screenshots. `push_screenshots` (l. 602) does set → delete all → reserve/upload/commit with an MD5 checksum → PATCH the order. All of that runs on the **deprecated** set-based endpoints. `config.json` hard-codes `displayType` (`APP_IPHONE_67`, `APP_IPAD_PRO_3GEN_129`). Apple now says to look up placement groups at runtime instead (`IPHONE_DYNAMIC_ISLAND_LARGE_PROFILE`, `IPAD_13_PROFILE`, …).
- `make listing-check` validates lengths and PNG sizes offline. It knows nothing about creative assets.
- Raw captures are 1320×2868 (iPhone) and 2064×2752 (iPad), both portrait. No existing capture fits 21:9, 3:2 or 16:9, so a header needs **new artwork**, not a re-crop.
- Screenshot audit against the new guidance: the captions are short and evocative, as Apple asks. No prices, URLs or accolades appear in the images. Search results without a creative asset show 01-today / 02-habit-detail / 03-widgets, which is a sensible lead. One aside: `06-settings` opens on an orange **"Not signed in to iCloud"** warning, because the screenshot run drops CloudKit. That's a weak first frame for the privacy pitch, and it's worth a seed or UI-test tweak whatever we decide here.

## Proposed approach

Split the work into three pieces that can each ship on their own, in this order:

### 1. A creative asset, drawn by the existing frame tool (the visible win)

Extend `frame-screenshots.swift` with a **landscape canvas** that composes a header from parts we already have: the paper→sage ground, a Fraunces headline, and one or two real captures (device-framed Today, maybe the widget tiles) placed off-centre. Output one **universal 16:9 5244×2950 PNG** per locale into `marketing/<locale>/creative/universal.png`.

- Universal first, because one file covers both placements and the 16:9 shape is the only one both accept. It also keeps the "same picture everywhere" property the pipeline was built for.
- Copy lives in `captions.json` under a new key (e.g. `"creative-universal"`), localized EN/FR, ≤ ~5 words, "enhance, not describe". Candidates: *"Habits, without the all-or-nothing."* / *"Des habitudes, sans le tout-ou-rien."*, which echoes the promotional text.
- Keep the focal point and headline inside a centred safe area. Apple publishes no number, so assume the middle ~60% and confirm in the ASC Preview tool once.
- Strip alpha on export: the current frames are drawn opaque, but the PNG writer must not emit an alpha channel.
- Effort: about a day, mostly design iteration. `make frames` is seconds per pass.

### 2. Upload creative assets through the Asset Library API

Add `creative` to `appstore.py`:

1. `GET /v1/apps/{id}/assetLibrary` → library id.
2. `POST /v1/appAssetLibraryImages` with `category: CREATIVE_ASSETS`, upload parts, commit `uploaded: true`, poll until `PREPARE_FOR_SUBMISSION`, then check that the returned `specId` is the universal spec.
3. `POST /v1/appAssetLibraryPlacements` twice per localization (`PRODUCT_PAGE_HEADER_ASSET` and `APP_STORE_SEARCH_RESULTS_ASSET`, group `DEFAULT_PROFILE`), against the editable `appStoreVersionLocalization`.
4. Replace = delete placement → create new placement → delete the orphaned asset. Deletes are not cascaded, and an asset with placements can't be deleted.

`--dry-run` and `make listing-check` cover it like everything else. The check gains: exact size per spec, PNG, no alpha.

Open alternative: the standalone Asset Library submission, which gets the header live **without** a new version. The docs describe it in the UI. The API path for it (if any) isn't documented in the pages read, so the first version may be "attach to the next app version".

Effort: about half a day of script work plus one real run.

### 3. Migrate screenshots off the deprecated set endpoints (housekeeping, not urgent)

Rewrite `push_screenshots` / `show_info` on the asset library: upload each PNG once, one placement per (locale, group), one ordering request per group. `config.json` swaps `displayType` for a placement group id, or better, a display class that the ref data resolves at runtime, as Apple recommends. The MD5 checksum goes away. Steps 2 and 3 share the upload code, so 3 is cheaper once 2 exists.

This is also where **iPhone Duo** lands (`IPHONE_DUO_PROFILE`; outer 1398×2034, inner 2007×2853). Duo screenshots are **required from April 2027 for builds on the iOS 27.1 SDK**. That needs a Duo simulator in `screenshots.sh` and is a separate small project. It's flagged here so it isn't discovered at submission time.

## Alternatives considered

### Hand-made header in Figma/Pixelmator, uploaded through the ASC web UI
- Idea: use Apple's templates, drag in once per locale.
- Why not (by default): it breaks the listing's founding rule. Nothing is made or uploaded by hand, and `make frames` keeps the site, the screenshots and the header visually in sync. It's still a fine stopgap if the header should be live this week.

### Separate 21:9 header + 3:2 search assets
- Idea: one composition per shape, each optimised for its crop.
- Why not now: twice the artwork and copy to localize, for a listing with a small audience. Revisit if the 16:9 universal crops badly in either placement in the Preview tool.

### Video header (screen recording of Today → log → score)
- Idea: Apple pushes video ("start strong, loop seamlessly, work silently").
- Why not now: it needs a recording pipeline (`simctl io recordVideo` + editing), and the header spec needs 10 s+ at exactly 3840×1646, so it would be upscaled from a portrait sim. That's high effort for a calm, static brand. Defer, and note it as a PPO test candidate later.

### Do nothing
- Viable. Search keeps showing screenshots 01–03, which are good. The cost is a bare header on iOS 27 product pages next to competitors that have one.

## Risks and unknowns

- **Safe area is undocumented.** The universal 16:9 will be cropped to ~21:9 for the header and ~3:2 for search. Composition has to survive both crops, which in practice means a horizontal band around the centre. The ASC Preview tool is the only check.
- **Spec drift between docs and live data** (header PNG-only, 10 s video minimum). Read the ref data at runtime and assert the returned `specId`. Don't hard-code it.
- **Review**: creative assets go through review and must not mislead (guideline 2.3). Real UI keeps us safe. "No tracking. Ever." as a claim is already on the screenshots and is true.
- **No CI coverage**: like the rest of `make listing`, this is verified by running it. `--dry-run` reads the live state.
- The deprecated endpoints carry no announced removal date. Waiting on step 3 is a judgement call, not a deadline.

## Open questions

- [ ] **Scope**: header artwork only (1), header + API upload (1+2), or the full migration including screenshots (1+2+3)?
- [ ] **Headline copy** for the header, EN and FR. Reuse the promotional-text idea, or something new?
- [ ] **Composition**: one centred device on paper, or device + widget tiles? (A mock of each via `make frames` would make this a visual choice.)
- [ ] **Go-live path**: attach to the next version (1.7?), or standalone Asset Library submission through the web UI as a one-off?
- [ ] Fix the "Not signed in to iCloud" banner in `06-settings` in this PR or separately?
- [ ] iPhone Duo screenshots: open an issue now for the April 2027 requirement?

## References

- Apple, [App Store asset best practices](https://developer.apple.com/app-store/asset-best-practices/)
- Apple, [Creative assets specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/creative-assets-specifications)
- Apple, [Manage your App Store assets](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-your-app-store-assets/)
- Apple, App Store Connect API: [Understanding the App Asset Library](https://developer.apple.com/documentation/appstoreconnectapi/understanding-the-app-asset-library), [Migrating to the App Asset Library](https://developer.apple.com/documentation/appstoreconnectapi/migrating-to-the-app-asset-library), [Placing assets](https://developer.apple.com/documentation/appstoreconnectapi/placing-assets-on-your-app-store-surfaces), [Discovering asset specifications](https://developer.apple.com/documentation/appstoreconnectapi/discovering-asset-specifications)
- Apple, [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications) (iPhone Duo sizes, April 2027 requirement)
- Adapty, [App Store Asset Library is live](https://adapty.io/blog/app-store-asset-library/) (go-live date 2026-10-05)
