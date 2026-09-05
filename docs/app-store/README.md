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

## Before submitting

`make listing` writes the listing. It does not submit it, and it does not upload a build — that is `xcrun altool --upload-app`, and it is a separate decision.

Run `python3 Scripts/appstore.py all --dry-run` first if you want to see the diff before it goes: it reads and compares exactly as the real run does, prints every field that would change with its before and after, and sends nothing.

Then check it in App Store Connect. The API will happily accept copy that is correct and wrong.
