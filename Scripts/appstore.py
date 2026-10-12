#!/usr/bin/env python3
"""Push Kadō's listing — copy, screenshots and creative — to App Store Connect.

    Scripts/appstore.py check                  # lengths and files, no network
    Scripts/appstore.py info                   # what the API currently holds
    Scripts/appstore.py metadata               # names, descriptions, keywords, what's new
    Scripts/appstore.py screenshots            # the framed images, replacing what's there
    Scripts/appstore.py creative               # the product page header and search asset
    Scripts/appstore.py all                    # all three, in that order

Copy lives in docs/app-store/metadata/<locale>/<field>.txt, one file per field, because a
description is four thousand characters of prose with its own line breaks and no JSON string
survives being edited by hand at that length. Screenshots come from docs/app-store/marketing/,
which is what `make screenshots` writes.

Credentials, the same pair `make testflight` uses:

    ASC_KEY_ID     the key's ID; the .p8 is found by it under ~/.appstoreconnect/private_keys
    ASC_ISSUER_ID  the Issuer ID shown above the key list in App Store Connect

Everything that writes takes `--dry-run`, which reads the same, compares the same, and stops
short of the write. Run it first: this is the copy customers read, and the API has no undo.

No third-party packages. The ES256 signature App Store Connect wants is made with `openssl`,
which is the one part of this that would otherwise need a dependency.
"""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONFIG_PATH = ROOT / "docs/app-store/config.json"
METADATA_DIR = ROOT / "docs/app-store/metadata"
MARKETING_DIR = ROOT / "docs/app-store/marketing"

API = "https://api.appstoreconnect.apple.com"

# Stands in for the id a `POST` would have returned, so a dry run can carry on describing what
# it would do instead of stopping at the first record that does not exist yet.
DRY_RUN_ID = "dry-run"

# The two records a listing's copy is split across, and the fields each one owns. App Store
# Connect draws them on one page, so the split is invisible in the UI and load-bearing here:
# a name lives on the *app*, a description lives on the *version*, and patching one with the
# other's fields is a 409 with a message that doesn't say which field was wrong.
APP_INFO_FIELDS = {
    "name": "name",
    "subtitle": "subtitle",
    "privacy_url": "privacyPolicyUrl",
}
VERSION_FIELDS = {
    "description": "description",
    "keywords": "keywords",
    "promotional_text": "promotionalText",
    "release_notes": "whatsNew",
    "support_url": "supportUrl",
    "marketing_url": "marketingUrl",
}

# What App Store Connect enforces. Checked here rather than discovered on submission, because
# a rejection for a 31-character subtitle arrives days after the upload that caused it.
LIMITS = {
    "name": 30,
    "subtitle": 30,
    "promotional_text": 170,
    "description": 4000,
    "keywords": 100,
    "release_notes": 4000,
}

# Apple's own states for "you may still edit this". Anything else is live or in review, and
# writing to it is refused by the API rather than queued.
#
# `PREPARE_FOR_SUBMISSION` is listed first and picked first: a version in review may
# technically still accept some fields, and quietly writing to that one instead of the draft
# being prepared is the wrong guess to make silently.
EDITABLE_STATES = (
    "PREPARE_FOR_SUBMISSION",
    "DEVELOPER_REJECTED",
    "REJECTED",
    "METADATA_REJECTED",
    "INVALID_BINARY",
    "READY_FOR_REVIEW",
    "WAITING_FOR_REVIEW",
)


def state_of(record: dict) -> str | None:
    """The record's state, under whichever name this API version calls it.

    App Store Connect renamed `appStoreState` to `appVersionState` and kept both on the
    response for a while. Reading one and not the other works right up until the day it
    doesn't, and the symptom is "no version is open for editing" on an app that plainly has
    one.
    """
    attributes = record.get("attributes", {})
    return (
        attributes.get("appVersionState")
        or attributes.get("appStoreState")
        or attributes.get("state")
    )


def fail(message: str) -> "NoReturn":  # noqa: F821
    print(f"error: {message}", file=sys.stderr)
    raise SystemExit(1)


# MARK: - Authentication


def sign_es256(message: bytes, key_path: Path) -> bytes:
    """The raw 64-byte R||S signature a JWT needs, via openssl.

    `openssl dgst -sign` emits the DER encoding — a SEQUENCE of two INTEGERs — and JWS wants
    the two integers laid end to end, fixed at 32 bytes each. Converting between them is the
    whole reason this function exists rather than a one-line call.
    """
    der = subprocess.run(
        ["openssl", "dgst", "-sha256", "-sign", str(key_path), "-binary"],
        input=message,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=True,
    ).stdout

    if not der or der[0] != 0x30:
        fail("openssl did not return a DER ECDSA signature — is the .p8 an EC private key?")
    index = 2 + (der[1] & 0x7F if der[1] & 0x80 else 0)

    def read_integer(at: int) -> tuple[bytes, int]:
        if der[at] != 0x02:
            fail("malformed DER signature from openssl")
        length = der[at + 1]
        value = der[at + 2 : at + 2 + length]
        # DER keeps a leading zero byte to stop a high bit reading as a negative number, and
        # pads short integers not at all. JWS wants exactly 32 bytes either way.
        return value.lstrip(b"\x00").rjust(32, b"\x00"), at + 2 + length

    r, next_index = read_integer(index)
    s, _ = read_integer(next_index)
    return r + s


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def token() -> str:
    key_id = os.environ.get("ASC_KEY_ID")
    issuer_id = os.environ.get("ASC_ISSUER_ID")
    if not key_id or not issuer_id:
        fail(
            "ASC_KEY_ID and ASC_ISSUER_ID must both be set.\n"
            "  The issuer is shown above the key list at\n"
            "  https://appstoreconnect.apple.com/access/integrations/api"
        )

    candidates = [
        Path.home() / ".appstoreconnect/private_keys" / f"AuthKey_{key_id}.p8",
        Path.home() / "private_keys" / f"AuthKey_{key_id}.p8",
        ROOT / f"AuthKey_{key_id}.p8",
    ]
    key_path = next((path for path in candidates if path.exists()), None)
    if key_path is None:
        listed = "\n".join(f"    {path}" for path in candidates)
        fail(f"no AuthKey_{key_id}.p8 found. Looked in:\n{listed}")

    now = int(time.time())
    header = {"alg": "ES256", "kid": key_id, "typ": "JWT"}
    # Twenty minutes: Apple's ceiling for a token is twenty, and a run that uploads a dozen
    # screenshots to four localizations takes a couple of them.
    payload = {
        "iss": issuer_id,
        "iat": now,
        "exp": now + 20 * 60,
        "aud": "appstoreconnect-v1",
    }
    signing_input = ".".join(
        b64url(json.dumps(part, separators=(",", ":")).encode()) for part in (header, payload)
    ).encode()
    return f"{signing_input.decode()}.{b64url(sign_es256(signing_input, key_path))}"


