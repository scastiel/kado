#!/usr/bin/env python3
"""Give exported xcresult attachments the names the test gave them, and check their size.

`xcresulttool export attachments` writes every attachment under a generated file name and
records the real one in a manifest. The real one is the whole point — "01-today" is what puts
the screenshot first in App Store Connect — so this is the step that turns one into the other.

    name-screenshots.py <exported dir> <destination dir> <expected WxH>

The destination is added to, never emptied: a light pass and a dark pass write into the same
folder, and the caller is what decides when the folder starts over.

Anything that is not the size App Store Connect accepts for the device is a hard error: a
listing is rejected for it, and the rejection arrives days later.
"""

import json
import re
import shutil
import struct
import sys
from pathlib import Path

# The name a test gives an attachment comes back with the attachment's index and UUID glued to
# it — "01-today_0_11CD98D7-…". Only the part in front of that is the name anyone chose.
DISAMBIGUATOR = re.compile(r"_\d+_[0-9A-Fa-f-]{36}$")


def png_size(path: Path) -> tuple[int, int]:
    """Width and height straight out of the IHDR chunk, which is always the first one."""
    with path.open("rb") as handle:
        header = handle.read(24)
    if header[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"{path} is not a PNG")
    return struct.unpack(">II", header[16:24])


def attachments(manifest) -> list[dict]:
    """Every attachment in the manifest, whatever shape this Xcode wrote it in."""
    entries = manifest if isinstance(manifest, list) else manifest.get("tests", [manifest])
    return [
        attachment
        for entry in entries
        for attachment in entry.get("attachments", [])
    ]


def main() -> int:
    source, destination, expected = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3]
    expected_size = tuple(int(part) for part in expected.split("x"))

    manifest_path = source / "manifest.json"
    if not manifest_path.exists():
        print(f"no manifest in {source} — the run captured nothing", file=sys.stderr)
        return 1

    manifest = json.loads(manifest_path.read_text())
    destination.mkdir(parents=True, exist_ok=True)

    written = 0
    for attachment in attachments(manifest):
        exported = attachment.get("exportedFileName")
        name = attachment.get("suggestedHumanReadableName") or attachment.get("name")
        if not exported or not name:
            continue

        file = source / exported
        if not file.exists():
            print(f"manifest names {exported}, which was not exported", file=sys.stderr)
            return 1

        # A failing run attaches the element hierarchy as text, and XCTest attaches a few
        # diagnostics of its own. Only the pictures are wanted here, and a run that failed has
        # a better story to tell than "that attachment was not a PNG".
        if file.suffix.lower() != ".png":
            continue

        size = png_size(file)
        if size != expected_size:
            print(
                f"{name} is {size[0]}x{size[1]}, and the listing needs {expected}",
                file=sys.stderr,
            )
            return 1

        target = destination / f"{DISAMBIGUATOR.sub('', Path(name).stem)}.png"
        shutil.copyfile(file, target)
        print(f"  {target}  {size[0]}x{size[1]}")
        written += 1

    if written == 0:
        print(f"the manifest in {source} held no screenshots", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
