#!/bin/bash
# Run from the repository root, after installing a Release build of Glass Lab.
# Usage: capture.sh SIMULATOR_UDID OUT.png --mode native|clear|none --style clear --bg grid ...
# Two identical frames establish stability, not scene identity: retain a plain-background negative control as well.
set -euo pipefail
if [ "$#" -lt 2 ]; then
    echo "usage: $0 SIMULATOR_UDID OUT.png [Glass Lab arguments...]" >&2
    exit 2
fi
device=$1
output=$2
shift 2
mkdir -p "$(dirname "$output")"
xcrun simctl launch --terminate-running-process "$device" studio.aemi.GlassLab "$@" >/dev/null
sleep "${SCENE_SETTLE_SECONDS:-2.2}"
previous=""
for attempt in 1 2 3 4 5 6; do
    xcrun simctl io "$device" screenshot "$output" >/dev/null 2>&1
    current=$(shasum -a 256 "$output")
    if [ "$current" = "$previous" ]; then exit 0; fi
    previous=$current
    sleep 0.6
done
echo "scene did not settle: $output" >&2
exit 1