# MARK: - HTTP


class Client:
    def __init__(self, dry_run: bool = False):
        self.authorization = f"Bearer {token()}"
        self.dry_run = dry_run

    def request(
        self, method: str, path: str, body=None, *,
        raw_url: str = None, headers=None, authorize: bool = True,
    ):
        url = raw_url or (API + path)
        data = None
        # The asset upload URLs are pre-signed and point at a different host, which hands back
        # a 403 for an Authorization header it never asked for. Everything else needs one.
        request_headers = {"Authorization": self.authorization} if authorize else {}
        if headers:
            request_headers.update(headers)
        if body is not None:
            if isinstance(body, bytes):
                data = body
            else:
                data = json.dumps(body).encode()
                request_headers["Content-Type"] = "application/json"

        request = urllib.request.Request(url, data=data, method=method, headers=request_headers)
        # One retry, and only for the two failures that are about the server rather than about
        # the request: a rate limit and a 5xx. Anything else is a mistake worth showing at once.
        for attempt in range(2):
            try:
                with urllib.request.urlopen(request) as response:
                    payload = response.read()
                    if not payload:
                        return None
                    # An asset upload answers with whatever the storage host feels like; only
                    # the API itself promises JSON.
                    try:
                        return json.loads(payload)
                    except json.JSONDecodeError:
                        return None
            except urllib.error.HTTPError as error:
                detail = error.read().decode(errors="replace")
                if error.code in (429, 500, 502, 503) and attempt == 0:
                    time.sleep(3)
                    continue
                fail(f"{method} {url} → {error.code}\n{detail}")
            except urllib.error.URLError as error:
                fail(f"{method} {url} → {error.reason}")

    def get(self, path: str, **params):
        if params:
            query = "&".join(f"{key}={value}" for key, value in params.items())
            path = f"{path}?{query}"
        return self.request("GET", path)

    def get_all(self, path: str, **params) -> list:
        """Every page of a collection, which matters for screenshots and for nothing else."""
        items, page = [], self.get(path, **params)
        while page:
            items.extend(page.get("data", []))
            following = (page.get("links") or {}).get("next")
            if not following:
                break
            page = self.request("GET", "", raw_url=following)
        return items

    def post(self, path: str, body):
        if self.dry_run:
            return {"data": {"id": DRY_RUN_ID, "attributes": {}}}
        return self.request("POST", path, body)

    def patch(self, path: str, body):
        if self.dry_run:
            return None
        return self.request("PATCH", path, body)

    def delete(self, path: str):
        if self.dry_run:
            return None
        return self.request("DELETE", path)


# MARK: - Local metadata


@dataclass
class Listing:
    locale: str
    fields: dict[str, str]


def load_config() -> dict:
    if not CONFIG_PATH.exists():
        fail(f"{CONFIG_PATH.relative_to(ROOT)} is missing")
    return json.loads(CONFIG_PATH.read_text())


def load_listings(locales: list[str]) -> list[Listing]:
    listings = []
    for locale in locales:
        directory = METADATA_DIR / locale
        if not directory.is_dir():
            fail(f"no copy for {locale} — expected {directory.relative_to(ROOT)}/")
        fields = {}
        for file in sorted(directory.glob("*.txt")):
            # Trailing newlines are an artefact of the file, not of the copy. App Store Connect
            # keeps whatever it is given, so one left in shows up as a blank last line.
            fields[file.stem] = file.read_text().rstrip("\n")
        listings.append(Listing(locale=locale, fields=fields))
    return listings


# Characters App Store Connect refuses in a description, and the reason it is worth checking
# here: the refusal is a 409 from the middle of an upload, naming one character and no line
# number, after some of the run has already been written.
#
# Box Drawing and Block Elements — U+2500 to U+259F — is exactly the range somebody reaches for
# to draw a rule between sections, and `docs/app-store-connect.md` had done precisely that with
# `━`. The listing uses a row of hyphens instead.
FORBIDDEN = {chr(code) for code in range(0x2500, 0x25A0)}


def forbidden_in(value: str) -> set[str]:
    return {character for character in value if character in FORBIDDEN}


