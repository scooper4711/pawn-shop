#!/usr/bin/env bash
# Build "Pawn Shop.app" into build/ (release configuration, ad-hoc signed).
# Usage: scripts-build/bundle.sh [--install]   (--install moves it to /Applications)
set -euo pipefail

cd "$(dirname "$0")/.."
APP="build/Pawn Shop.app"

swift build -c release --product PawnShop
BIN="$(swift build -c release --show-bin-path)/PawnShop"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/PawnShop"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP"
echo "Built $APP"

if [[ "${1:-}" == "--install" ]]; then
    rm -rf "/Applications/Pawn Shop.app"
    cp -R "$APP" /Applications/
    # Leave only the installed copy registered, so Finder and Spotlight launch that one.
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
        -u "$APP"
    rm -rf "$APP"
    echo "Installed to /Applications/Pawn Shop.app"
fi
