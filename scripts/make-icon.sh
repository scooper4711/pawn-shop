#!/usr/bin/env bash
# Regenerate Resources/AppIcon.icns and the iPad's icon from scripts/make-icon.swift.
set -euo pipefail

cd "$(dirname "$0")/.."
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

swift scripts/make-icon.swift "$WORK/icon-1024.png"
ICONSET="$WORK/AppIcon.iconset"
mkdir "$ICONSET"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$WORK/icon-1024.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z "$double" "$double" "$WORK/icon-1024.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o Resources/AppIcon.icns
echo "Wrote Resources/AppIcon.icns"

IPAD_ICON=ios/App/Assets.xcassets/AppIcon.appiconset/icon-1024.png
swift scripts/make-icon.swift --full-bleed "$IPAD_ICON"
echo "Wrote $IPAD_ICON"
