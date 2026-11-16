#!/bin/sh
# Prints the identifier of a simulator: the one named by IPAD_SIMULATOR (an iPhone will do), or otherwise an
# iPad on the newest installed iOS version. Prints nothing when there is none.
set -eu

xcrun simctl list devices available --json | /usr/bin/python3 -c '
import json
import os
import sys

wanted = os.environ.get("IPAD_SIMULATOR", "")
runtimes = json.load(sys.stdin)["devices"]


def version(runtime):
    digits = runtime.rsplit("iOS-", 1)[-1].split("-")
    return [int(part) for part in digits if part.isdigit()]


candidates = [
    (version(runtime), device)
    for runtime, devices in runtimes.items() if "iOS" in runtime
    for device in devices if device["name"] == wanted or (not wanted and device["name"].startswith("iPad"))
]
candidates.sort(key=lambda pair: pair[0])
print(candidates[-1][1]["udid"] if candidates else "")
'
