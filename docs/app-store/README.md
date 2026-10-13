# The App Store listing, from the command line

Everything App Store Connect shows about Kadō — the copy, in both languages, and the screenshots — lives in this folder and is pushed from it. Xcode is never opened, and nothing is retyped into a web form.

```
make screenshots     photograph the app, both languages, every device size, and frame it
make frames          re-wrap the existing captures — new headline, no recapture
make listing-check   lengths and image sizes, checked without the network
make listing-info    what App Store Connect currently holds
make listing         send the copy, the screenshots and the creative
make listing-creative  send only the header and search creative
```

`make listing` refuses to run until `make listing-check` passes, so a 31-character subtitle costs a second rather than a rejection that arrives days after the upload that caused it.

---

## What is where

| Path | What it is |
|---|---|
| `config.json` | The languages and the device sizes. The one table both halves of the pipeline read. Each size's App Store Connect placement group is looked up at upload time, never written here. |
| `metadata/<locale>/*.txt` | The copy. One file per field, because a description is four thousand characters of prose with its own line breaks and no JSON string survives being edited by hand at that length. |
| `captions.json` | The headline drawn across the top of each screenshot, per locale. |
| `screenshots/<locale>/<device>/` | The raw captures. The source of truth — committed, and never edited by hand. |
| `screenshots/<locale>/03-widgets/` | The widget tiles, one PNG per widget, photographed once at 3× and composed onto every canvas. An *assembly*, not a capture — see below. |
| `marketing/<locale>/<device>/` | The same captures wrapped in the frame, plus the assembled shots. **This is what gets uploaded.** |
| `marketing/<locale>/creative/universal.png` | The product page header (16:9). Drawn by the same `make frames`. See below. |
| `marketing/<locale>/creative/search.png` | The search results banner (3:2), drawn separately because search shows the whole image. |

`docs/app-store-connect.md`, one level up, is the human document: the age-rating answers, the App Review notes, the TestFlight copy, the submission checklists. It is prose for a person to read before a submission. This folder is what a script reads. Where they overlap — the description, the keywords — the files here are what actually ships, so a change made in one belongs in both.

---

## Locales — read this before adding one

Kadō's English listing is **`en-CA`**, not `en-US`. That is what App Store Connect actually holds, and it is not something to guess at: writing `en-US` would not update the English listing, it would quietly add a second English localization beside it. The API accepts that without complaint.

`make listing-info` prints the live locales and each locale's screenshots per placement group, and warns about anything in `config.json` that doesn't match them. Run it before changing either.

The same applies to device families. Screenshots are placed in **placement groups** (`IPHONE_DYNAMIC_ISLAND_LARGE_PROFILE` for the 1320×2868 captures, `IPAD_13_PROFILE` for the 2064×2752 ones). `appstore.py` resolves the group from each file's size against Apple's reference data, because Apple adds families there without an API version change. A group the listing holds that `config.json` would not produce is left alone and reported. `--prune-groups` removes it; that is how a stale smaller-iPhone family would be cleared. Under the old set API this was the `APP_IPHONE_65` set the 1.6 listing carried beside the current `APP_IPHONE_67` one.

---

## The copy

Every field is a file. An **absent file is left alone**: a locale with no `marketing_url.txt` keeps whatever App Store Connect already holds, rather than having it cleared. That is what makes it safe to run `make listing` after editing one field by hand in the web UI.

| File | Field | Limit |
|---|---|---|
| `name.txt` | App name | 30 |
| `subtitle.txt` | Subtitle | 30 |
| `privacy_url.txt` | Privacy policy URL | — |
| `description.txt` | Description | 4000 |
| `keywords.txt` | Keywords, comma-separated, no space after the commas | 100 |
| `promotional_text.txt` | Promotional text | 170 |
| `release_notes.txt` | What's New | 4000 |
| `support_url.txt` | Support URL | — |
| `marketing_url.txt` | Marketing URL | — |

The first three belong to the *app*; the rest belong to the *version*. App Store Connect draws them on one page, so the split is invisible in the UI and load-bearing in the API — the uploader knows which is which, and nothing else needs to.