def check(config: dict, locales: list[str]) -> int:
    """Everything that can be known without the network: lengths, and whether the images exist."""
    problems = 0
    known = set(APP_INFO_FIELDS) | set(VERSION_FIELDS)

    for listing in load_listings(locales):
        print(f"{listing.locale}")
        for name in sorted(listing.fields):
            value = listing.fields[name]
            if name not in known:
                print(f"  ?  {name}.txt is not a field this uploads")
                problems += 1
                continue
            limit = LIMITS.get(name)
            length = len(value)
            if not value:
                print(f"  !  {name} is empty")
                problems += 1
            elif limit and length > limit:
                print(f"  !  {name} is {length} characters, and the limit is {limit}")
                problems += 1
            elif forbidden_in(value):
                drawn = " ".join(sorted(forbidden_in(value)))
                print(
                    f"  !  {name} contains {drawn}, which App Store Connect refuses."
                    " Use hyphens for a rule."
                )
                problems += 1
            else:
                print(f"  ok {name:<18} {length}" + (f"/{limit}" if limit else ""))
        missing = sorted(known - set(listing.fields))
        for name in missing:
            print(f"  -  {name}.txt is absent, so that field is left as it is")

        for device, spec in config["devices"].items():
            folder = MARKETING_DIR / listing.locale / device
            shots = sorted(folder.glob("*.png")) if folder.is_dir() else []
            if not shots:
                print(f"  !  no framed screenshots in {folder.relative_to(ROOT)}")
                problems += 1
                continue
            # App Store Connect takes between three and ten per set, and
            # says so only after the upload.
            if not 3 <= len(shots) <= 10:
                print(
                    f"  !  {device} has {len(shots)} screenshots,"
                    " and a set takes between 3 and 10"
                )
                problems += 1
            width, height = (int(part) for part in spec["size"].split("x"))
            for shot in shots:
                actual = png_size(shot)
                if actual != (width, height):
                    print(
                        f"  !  {shot.name} on {device} is {actual[0]}x{actual[1]},"
                        f" and the set needs {spec['size']}"
                    )
                    problems += 1
            print(f"  ok {device:<18} {len(shots)} screenshots")

        problems += check_creative(listing.locale)
        print()

    if problems:
        print(f"{problems} thing(s) to fix before uploading.")
    else:
        print("Ready to upload.")
    return 1 if problems else 0


# The creatives under marketing/<locale>/creative/, and the size each is drawn at. The universal
# 16:9 is the product page header; the 3:2 is the search results asset, drawn separately
# because search shows every pixel of an image the header only shows the top of. App Store
# Connect refuses alpha in either outright — an alpha channel that is opaque everywhere is
# still an alpha channel.
CREATIVE_FILES = {
    "universal.png": (5244, 2950),
    "search.png": (3840, 2560),
}


def check_creative(locale: str) -> int:
    problems = 0
    for name, expected in CREATIVE_FILES.items():
        path = MARKETING_DIR / locale / "creative" / name
        shown = path.relative_to(ROOT)
        if not path.exists():
            print(f"  !  no creative at {shown} — `make frames` draws it")
            problems += 1
            continue
        size = png_size(path)
        found = 0
        if size != expected:
            print(
                f"  !  {name} is {size[0]}x{size[1]},"
                f" and it is drawn for {expected[0]}x{expected[1]}"
            )
            found += 1
        if png_has_alpha(path):
            print(f"  !  {shown} has an alpha channel, which App Store Connect refuses")
            found += 1
        if not found:
            print(f"  ok {'creative/' + name:<18} {size[0]}x{size[1]}, no alpha")
        problems += found
    return problems


def png_has_alpha(path: Path) -> bool:
    """Whether a PNG can carry transparency: an alpha colour type, or a `tRNS` chunk, which
    gives a palette or even a plain RGB image a transparent colour without changing its type."""
    data = path.read_bytes()
    color_type = data[25]
    if color_type in (4, 6):  # grey + alpha, RGB + alpha
        return True
    offset = 8
    while offset + 8 <= len(data):
        length = int.from_bytes(data[offset : offset + 4], "big")
        kind = data[offset + 4 : offset + 8]
        if kind == b"tRNS":
            return True
        if kind == b"IDAT":  # tRNS must come before the image data
            return False
        offset += 12 + length
    return False


def png_size(path: Path) -> tuple[int, int]:
    with path.open("rb") as handle:
        header = handle.read(24)
    if header[:8] != b"\x89PNG\r\n\x1a\n":
        fail(f"{path} is not a PNG")
    return int.from_bytes(header[16:20], "big"), int.from_bytes(header[20:24], "big")


# MARK: - Locating the app, its info record, and the version being edited


def find_app(client: Client, bundle_id: str) -> dict:
    apps = client.get("/v1/apps", **{"filter[bundleId]": bundle_id})["data"]
    if not apps:
        fail(f"no app with bundle id {bundle_id} is visible to this API key")
    return apps[0]


def find_app_info(client: Client, app_id: str) -> dict:
    infos = client.get(f"/v1/apps/{app_id}/appInfos")["data"]
    editable = pick_editable(infos)
    if editable is None:
        fail(
            "no editable app info record — the listing's name and subtitle can only be "
            "changed while a version is being prepared."
        )
    return editable


def pick_editable(records: list[dict]) -> dict | None:
    """The most editable record, in `EDITABLE_STATES` order rather than the API's."""
    for state in EDITABLE_STATES:
        for record in records:
            if state_of(record) == state:
                return record
    return None


