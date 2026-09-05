#!/usr/bin/env python3
"""Push Kadō's listing — copy and screenshots — to App Store Connect.

    Scripts/appstore.py check                  # lengths and files, no network
    Scripts/appstore.py info                   # what the API currently holds
    Scripts/appstore.py metadata               # names, descriptions, keywords, what's new
    Scripts/appstore.py screenshots            # the framed images, replacing what's there
    Scripts/appstore.py all                    # both, metadata first

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
        print()

    if problems:
        print(f"{problems} thing(s) to fix before uploading.")
    else:
        print("Ready to upload.")
    return 1 if problems else 0


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


def push_screenshots(client: Client, config: dict, locales: list[str], wanted_version: str | None):
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
            if screenshot_set is None:
                print(f"  + {device}: creating the {display_type} set")
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

    editable_versions = [
        v for v in versions if state_of(v) in EDITABLE_STATES
    ]
    if not editable_versions:
        return
    version = editable_versions[0]
    print(f"\nLocalizations on {version['attributes']['versionString']}")
    for locale, localization in sorted(
        localizations(
            client, f"/v1/appStoreVersions/{version['id']}/appStoreVersionLocalizations"
        ).items()
    ):
        sets = client.get_all(
            f"/v1/appStoreVersionLocalizations/{localization['id']}/appScreenshotSets"
        )
        counts = []
        for screenshot_set in sets:
            shots = client.get_all(
                f"/v1/appScreenshotSets/{screenshot_set['id']}/appScreenshots"
            )
            counts.append(
                f"{screenshot_set['attributes']['screenshotDisplayType']}×{len(shots)}"
            )
        print(f"  {locale:<8} {', '.join(counts) if counts else 'no screenshots'}")


# MARK: - Entry point


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument(
        "command", choices=["check", "info", "metadata", "screenshots", "all"]
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
        "--yes", action="store_true", help="skip the confirmation prompt"
    )
    arguments = parser.parse_args()

    config = load_config()
    locales = arguments.locales or [
        language["locale"] for language in config["languages"].values()
    ]

    if arguments.command == "check":
        return check(config, locales)

    if arguments.command in ("metadata", "screenshots", "all") and not arguments.dry_run:
        if not arguments.yes and sys.stdin.isatty():
            what = "copy and screenshots" if arguments.command == "all" else arguments.command
            print(f"About to write {what} for {', '.join(locales)} to App Store Connect.")
            if input("Continue? [y/N] ").strip().lower() not in ("y", "yes"):
                print("Nothing was sent.")
                return 1

    client = Client(dry_run=arguments.dry_run)
    if arguments.dry_run:
        print("Dry run — nothing will be written.\n")

    if arguments.command == "info":
        show_info(client, config)
    if arguments.command in ("metadata", "all"):
        push_metadata(client, config, locales, arguments.version)
    if arguments.command in ("screenshots", "all"):
        if arguments.command == "all":
            print()
        push_screenshots(client, config, locales, arguments.version)

    if not arguments.dry_run and arguments.command != "info":
        print("\nDone. Review it in App Store Connect before submitting.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