Promotional text and What's New can be changed without a new review. The rest can only be changed while a version is open for editing, and `make listing` says so plainly if none is.

**French is native, not translated.** `tu` throughout, `série` for streak, `habitude` feminine — the conventions in `CLAUDE.md`. Never run the English through a translator and paste the result.

---

## The screenshots

`make screenshots` drives `KadoUITests/ScreenshotTests`, once per language and per device, in three passes: a light one for the screens (01, 02, 04–06) and a dark one for 07, because nothing inside a test can change the simulator's appearance and `simctl` can; and a widgets pass, on the iPhone only, for the tiles the frame assembles into 03. `Scripts/screenshots.sh --passes widgets` runs just that one — and a partial run adds to the folder rather than emptying it, so re-photographing the tiles after a lock-card tweak leaves the six screens as they were.

Before each pass the simulator is shut down, given the run's language on disk, booted, checked that the language took, pinned to the right appearance, and given a 9:41 status bar with a full battery. Two runs a week apart differ only where the app differs.

The app launches with `-uiTestRun`, which redirects SwiftData to a throwaway file and drops CloudKit. **A screenshot run cannot reach, let alone sync, anybody's real habits.** The data in the pictures is `DevModeSeed`'s, which translates its own habit names and carries a month of history, so the calendars and the scores photograph as something somebody has been using.

Then everything is wrapped: Kadō's paper ground, a Fraunces headline from `captions.json`, and a device the capture sits inside — the dark shot on a dark ground so it isn't a black rectangle marooned on white. The framing is a **separate pass over the raw captures**, which is the whole point: a new headline is `make frames` and four seconds, where re-photographing the app is a simulator per language per device and the better part of half an hour.

### The iPhone Duo

`iphone-duo` is the Duo's **outer** display, 1398×2034. It's one of the two sizes Apple's `IPHONE_DUO_PROFILE` accepts; the other is the inner 2007×2853. Apple requires Duo screenshots for builds on the iOS 27.1 SDK from April 2027. Two reasons for the outer display:

- **Kadō is already laid out for it.** On the inner display the app is a stretched phone layout (#140).
- **The capture can run unattended.** A fresh Duo simulator boots folded, so the app runs on the outer display. Nothing in `simctl` or XCTest can unfold one (`UIHinge` only observes the hinge), and the inner display stays black until a person unfolds it in Device Hub.

Both displays are separate framebuffers: `xcrun simctl io <udid> enumerate` lists them, and `screenshot --display=<uuid>` photographs either one.

On the outer display, iOS 27.1 moves the tab bar into a vertical rail, and moves the navigation bar's Back and overflow buttons into the system column on the right edge. A screen's first navigation-bar button is then its own trailing item (Habit Detail's **Edit**), so `ScreenshotTests` goes back through `KadoUITestCase.goBack(in:)`, which taps UIKit's `BackButton` identifier.

### The widgets shot is an assembly

`03-widgets` is not a photograph of a Home Screen — a real one carries a wallpaper, other apps' icons and a dock, and XCUITest adding widgets through jiggle mode is the most fragile thing the suite could do. It is the widgets themselves: the app, launched with `-uiTestWidgetGallery`, shows a Debug-only gallery of every widget at its Home Screen / Lock Screen size on the screenshot seed (`Kado/Support/WidgetGalleryView.swift`), and the test photographs each tile by element. The tiles land in `screenshots/<locale>/03-widgets/` — beside the device folders, not inside one, because every canvas is composed from the same 3× files. The frame then arranges them: one column on the phone's canvas, two on the iPad's and the iPhone Duo's, under the headline where a device would start. The arrangement lives in `Scripts/frame-screenshots.swift`'s `Assembly`, so moving a tile is `make frames`, not a simulator run.

The widget views themselves live in `KadoCore` so the app can draw them; the extension keeps only its `Widget` configurations. The gallery supplies what WidgetKit normally would — the container background, the 22pt corner, the 16pt content margins — and renders the Lock Screen widgets `.vibrant` on a dark card, the way a Lock Screen does. The Home Screen's Tinted and Clear appearances are the one thing it cannot show: those are flattened in WidgetKit's render server, not in SwiftUI.

### The creative: header and search banner

On iOS 27 a listing has two landscape slots — a header across the top of the product page and a creative in search results — and Apple accepts one **universal** 16:9 image for both. Kadō draws two instead, because the placements turned out to want opposite layouts (see the crops below):

- `marketing/<locale>/creative/universal.png`: **5244×2950**, Apple's universal spec, used for the **header**.
- `marketing/<locale>/creative/search.png`: **3840×2560**, Apple's search-only 3:2 spec, used for **search results**.

Both are PNGs with **no alpha channel**. App Store Connect refuses alpha outright, even an alpha channel that is opaque everywhere, so the frame writes them through a no-alpha bitmap rather than the RGBA one the screenshots use. `make listing-check` checks both files' size and alpha. Same headline, same drawing; each layout is a `CreativeLayout` value in `Scripts/frame-screenshots.swift`.

It is the same ground and the same Fraunces as the screenshots, laid out sideways. On the left are the `creative-universal` headline from `captions.json` and `稼 働 · in operation`, the wordmark from the foot of Settings, set as `SettingsView` sets it and left untranslated, as the app leaves it. On the right is that locale's iPhone `01-today` capture in a phone that runs off the bottom edge. Behind both, across the full width, is a band of the Overview grid in the monochrome sage theme. There is no icon or name: both placements draw the app's own icon and name right beside the creative. The grid is drawn, not cropped, because no capture shows the monochrome theme. Its cells are mixed in Oklab exactly as `MatrixCell` mixes them, and its rows are hand-set in `creativeMatrix`. It fades into the paper over the left half of its width (`Matrix.fadeLength`), so older days recede. The fade is masked with alpha while drawing; the written PNG is still flattened with no alpha. Nothing in it is new artwork, so a recapture or a reworded headline carries through on the next `make frames`. The layout is `Creative` in `Scripts/frame-screenshots.swift`.

**The crops, as measured.** Apple publishes no numbers, and the first cut's guess (a centred 60% × 75% band) was wrong for both placements. App Store Connect's **Preview** tool showed:

- **Search results:** the whole 16:9, about 615pt wide. Anything confined to the middle reads small there, which is why the grid runs edge to edge.
- **The iPhone product page header:** a 3:2 window of only ~54% × 64% of the canvas, centred across but **anchored to the top**: x 1212–4057, y 0–1890 (counting from the top). The bottom third of the canvas never shows there.
  - The status bar's fade covers its top (to y ≈ 400).
  - The back and share buttons cover its top corners (to y ≈ 800, at x 1317–1672 and 3597–3953).
  - So the headline and the phone start just below the buttons, inside the window's edges, and the grid's first row closes the window's bottom.
  - A first measurement assumed the window was centred vertically, and put the wordmark and grid below its bottom edge. Measure against where known elements land, not against the frame.

The layout constants in `Creative` are these numbers. Re-check in the Preview tool after any layout change, on iPhone and iPad.

Why the phone alone, and not the phone with widget tiles beside it: `docs/plans/2026-10/listing-creative/` has both mocks. The tiles repeated the list's rows at a smaller size and covered the "Slipped" row, which is the one that makes the headline's point.

The universal image was tried in search first, and in Apple's Preview tool it read as a small headline and phone adrift on paper. The layout that suits the header's small top window is wrong for a placement that shows every pixel. Hence `search.png`. A dedicated 21:9 header (3840×1646) is the remaining option if the universal image ever stops suiting the header.

#### Uploading it

`appstore.py creative` (in `make listing`, or alone as `make listing-creative`) sends them through the **App Asset Library**, the half of the API creative assets live in. Screenshot sets hang off the version; a creative is uploaded to the app's library once and then *placed* on each version localization.

- **Which file goes where:** `PRODUCT_PAGE_HEADER_ASSET` ← `universal.png`; `APP_STORE_SEARCH_RESULTS_ASSET` ← `search.png`, falling back to `universal.png` if there is no `search.png` (`CREATIVE_SOURCES`).
- **The spec is read, not written down.** Every run reads Apple's reference data (`/v1/appAssetLibraryRefData`) for the image spec that takes each file's placement and pixel size, and for the group it is placed in (`DEFAULT_PROFILE` today). It stops if no spec takes the size. After processing, it checks that Apple filed the upload under that spec.
- **Placements need a version being prepared.** Only `PREPARE_FOR_SUBMISSION` takes them, so a real run on anything else stops before writing. `--dry-run` warns and carries on, so the plan can be read between releases: `appstore.py creative --dry-run --version 1.13`.
- **Re-running is free.** The API keeps no checksum, so each image is named `kado-creative-<locale>-<sha256 prefix>` in its `referenceName`. When both placements already show the file's name, nothing is sent. When an upload is in the library but not placed (an interrupted run), it is reused instead of uploaded again.
- **Replacing leaves no orphans.** Placements are immutable and a version takes one of each, so a changed image means: delete the old placement, create the new one, then delete the old image, but only if nothing else still places it. The live version's localization may still be showing it, and the API refuses the delete while one does.
- `make listing-info` lists each locale's header and search placements, with the image name and both states.

### Adding a shot

1. Photograph it in `ScreenshotTests`, named `08-something` — the name orders the set in App Store Connect, and it is what the file ends up called. For an assembly, name each tile `08-something--part` instead; `Scripts/name-screenshots.py` files those under `08-something/` at whatever size the element has, and `frame-screenshots.swift` needs a layout for it.
2. Write its headline into `captions.json`, in **every** locale. The framing stops on a missing one rather than shipping one untitled screenshot beside six titled ones.
3. `make screenshots`.

### The marketing site

`getkado.app` ships the same captures, unframed and resized to about twice the width the page draws them — the site wraps them in its own CSS device bezels, which follow its light and dark mode. `make screenshots` and `make frames` both regenerate `docs/screenshots/site/{iphone,iphone-duo,ipad}/` from the iPhone, iPhone Duo and iPad captures, so the site and the listing cannot drift apart — they had, quietly, for several releases. `make site-shots` does only that step. Push the folder and the Pages workflow redeploys.

### Uploading them

`appstore.py screenshots` (in `make listing`) goes through the **App Asset Library**, like the creative. The screenshot-set endpoints it used before are deprecated.

- **Each file is uploaded once,** named `kado-shot-<name>-<sha256 prefix>` in its `referenceName`. It is then *placed* as `APP_SCREENSHOT` in its group, per localization.
- **Re-running costs nothing.** The whole run is planned first. A group that already shows exactly these files, in this order, is left alone. A file already in the library is placed rather than uploaded again, so a run interrupted halfway picks up where it stopped.
- **A changed group is reconciled, not wiped:**
  1. placements already showing a wanted file stay;
  2. the rest are deleted;
  3. the missing ones are placed;
  4. one ordering request per group sets the display order.
- **Uploads are batched:** every missing file is uploaded first, then all of them are waited on together, since processing takes a while per image.
- **Images are deleted only when nothing places them.** The version being prepared shares its images with the live one, which must keep them.
- Placements need a version in `PREPARE_FOR_SUBMISSION`, as for the creative. `--dry-run --version <live>` still prints the plan between releases.

---

## Credentials

The same key `altool` uses:

```bash
export ASC_KEY_ID=XXXXXXXXXX      # the key's ID
export ASC_ISSUER_ID=<uuid>       # shown above the key list in App Store Connect
```

The private key goes in `~/.appstoreconnect/private_keys/AuthKey_<ASC_KEY_ID>.p8` and is **never** committed. Both come from [Users and Access → Integrations → App Store Connect API](https://appstoreconnect.apple.com/access/integrations/api); the key needs the **App Manager** role to write a listing.

`Scripts/appstore.py` signs its own tokens with `openssl` rather than pulling in a JWT library — the one place a dependency would otherwise have crept into a project that has none.

---

## Uploading a build

```
make archive      a signed App Store archive
make ipa          export it
make testflight   both, then upload
```

These pass the same API key to `xcodebuild` as `-authenticationKeyPath` / `-authenticationKeyID` / `-authenticationKeyIssuerID`, alongside `-allowProvisioningUpdates`. That is what lets a machine archive without a distribution certificate already in its keychain — Xcode issues the signing assets through the API instead.

**Read this before the first run on a fresh machine.** "Issues the signing assets" means it *creates them on the account*, and two of those actions are not freely reversible:

- **An Apple Distribution certificate.** A team may hold at most two (three counting Xcode-managed ones). The private key exists only on the machine that created it and cannot be downloaded again from Apple, so a certificate created here is not usable from another Mac unless it is exported as a `.p12` first. Revoking one to make room invalidates every build signed with it that has not yet been uploaded.
- **An App Store provisioning profile** for `dev.scastiel.kado` and for each extension. These are cheap and regenerable; the certificate is the part to think about.

Check what the account already holds before creating anything — the App Store Connect API answers this directly, and `security find-identity -v -p codesigning` says what this machine holds. The two can disagree: a certificate can exist on the account with its private key on a different Mac, which looks identical to "no certificate" from here and is fixed by exporting a `.p12`, not by creating a second one.

**Signing needs an Admin key; the listing does not.** This is the one place two keys earn their keep:

| Key | Role | Can do |
|---|---|---|
| `3NJ328MR4F` | App Manager | the whole listing — copy, screenshots, version records |
| `RLTPSN7JPS` | Admin | all of that, plus cloud signing: certificates and profiles |

Use the App Manager key for `make listing` and the Admin key for `make archive` / `ipa` / `testflight`. Nothing stops you using the Admin key for everything, but the narrower one is the right default for the step that runs most often.

An App Manager key cannot create a distribution certificate *or* a provisioning profile. The failure is worth recognising because it arrives late and reads like a missing file rather than a permission:

```
error: exportArchive Cloud signing permission error
error: exportArchive No signing certificate "iOS Distribution" found
```

Worse, `xcodebuild archive` *succeeds* first — it falls back to the Apple Development identity and produces a Release archive signed with it, so the run looks fine right up until the export. Check `SigningIdentity` in the archive's `Info.plist` if in doubt:

```
/usr/libexec/PlistBuddy -c 'Print :ApplicationProperties:SigningIdentity' build/Kado.xcarchive/Info.plist
```

Two things have to be true, and the second is easy to miss because fixing the first changes the error rather than removing it:

1. **An Apple Distribution certificate in the keychain.** Made once, by a person, in **Xcode → Settings → Accounts → Manage Certificates → + → Apple Distribution**. Note that the same menu's "Apple Development" entry looks equally plausible and is not it — check with `security find-identity -v -p codesigning`, which must list `Apple Distribution: … (VKY5EKKU47)`.
2. **An App Store provisioning profile** for `dev.scastiel.kado` and each extension. These do not exist until something creates them, and creating them is cloud signing — so an Admin key, or one archive from Xcode's Organizer.

With only the first done, the error changes to `Provisioning profile "…" doesn't include signing certificate "…"`, which reads like a stale cache and is really the profile never having existed.

The archive on disk stays usable throughout — `-exportArchive` re-signs it — so only `make ipa` has to be re-run, never `make archive`.

The build number must exceed everything App Store Connect has already seen. It rejects a duplicate *after* the upload rather than before it, so bump `CURRENT_PROJECT_VERSION` in the same commit as `MARKETING_VERSION`; the repo convention is `chore: bump version to 1.X (build N)`. Both live in `Kado.xcodeproj/project.pbxproj` in eight places each — every target — and a partial bump builds fine and fails at upload.

---

## Before submitting

`make listing` writes the listing. It does not submit it, and it does not upload a build — that is `xcrun altool --upload-app`, and it is a separate decision.

Run `python3 Scripts/appstore.py all --dry-run` first if you want to see the diff before it goes: it reads and compares exactly as the real run does, prints every field that would change with its before and after, and sends nothing.

Then check it in App Store Connect. The API will happily accept copy that is correct and wrong.