def create_version(client: Client, config: dict, version_string: str):
    """Open the next version for editing, which is what everything else here needs.

    A version record is a draft, not a submission — it creates the "Prepare for Submission"
    slot the copy and the screenshots hang off, and it can be deleted again from App Store
    Connect while it is still in that state. Nothing is sent to review by this.
    """
    app = find_app(client, config["bundleId"])
    versions = client.get(
        f"/v1/apps/{app['id']}/appStoreVersions",
        **{"filter[platform]": "IOS", "limit": "20"},
    )["data"]

    existing = next(
        (v for v in versions if v["attributes"]["versionString"] == version_string), None
    )
    if existing:
        fail(f"{version_string} already exists, in state {state_of(existing)}.")

    # App Store Connect allows one version in flight at a time, and refuses the second with a
    # message about the *app* rather than about the version already open. Say which one.
    already_open = pick_editable(versions)
    if already_open:
        fail(
            f"{already_open['attributes']['versionString']} is already open for editing "
            f"({state_of(already_open)}). App Store Connect allows one at a time — finish it, "
            "or delete it in App Store Connect, before opening another."
        )

    # Carried forward from the most recent version rather than left blank, because a version
    # created through the API does not inherit them the way one created in the UI does.
    attributes = {"platform": "IOS", "versionString": version_string}
    if versions:
        for field in ("copyright", "releaseType"):
            value = versions[0]["attributes"].get(field)
            if value:
                attributes[field] = value

    print(f"{app['attributes']['name']} — creating version {version_string}")
    for key, value in sorted(attributes.items()):
        print(f"  {key}: {value}")

    created = client.post(
        "/v1/appStoreVersions",
        {
            "data": {
                "type": "appStoreVersions",
                "attributes": attributes,
                "relationships": {"app": {"data": {"type": "apps", "id": app["id"]}}},
            }
        },
    )
    if client.dry_run:
        print("\n  (dry run — nothing was created)")
        return
    version = created["data"]
    print(f"\n  created, in state {state_of(version)}")
    print("  Next: Scripts/appstore.py all --dry-run, then make listing")


def find_version(client: Client, app_id: str, wanted: str | None) -> dict:
    versions = client.get(
        f"/v1/apps/{app_id}/appStoreVersions",
        **{"filter[platform]": "IOS", "limit": "20"},
    )["data"]
    if wanted:
        for version in versions:
            if version["attributes"]["versionString"] == wanted:
                return version
        fail(f"this app has no {wanted} version record")
    editable = pick_editable(versions)
    if editable is None:
        available = ", ".join(
            f"{v['attributes']['versionString']} ({state_of(v)})" for v in versions[:5]
        )
        fail(
            "no version is open for editing. Create the next version in App Store Connect "
            f"first, or name one with --version.\n  Most recent: {available}"
        )
    return editable


def localizations(client: Client, path: str) -> dict[str, dict]:
    return {item["attributes"]["locale"]: item for item in client.get_all(path)}


# MARK: - Metadata


def push_metadata(client: Client, config: dict, locales: list[str], wanted_version: str | None):
    app = find_app(client, config["bundleId"])
    app_info = find_app_info(client, app["id"])
    version = find_version(client, app["id"], wanted_version)
    print(
        f"{app['attributes']['name']} — version {version['attributes']['versionString']}"
        f" ({state_of(version)})"
    )

    info_localizations = localizations(
        client, f"/v1/appInfos/{app_info['id']}/appInfoLocalizations"
    )
    version_localizations = localizations(
        client, f"/v1/appStoreVersions/{version['id']}/appStoreVersionLocalizations"
    )

    for listing in load_listings(locales):
        print(f"\n{listing.locale}")
        _push(
            client,
            listing,
            APP_INFO_FIELDS,
            existing=info_localizations.get(listing.locale),
            collection="appInfoLocalizations",
            parent=("appInfo", app_info["id"]),
        )
        _push(
            client,
            listing,
            VERSION_FIELDS,
            existing=version_localizations.get(listing.locale),
            collection="appStoreVersionLocalizations",
            parent=("appStoreVersion", version["id"]),
        )


def _push(client, listing, mapping, *, existing, collection, parent):
    """Patch the fields this listing actually carries, and say which ones changed.

    Absent files are absent on purpose: a locale that has no `marketing_url.txt` should keep
    whatever App Store Connect already holds, not have it cleared. Only files that exist are
    sent, which is what makes it safe to run this after editing one field by hand in the UI.
    """
    attributes = {
        mapping[name]: listing.fields[name] for name in mapping if name in listing.fields
    }
    if not attributes:
        return

    if existing is None:
        print(f"  + creating {collection[:-1]} for {listing.locale}")
        parent_type, parent_id = parent
        client.post(
            f"/v1/{collection}",
            {
                "data": {
                    "type": collection,
                    "attributes": {**attributes, "locale": listing.locale},
                    "relationships": {
                        parent_type: {"data": {"type": parent_type + "s", "id": parent_id}}
                    },
                }
            },
        )
        return

    current = existing["attributes"]
    changed = {key: value for key, value in attributes.items() if current.get(key) != value}
    if not changed:
        print(f"  = {collection[:-1]} already matches")
        return
    for key in sorted(changed):
        before = (current.get(key) or "").replace("\n", " ")[:48]
        after = changed[key].replace("\n", " ")[:48]
        print(f"  ~ {key}\n      was: {before}\n      now: {after}")
    client.patch(
        f"/v1/{collection}/{existing['id']}",
        {"data": {"type": collection, "id": existing["id"], "attributes": changed}},
    )


# MARK: - Screenshots


