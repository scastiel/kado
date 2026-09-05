# The App Store listing, from the command line

Everything App Store Connect shows about Kadō — the copy, in both languages, and the screenshots — lives in this folder and is pushed from it. Xcode is never opened, and nothing is retyped into a web form.

```
make screenshots     photograph the app, both languages, both device sizes, and frame it
make frames          re-wrap the existing captures — new headline, no recapture
make listing-check   lengths and image sizes, checked without the network
make listing-info    what App Store Connect currently holds
make listing         send the copy and the screenshots
```

`make listing` refuses to run until `make listing-check` passes, so a 31-character subtitle costs a second rather than a rejection that arrives days after the upload that caused it.

---

## What is where

| Path | What it is |
|---|---|
| `config.json` | The languages, the device sizes, and the App Store Connect screenshot set each size belongs to. The one table both halves of the pipeline read. |
| `metadata/<locale>/*.txt` | The copy. One file per field, because a description is four thousand characters of prose with its own line breaks and no JSON string survives being edited by hand at that length. |
| `captions.json` | The headline drawn across the top of each screenshot, per locale. |
| `screenshots/<locale>/<device>/` | The raw captures. The source of truth — committed, and never edited by hand. |
| `marketing/<locale>/<device>/` | The same captures wrapped in the frame. **This is what gets uploaded.** |

`docs/app-store-connect.md`, one level up, is the human document: the age-rating answers, the App Review notes, the TestFlight copy, the submission checklists. It is prose for a person to read before a submission. This folder is what a script reads. Where they overlap — the description, the keywords — the files here are what actually ships, so a change made in one belongs in both.

---

## Locales — read this before adding one

Kadō's English listing is **`en-CA`**, not `en-US`. That is what App Store Connect actually holds, and it is not something to guess at: writing `en-US` would not update the English listing, it would quietly add a second English localization beside it. The API accepts that without complaint.

`make listing-info` prints the live locales and screenshot sets, and warns about anything in `config.json` that doesn't match them. Run it before changing either.

The same applies to screenshot sets. The 1.6 listing carries its iPhone shots under `APP_IPHONE_65` (the older 6.5" canvas, 1284×2778); these captures are 1320×2868, which belongs to `APP_IPHONE_67` — the size Apple asks for now and scales every smaller device from. The first upload therefore *creates* that set rather than replacing anything, and the old 6.5" one sits there until it is deleted by hand in App Store Connect.

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

`make screenshots` drives `KadoUITests/ScreenshotTests`, once per language and per device, twice over — a light pass for shots 01–05 and a dark pass for 06, because nothing inside a test can change the simulator's appearance and `simctl` can.

Before each pass the simulator is shut down, given the run's language on disk, booted, checked that the language took, pinned to the right appearance, and given a 9:41 status bar with a full battery. Two runs a week apart differ only where the app differs.

The app launches with `-uiTestRun`, which redirects SwiftData to a throwaway file and drops CloudKit. **A screenshot run cannot reach, let alone sync, anybody's real habits.** The data in the pictures is `DevModeSeed`'s, which translates its own habit names and carries a month of history, so the calendars and the scores photograph as something somebody has been using.

Then everything is wrapped: Kadō's paper ground, a Fraunces headline from `captions.json`, and a device the capture sits inside — the dark shot on a dark ground so it isn't a black rectangle marooned on white. The framing is a **separate pass over the raw captures**, which is the whole point: a new headline is `make frames` and four seconds, where re-photographing the app is a simulator per language per device and the better part of half an hour.

### Adding a shot

1. Photograph it in `ScreenshotTests`, named `07-something` — the name orders the set in App Store Connect, and it is what the file ends up called.
2. Write its headline into `captions.json`, in **every** locale. The framing stops on a missing one rather than shipping one untitled screenshot beside six titled ones.
3. `make screenshots`.

### The marketing site

`getkado.app` ships the same captures, unframed, at the canvas its CSS was built against. `make screenshots` and `make frames` both regenerate `docs/screenshots/iphone-67-appstore/` from the iPhone captures, so the site and the listing cannot drift apart — they had, quietly, for several releases. `make site-shots` does only that step. Push the folder and the Pages workflow redeploys.

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
