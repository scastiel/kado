#!/usr/bin/env python3
"""Give exported xcresult attachments the names the test gave them, and check their size.

`xcresulttool export attachments` writes every attachment under a generated file name and
records the real one in a manifest. The real one is the whole point — "01-today" is what puts
the screenshot first in App Store Connect — so this is the step that turns one into the other.

    name-screenshots.py <exported dir> <destination dir> <expected WxH>
    name-screenshots.py --self-test

The destination is added to, never emptied: a light pass, a dark pass and a widgets pass write
into the same folder, and the caller is what decides when the folder starts over.

Anything that is not the size App Store Connect accepts for the device is a hard error: a
listing is rejected for it, and the rejection arrives days later.

The one exception is a *tile*: an attachment named `NN-name--part` is one piece of a shot that
`Scripts/frame-screenshots.swift` assembles rather than a shot on its own, and it lands at
`NN-name/part.png` at whatever size the element it photographs has. The widgets shot is made of
four of these. `--self-test` checks the routing rule without a result bundle.
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

# What separates a shot's name from a tile's part in an attachment name. Two dashes, because a
# shot's own name is already hyphenated ("02-habit-detail") and a slash does not survive the
# export.
TILE_SEPARATOR = "--"


def route(attachment_name: str) -> tuple[Path, bool]:
    """Where an attachment lands under the destination, and whether it is a whole shot.

    "01-today" is a shot and goes to `01-today.png`, checked against the device canvas.
    "03-widgets--medium" is a tile of the "03-widgets" shot and goes to
    `03-widgets/medium.png`, at whatever size it is.
    """
    chosen = DISAMBIGUATOR.sub("", Path(attachment_name).stem)
    if TILE_SEPARATOR in chosen:
        shot, part = chosen.split(TILE_SEPARATOR, 1)
        return Path(shot) / f"{part}.png", False
    return Path(f"{chosen}.png"), True


def self_test() -> int:
    cases = {
        "01-today": (Path("01-today.png"), True),
        "01-today_0_11CD98D7-8F5E-4F6B-9E7A-2C3D4E5F6A7B": (Path("01-today.png"), True),
        "02-habit-detail": (Path("02-habit-detail.png"), True),
        "03-widgets--medium": (Path("03-widgets/medium.png"), False),
        "03-widgets--lock_3_11CD98D7-8F5E-4F6B-9E7A-2C3D4E5F6A7B": (
            Path("03-widgets/lock.png"), False
        ),
    }
    failures = [
        f"{name!r} → {route(name)!r}, expected {expected!r}"
        for name, expected in cases.items()
        if route(name) != expected
    ]
    for failure in failures:
        print(failure, file=sys.stderr)
    print("routing: " + ("ok" if not failures else f"{len(failures)} wrong"))
    return 1 if failures else 0


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
    if sys.argv[1:] == ["--self-test"]:
        return self_test()
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
        relative, is_shot = route(name)
        if is_shot and size != expected_size:
            print(
                f"{name} is {size[0]}x{size[1]}, and the listing needs {expected}",
                file=sys.stderr,
            )
            return 1

        target = destination / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(file, target)
        print(f"  {target}  {size[0]}x{size[1]}")
        written += 1

    if written == 0:
        print(f"the manifest in {source} held no screenshots", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