def push_screenshots(
    client: Client, config: dict, locales: list[str], wanted_version: str | None,
    prune: bool = False,
):
    app = find_app(client, config["bundleId"])
    version = find_version(client, app["id"], wanted_version)
    print(
        f"{app['attributes']['name']} — version {version['attributes']['versionString']}"
        f" ({state_of(version)})"
    )
    version_localizations = localizations(
        client, f"/v1/appStoreVersions/{version['id']}/appStoreVersionLocalizations"
    )

    for locale in locales:
        localization = version_localizations.get(locale)
        if localization is None:
            fail(
                f"App Store Connect has no {locale} localization to hang screenshots on. "
                "Run `metadata` first — it creates one."
            )
        print(f"\n{locale}")
        sets = {
            item["attributes"]["screenshotDisplayType"]: item
            for item in client.get_all(
                f"/v1/appStoreVersionLocalizations/{localization['id']}/appScreenshotSets"
            )
        }

        for device, spec in config["devices"].items():
            folder = MARKETING_DIR / locale / device
            shots = sorted(folder.glob("*.png")) if folder.is_dir() else []
            if not shots:
                print(f"  - {device}: nothing in {folder.relative_to(ROOT)}, left alone")
                continue

            display_type = spec["displayType"]
            screenshot_set = sets.get(display_type)
            print(f"  {device} → {display_type}")
            if screenshot_set is None:
                print("    creating the set, which the listing does not have yet")
                created = client.post(
                    "/v1/appScreenshotSets",
                    {
                        "data": {
                            "type": "appScreenshotSets",
                            "attributes": {"screenshotDisplayType": display_type},
                            "relationships": {
                                "appStoreVersionLocalization": {
                                    "data": {
                                        "type": "appStoreVersionLocalizations",
                                        "id": localization["id"],
                                    }
                                }
                            },
                        }
                    },
                )
                screenshot_set = created["data"]

            set_id = screenshot_set["id"]
            # Replaced wholesale rather than diffed. The API has no way to ask "is this the
            # same picture", the set is at most ten small files, and a half-updated set — new
            # shot 3 beside old shot 4 — is the failure worth designing away.
            #
            # Nothing to replace in a set that does not exist yet — which in a dry run is
            # every set the listing is missing, and whose id is a placeholder that would 404.
            existing = (
                []
                if set_id == DRY_RUN_ID
                else client.get_all(f"/v1/appScreenshotSets/{set_id}/appScreenshots")
            )
            for screenshot in existing:
                client.delete(f"/v1/appScreenshots/{screenshot['id']}")
            if existing:
                print(f"    removed {len(existing)} existing screenshot(s)")

            uploaded = []
            for shot in shots:
                uploaded.append(upload_screenshot(client, set_id, shot))
                print(f"    {shot.name}")

            if client.dry_run:
                print(f"  ✓ {device}: {len(shots)} screenshots (dry run, nothing sent)")
                continue

            # The order the set is shown in, which is not the order they were created in.
            client.patch(
                f"/v1/appScreenshotSets/{set_id}/relationships/appScreenshots",
                {"data": [{"type": "appScreenshots", "id": i} for i in uploaded]},
            )
            print(f"  ✓ {device}: {len(shots)} screenshots")

        # Sets the listing has and this repo does not. Left alone by default — deleting
        # somebody's screenshots on a flag they didn't pass is not a thing a tool should do.
        #
        # But leaving them is not harmless either: Apple serves the closest set it has and
        # scales down from there, so an old 6.5" set beside a fresh 6.7" one means two
        # different people see two different listings, one of them out of date. That is
        # exactly the drift this pipeline exists to remove, hence the flag.
        configured_types = {device["displayType"] for device in config["devices"].values()}
        for display_type, screenshot_set in sorted(sets.items()):
            if display_type in configured_types:
                continue
            if not prune:
                print(
                    f"  - {display_type}: in the listing but not in config.json, left as it is"
                    " (--prune-sets removes it)"
                )
                continue
            print(f"  ✗ {display_type}: removing, nothing here replaces it")
            client.delete(f"/v1/appScreenshotSets/{screenshot_set['id']}")


def upload_screenshot(client: Client, set_id: str, path: Path) -> str:
    """Reserve, upload, then commit — the three steps every asset in this API takes."""
    payload = path.read_bytes()
    reservation = client.post(
        "/v1/appScreenshots",
        {
            "data": {
                "type": "appScreenshots",
                "attributes": {"fileName": path.name, "fileSize": len(payload)},
                "relationships": {
                    "appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": set_id}}
                },
            }
        },
    )
    if client.dry_run:
        return DRY_RUN_ID

    screenshot = reservation["data"]
    for operation in screenshot["attributes"]["uploadOperations"]:
        chunk = payload[operation["offset"] : operation["offset"] + operation["length"]]
        headers = {
            header["name"]: header["value"] for header in operation.get("requestHeaders", [])
        }
        client.request(
            operation["method"], "", body=chunk,
            raw_url=operation["url"], headers=headers, authorize=False,
        )

    # The checksum is Apple's proof the bytes arrived whole. MD5 is what the API asks for; it
    # is an integrity check against a truncated upload, not a security claim.
    client.patch(
        f"/v1/appScreenshots/{screenshot['id']}",
        {
            "data": {
                "type": "appScreenshots",
                "id": screenshot["id"],
                "attributes": {
                    "uploaded": True,
                    "sourceFileChecksum": hashlib.md5(payload).hexdigest(),
                },
            }
        },
    )
    return screenshot["id"]


# MARK: - The creative: product page header and search results asset
#
# Creative assets exist only in the App Asset Library, a newer half of the API than the
# screenshot sets above: an image is uploaded to the app's library once, then *placed* — on a
# version localization, as a header or as a search results asset. Placements are immutable and
# a version takes one of each, so replacing an image is delete-then-create, and deleting the
# image afterwards is a separate step the API will refuse while any placement still uses it.
#
# The API keeps no checksum of what was uploaded, so the file's own hash rides in the image's
# `referenceName` — the one free-text field it lets us set and filter on. A run that finds both
# placements already pointing at an image with this file's name has nothing to do.

