#!/usr/bin/env bash
# Builds "build/Pawn Shop.app" from the Swift package (release configuration, ad-hoc signed).
#
# Usage: scripts/build-app.sh [--install]   (--install moves it to /Applications)
#
# VERSION    version written to the bundle (default 0.0.0)
# UNIVERSAL  set to 1 to build for both Apple silicon and Intel
set -euo pipefail

cd "$(dirname "$0")/.."
VERSION="${VERSION:-0.0.0}"
APP="build/Pawn Shop.app"
EXECUTABLE="PawnShop"

if [[ "${UNIVERSAL:-0}" == "1" ]]; then
    swift build -c release --product "$EXECUTABLE" --arch arm64 --arch x86_64
    # Asked rather than assumed: newer SwiftPM moved universal builds out of .build/apple, and a copy left
    # there by an older toolchain would otherwise be bundled instead.
    BINARY="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/$EXECUTABLE"
else
    swift build -c release --product "$EXECUTABLE"
    BINARY="$(swift build -c release --show-bin-path)/$EXECUTABLE"
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/$EXECUTABLE"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
if [[ -d Generated ]]; then
    ditto Generated "$APP/Contents/Resources/Generated"
else
    echo "Warning: Generated/ is missing; run \"make items\" to bundle the item cards." >&2
fi
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" -c "Set :CFBundleVersion $VERSION" \
    "$APP/Contents/Info.plist"
# Ad-hoc signature: enough to run locally; Gatekeeper still asks on other Macs.
codesign --force --sign - "$APP"
echo "Built $APP ($VERSION)"

if [[ "${1:-}" == "--install" ]]; then
    rm -rf "/Applications/Pawn Shop.app"
    ditto "$APP" "/Applications/Pawn Shop.app"
    # Leave only the installed copy registered, so Finder and Spotlight launch that one.
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
        -u "$APP" 2>/dev/null || true  # Fails when it was never registered, which is fine.
    rm -rf "$APP"
    echo "Installed to /Applications/Pawn Shop.app"
fi
