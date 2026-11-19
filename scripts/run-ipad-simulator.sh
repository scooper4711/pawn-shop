#!/bin/sh
# Builds the iPad app for the simulator, installs it and starts it.
#
# IPAD_SIMULATOR  name of the simulator to use (default: an iPad on the newest iOS installed)
set -eu

cd "$(dirname "$0")/.."
[ -d Generated ] || echo "Warning: Generated/ is missing; run \"make items\" to bundle the item cards." >&2

DEVICE="$(scripts/ipad-simulator-id.sh)"
[ -n "$DEVICE" ] || { echo "Starting the simulator failed: no iPad simulator is installed." >&2; exit 1; }

# Unsigned, so it builds without a developer team; the App Group is then missing and Import from Scrollkeeper asks
# for the folder. It has no iCloud entitlement either, so it names no container to sync through: CloudKit stops an
# app that opens one without the entitlement.
xcodebuild -project ios/PawnShop.xcodeproj -scheme PawnShop-iPad \
    -destination "platform=iOS Simulator,id=$DEVICE" -derivedDataPath ios/build \
    CODE_SIGNING_ALLOWED=NO TABLESIDE_SYNC_CONTAINER= build | tail -n 3

APP="ios/build/Build/Products/Debug-iphonesimulator/PawnShop.app"
xcrun simctl boot "$DEVICE" 2>/dev/null || true
# Xcode 27 shows simulators in Device Hub; earlier versions in the Simulator app.
open -b com.apple.dt.Devices 2>/dev/null || open -a Simulator
xcrun simctl install "$DEVICE" "$APP"
xcrun simctl launch "$DEVICE" io.github.scooper4711.PawnShop
