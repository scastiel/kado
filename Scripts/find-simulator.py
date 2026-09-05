#!/usr/bin/env python3
"""Print the UDID of the simulator with this exact name.

    xcrun simctl list devices -j | find-simulator.py "Kado Shots main iphone-6.9"

The UDID rather than the name, because the name is not a stable address: a clone left behind by
a parallel test run is called "Clone 1 of <name>", and a device is reachable by its own name
right up until something creates a second one. It is also the only way to reach the device's
preferences on disk, which is where a screenshot run sets the system language.
"""

import json
import sys


def main() -> int:
    name = sys.argv[1]
    devices = json.load(sys.stdin)["devices"]

    matches = [
        device
        for runtime in devices.values()
        for device in runtime
        if device.get("name") == name and device.get("isAvailable", True)
    ]
    if len(matches) != 1:
        print(
            f"expected exactly one simulator named {name!r}, found {len(matches)}",
            file=sys.stderr,
        )
        return 1

    print(matches[0]["udid"])
    return 0


if __name__ == "__main__":
    sys.exit(main())