CREATIVE_PLACEMENTS = ("PRODUCT_PAGE_HEADER_ASSET", "APP_STORE_SEARCH_RESULTS_ASSET")

# Image states from which an asset can be placed. Everything before them is still uploading or
# processing; FAILED is its own case.
CREATIVE_READY = (
    "PREPARE_FOR_SUBMISSION", "READY_FOR_REVIEW", "WAITING_FOR_REVIEW", "IN_REVIEW",
    "ACCEPTED", "APPROVED",
)


def creative_reference(locale: str, payload: bytes) -> str:
    return f"kado-creative-{locale}-{hashlib.sha256(payload).hexdigest()[:16]}"


# Which file each placement shows, first one present wins. The header takes the universal 16:9;
# search takes its own 3:2 when there is one, because search shows every pixel of an image the
# header only shows the top of, and falls back to the universal one when there isn't.
CREATIVE_SOURCES = {
    "PRODUCT_PAGE_HEADER_ASSET": ("universal.png",),
    "APP_STORE_SEARCH_RESULTS_ASSET": ("search.png", "universal.png"),
}


def creative_reference_data(client: Client) -> dict:
    """Apple's image specs and placement types, read at run time rather than written down here:
    Apple says to, and the help page's numbers already disagreed with the live data the first
    time this ran."""
    return client.get(
        "/v1/appAssetLibraryRefData",
        **{"fields[appAssetLibraryRefData]": "imageSpecs,placementTypes"},
    )["data"][0]["attributes"]


def creative_spec(reference: dict, placement_type: str, size: tuple[int, int]) -> tuple[str, str]:
    """The spec an image of `size` meets for `placement_type`, and the group it is placed in.

    Matched on the placement and the pixel size alone, which is enough: the universal 16:9 is
    one exact size, and the search-only 3:2 is a range no 16:9 falls into. Whatever Apple's
    processing then files the upload under is checked against this.
    """
    width, height = size
    for spec in reference["imageSpecs"]:
        dimensions = spec["dimensions"]
        if (placement_type in spec["compatiblePlacementTypes"]
                and dimensions["minWidth"] <= width <= dimensions["maxWidth"]
                and dimensions["minHeight"] <= height <= dimensions["maxHeight"]):
            break
    else:
        fail(
            f"no image spec in Apple's reference data takes a {width}x{height} "
            f"{placement_type} — the frame tool's sizes need to follow it"
        )
    for entry in reference["placementTypes"]:
        if entry["placementTypeId"] != placement_type:
            continue
        for mapping in entry["specMappings"]:
            if spec["specId"] in mapping["specs"]:
                return spec["specId"], mapping["placementGroupId"]
    fail(f"no placement group takes spec {spec['shortName']} for {placement_type}")


def creative_placements(client: Client, localization_id: str) -> dict[str, tuple[dict, dict]]:
    """The localization's header and search placements, each with the image it shows."""
    response = client.get(
        f"/v1/appStoreVersionLocalizations/{localization_id}/placements",
        **{
            "filter[placementType]": ",".join(CREATIVE_PLACEMENTS),
            "include": "image",
            "limit": "50",
        },
    )
    images = {item["id"]: item for item in response.get("included", [])}
    placements = {}
    for placement in response["data"]:
        image_id = placement["relationships"]["image"]["data"]["id"]
        placements[placement["attributes"]["placementType"]] = (
            placement, images.get(image_id, {"id": image_id, "attributes": {}})
        )
    return placements


def push_creative(client: Client, config: dict, locales: list[str], wanted_version: str | None):
    app = find_app(client, config["bundleId"])
    version = find_version(client, app["id"], wanted_version)
    state = state_of(version)
    print(
        f"{app['attributes']['name']} — creative, version "
        f"{version['attributes']['versionString']} ({state})"
    )
    # Narrower than the copy's `EDITABLE_STATES`: Apple places assets only on a version being
    # prepared, and refuses the rest with a STATE_ERROR from the middle of the run.
    if state != "PREPARE_FOR_SUBMISSION":
        message = (
            f"placements can only be made on a version in PREPARE_FOR_SUBMISSION, and "
            f"{version['attributes']['versionString']} is {state}. Open the next version "
            "first (create-version)."
        )
        if not client.dry_run:
            fail(message)
        print(f"  ! {message}\n    Dry run, so carrying on to show what would change.")

    library_id = client.get(f"/v1/apps/{app['id']}/assetLibrary")["data"]["id"]
    reference_data = creative_reference_data(client)
    version_localizations = localizations(
        client, f"/v1/appStoreVersions/{version['id']}/appStoreVersionLocalizations"
    )

    for locale in locales:
        print(f"\n{locale}")
        localization = version_localizations.get(locale)
        if localization is None:
            fail(
                f"App Store Connect has no {locale} localization to place the creative on. "
                "Run `metadata` first — it creates one."
            )
        placed = creative_placements(client, localization["id"])
        # One upload per file, however many placements show it.
        uploaded: dict[str, str] = {}
        replaced = set()

        for placement_type, candidates in CREATIVE_SOURCES.items():
            folder = MARKETING_DIR / locale / "creative"
            path = next((folder / name for name in candidates if (folder / name).exists()), None)
            if path is None:
                print(f"  - {placement_type}: nothing in {folder.relative_to(ROOT)}, left alone")
                continue
            payload = path.read_bytes()
            reference = creative_reference(locale, payload)
            current = placed.get(placement_type)
            if current and current[1]["attributes"].get("referenceName") == reference:
                print(f"  = {placement_type} already shows {path.name} ({reference})")
                continue

            spec_id, group = creative_spec(reference_data, placement_type, png_size(path))
            if reference not in uploaded:
                uploaded[reference] = creative_image(
                    client, library_id, spec_id, path, payload, reference
                )
            image_id = uploaded[reference]

            if current:
                was = current[1]["attributes"].get("referenceName") or current[1]["id"]
                print(f"  ✗ {placement_type}: removing the placement of {was}")
                client.delete(f"/v1/appAssetLibraryPlacements/{current[0]['id']}")
                replaced.add(current[1]["id"])
            print(f"  + {placement_type} ({group}) → {path.name} ({reference})")
            client.post(
                "/v1/appAssetLibraryPlacements",
                {
                    "data": {
                        "type": "appAssetLibraryPlacements",
                        "attributes": {
                            "placementType": placement_type,
                            "placementGroup": group,
                        },
                        "relationships": {
                            "image": {
                                "data": {"type": "appAssetLibraryImages", "id": image_id}
                            },
                            "appStoreVersionLocalization": {
                                "data": {
                                    "type": "appStoreVersionLocalizations",
                                    "id": localization["id"],
                                }
                            },
                        },
                    }
                },
            )

        # An image this run took off the version is deleted only once nothing places it: the
        # live version's localization, or another locale, may still be showing it, and the
        # API refuses the delete anyway while one does. A dry run removed nothing, so it says
        # what it would check instead of checking it.
        for old_id in sorted(replaced):
            if client.dry_run:
                print(f"  ? {old_id}: deleted afterwards if nothing else places it")
                continue
            remaining = client.get(
                f"/v1/appAssetLibraryImages/{old_id}/relationships/placements"
            )["data"]
            if remaining:
                print(f"  - {old_id}: still placed {len(remaining)} time(s) elsewhere, kept")
            else:
                client.delete(f"/v1/appAssetLibraryImages/{old_id}")
                print(f"  ✗ {old_id}: no placements left, deleted from the library")


