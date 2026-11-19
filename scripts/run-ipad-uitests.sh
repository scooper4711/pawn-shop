#!/bin/sh
# Runs the iPad UI tests in a simulator. They screenshot the window in landscape and portrait; the screenshots are
# kept in the test results (ios/build/Logs/Test).
#
# IPAD_SIMULATOR  name of the simulator to use (default: an iPad on the newest iOS installed)
# ONLY            tests to run, space-separated, such as "LayoutUITests/testSheetInLandscape"
set -eu

cd "$(dirname "$0")/.."

DEVICE="$(scripts/ipad-simulator-id.sh)"
[ -n "$DEVICE" ] || { echo "Running the UI tests failed: no iPad simulator is installed." >&2; exit 1; }
echo "Running the UI tests on simulator $DEVICE..."

# Unsigned, so the app has no iCloud entitlement and names no container to sync through (see run-ipad-simulator.sh).
set -- -project ios/PawnShop.xcodeproj -scheme PawnShop-iPad \
    -destination "platform=iOS Simulator,id=$DEVICE" -derivedDataPath ios/build CODE_SIGNING_ALLOWED=NO \
    TABLESIDE_SYNC_CONTAINER=
for test in ${ONLY:-}; do set -- "$@" -only-testing:"PawnShopUITests/$test"; done

LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT
STATUS=0
xcodebuild test "$@" > "$LOG" 2>&1 || STATUS=$?
grep -E " error: |Test Case .*(passed|failed)|\*\* TEST" "$LOG" || tail -n 20 "$LOG"
exit "$STATUS"