def creative_image(
    client: Client, library_id: str, spec_id: str, path: Path, payload: bytes, reference: str
) -> str:
    """The id of a library image holding exactly this file, uploading it if there is none.

    An image left by an interrupted run — uploaded, never placed — is found by its name and
    reused rather than uploaded a second time beside itself.
    """
    existing = client.get(
        f"/v1/appAssetLibraries/{library_id}/images",
        **{
            "filter[category]": "CREATIVE_ASSETS",
            "filter[referenceName]": reference,
        },
    )["data"]
    for image in existing:
        attributes = image["attributes"]
        if attributes.get("state") in CREATIVE_READY and attributes.get("specId") == spec_id:
            print(f"  · {reference} is already in the library ({attributes['state']})")
            return image["id"]
        # Half-uploaded or failed: of no use, and in the way of the name.
        print(f"  ✗ {reference}: discarding a {attributes.get('state')} copy")
        client.delete(f"/v1/appAssetLibraryImages/{image['id']}")

    print(f"  ↑ uploading {path.name} as {reference}")
    reservation = client.post(
        "/v1/appAssetLibraryImages",
        {
            "data": {
                "type": "appAssetLibraryImages",
                "attributes": {
                    "fileName": path.name,
                    "fileSize": len(payload),
                    "category": "CREATIVE_ASSETS",
                    "referenceName": reference,
                },
                "relationships": {
                    "assetLibrary": {"data": {"type": "appAssetLibraries", "id": library_id}}
                },
            }
        },
    )
    if client.dry_run:
        return DRY_RUN_ID

    image = reservation["data"]
    for operation in image["attributes"]["uploadOperations"]:
        chunk = payload[operation["offset"] : operation["offset"] + operation["length"]]
        headers = {
            header["name"]: header["value"] for header in operation.get("requestHeaders", [])
        }
        client.request(
            operation["method"], "", body=chunk,
            raw_url=operation["url"], headers=headers, authorize=False,
        )
    # No checksum here, unlike a screenshot: the library checks the bytes against `fileSize`.
    client.patch(
        f"/v1/appAssetLibraryImages/{image['id']}",
        {"data": {"type": "appAssetLibraryImages", "id": image["id"],
                  "attributes": {"uploaded": True}}},
    )

    # Processing is where Apple decides which spec the file meets. Placing an image before it
    # has one is refused, and an image that met some other spec would place as the wrong thing.
    deadline = time.time() + 10 * 60
    while True:
        attributes = client.get(f"/v1/appAssetLibraryImages/{image['id']}")["data"]["attributes"]
        state = attributes.get("state")
        if state in CREATIVE_READY:
            break
        if state == "FAILED":
            client.delete(f"/v1/appAssetLibraryImages/{image['id']}")
            fail(f"App Store Connect refused {path.name}: {attributes.get('stateDetails')}")
        if time.time() > deadline:
            fail(f"{path.name} is still {state} after ten minutes — re-run to pick it up")
        time.sleep(5)
    if attributes.get("specId") != spec_id:
        fail(
            f"{path.name} was processed as spec {attributes.get('specId')}, not the universal "
            f"creative {spec_id} — it would not place as both header and search asset"
        )
    print(f"  ✓ processed ({state})")
    return image["id"]


# MARK: - Reading back


def show_info(client: Client, config: dict):
    app = find_app(client, config["bundleId"])
    attributes = app["attributes"]
    print(f"{attributes['name']}  ({attributes['bundleId']})  id {app['id']}")

    versions = client.get(
        f"/v1/apps/{app['id']}/appStoreVersions",
        **{"filter[platform]": "IOS", "limit": "10"},
    )["data"]
    print("\nVersions")
    for version in versions:
        state = state_of(version)
        editable = "editable" if state in EDITABLE_STATES else ""
        print(f"  {version['attributes']['versionString']:<8} {state:<28} {editable}")

    # The version being prepared if there is one, else the newest released one. Falling silent
    # when nothing is editable would hide the one thing this command is for between releases:
    # which locales and which screenshot sets the live listing actually has, which is what says
    # whether `config.json`'s display types still match what Apple expects.
    version = pick_editable(versions) or (versions[0] if versions else None)
    if version is None:
        return
    editable = state_of(version) in EDITABLE_STATES
    print(
        f"\nLocalizations on {version['attributes']['versionString']}"
        f"{'' if editable else ' (live — read only until a new version is created)'}"
    )
    live_locales, live_types = set(), set()
    for locale, localization in sorted(
        localizations(
            client, f"/v1/appStoreVersions/{version['id']}/appStoreVersionLocalizations"
        ).items()
    ):
        live_locales.add(locale)
        sets = client.get_all(
            f"/v1/appStoreVersionLocalizations/{localization['id']}/appScreenshotSets"
        )
        counts = []
        for screenshot_set in sets:
            display_type = screenshot_set["attributes"]["screenshotDisplayType"]
            live_types.add(display_type)
            shots = client.get_all(
                f"/v1/appScreenshotSets/{screenshot_set['id']}/appScreenshots"
            )
            counts.append(f"{display_type}×{len(shots)}")
        print(f"  {locale:<8} {', '.join(counts) if counts else 'no screenshots'}")
        placed = creative_placements(client, localization["id"])
        for placement_type in CREATIVE_PLACEMENTS:
            if placement_type not in placed:
                print(f"           {placement_type}: none")
                continue
            placement, image = placed[placement_type]
            name = image["attributes"].get("referenceName") or image["id"]
            print(
                f"           {placement_type}: {name}"
                f" (placement {placement['attributes']['state']},"
                f" image {image['attributes'].get('state')})"
            )

    # What the listing holds versus what this repo is about to send it. Both mismatches below
    # are silent failures rather than errors: a locale we don't have would *add* a second
    # localization rather than update the intended one, and a display type we don't have leaves
    # the old set sitting beside the new one. Neither is refused by the API, and both were
    # live here the first time this ran.
    configured_locales = {
        language["locale"] for language in config["languages"].values()
    }
    configured_types = {device["displayType"] for device in config["devices"].values()}

    for label, configured, live in (
        ("locale", configured_locales, live_locales),
        ("screenshot set", configured_types, live_types),
    ):
        for value in sorted(configured - live):
            print(f"\n  ! config.json has {label} {value}, which the listing does not.")
            print("    Uploading creates a new one rather than replacing anything.")
        for value in sorted(live - configured):
            print(f"\n  ! the listing has {label} {value}, which config.json does not.")
            print("    Nothing here will update it, and it stays as it is.")


# MARK: - Entry point


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument(
        "command",
        choices=[
            "check", "info", "create-version", "metadata", "screenshots", "creative", "all",
        ],
    )
    parser.add_argument(
        "version_string",
        nargs="?",
        help="for create-version: the version to open, e.g. 1.7",
    )
    parser.add_argument(
        "--locales", nargs="+", help="only these, e.g. --locales fr-FR (default: all of them)"
    )
    parser.add_argument(
        "--version", dest="version", help="the version record to write to (default: the "
        "one open for editing)"
    )
    parser.add_argument(
        "--dry-run", action="store_true", help="read and compare, but send no writes"
    )
    parser.add_argument(
        "--prune-sets", action="store_true",
        help="also delete screenshot sets the listing has that config.json does not",
    )
    parser.add_argument(
        "--yes", action="store_true", help="skip the confirmation prompt"
    )
    arguments = parser.parse_args()

    config = load_config()
    locales = arguments.locales or [
        language["locale"] for language in config["languages"].values()
    ]

    if arguments.command == "check":
        return check(config, locales)

    if arguments.command == "create-version" and not arguments.version_string:
        fail("create-version needs the version to open, e.g. create-version 1.7")

    if arguments.command in ("create-version", "metadata", "screenshots", "creative", "all") \
            and not arguments.dry_run:
        if not arguments.yes and sys.stdin.isatty():
            what = {
                "all": f"copy, screenshots and the creative for {', '.join(locales)}",
                "metadata": f"copy for {', '.join(locales)}",
                "screenshots": f"screenshots for {', '.join(locales)}",
                "creative": f"the header and search creative for {', '.join(locales)}",
                "create-version": f"a new version {arguments.version_string}",
            }[arguments.command]
            print(f"About to write {what} to App Store Connect.")
            if input("Continue? [y/N] ").strip().lower() not in ("y", "yes"):
                print("Nothing was sent.")
                return 1

    client = Client(dry_run=arguments.dry_run)
    if arguments.dry_run:
        print("Dry run — nothing will be written.\n")

    if arguments.command == "info":
        show_info(client, config)
    if arguments.command == "create-version":
        create_version(client, config, arguments.version_string)
    if arguments.command in ("metadata", "all"):
        push_metadata(client, config, locales, arguments.version)
    if arguments.command in ("screenshots", "all"):
        if arguments.command == "all":
            print()
        push_screenshots(
            client, config, locales, arguments.version, prune=arguments.prune_sets
        )
    if arguments.command in ("creative", "all"):
        if arguments.command == "all":
            print()
        push_creative(client, config, locales, arguments.version)

    if not arguments.dry_run and arguments.command in ("metadata", "screenshots", "all"):
        print("\nDone. Review it in App Store Connect before submitting.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
