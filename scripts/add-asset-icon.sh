#!/usr/bin/env bash
# Compiles a built Mac app's AppIcon.icns into an asset catalog (Contents/Resources/Assets.car) and names it in the
# Info.plist (CFBundleIconName), as Xcode does. iCloud Drive draws Pawn Shop's folder with the icon of the build that
# last published the container's metadata (QA1893), and a build with only the .icns left the folder without one.
# tabletop-kit's package-appstore.sh does the same for the App Store package, which App Store Connect requires.
#
# Usage: scripts/add-asset-icon.sh <app>
set -euo pipefail

APP="${1:?app bundle}"
RESOURCES="$(cd "$APP/Contents/Resources" && pwd)"
INFO="$APP/Contents/Info.plist"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

fail() { echo "add-asset-icon: $*" >&2; exit 1; }

# The iconutil sizes (icon_16x16.png, icon_16x16@2x.png, …) as an appiconset's Contents.json lists them.
write_icon_set() {
    local iconset="$1" images="" file size scale
    for file in "$iconset"/icon_*.png; do
        file="$(basename "$file")"
        size="${file#icon_}"; size="${size%%[@.]*}"
        scale="1x"; [[ "$file" == *@2x.png ]] && scale="2x"
        images+="{\"filename\":\"$file\",\"idiom\":\"mac\",\"scale\":\"$scale\",\"size\":\"$size\"},"
    done
    echo "{\"images\":[${images%,}],\"info\":{\"version\":1,\"author\":\"xcode\"}}" > "$iconset/Contents.json"
}

catalog="$WORK/Icons.xcassets"
iconset="$catalog/AppIcon.appiconset"
mkdir -p "$iconset"
iconutil -c iconset "$RESOURCES/AppIcon.icns" -o "$WORK/AppIcon.iconset"
cp "$WORK"/AppIcon.iconset/*.png "$iconset/"
write_icon_set "$iconset"
echo '{"info":{"version":1,"author":"xcode"}}' > "$catalog/Contents.json"
target="$(/usr/libexec/PlistBuddy -c "Print :LSMinimumSystemVersion" "$INFO")"
# actool exits 0 when it fails, so look for what it should have written.
xcrun actool "$catalog" --compile "$RESOURCES" --platform macosx --minimum-deployment-target "$target" \
    --app-icon AppIcon --output-partial-info-plist "$WORK/partial.plist" > "$WORK/actool.log" 2>&1 || true
[[ -f "$RESOURCES/Assets.car" ]] || { cat "$WORK/actool.log" >&2; fail "actool didn't compile the icon"; }
name="$(/usr/libexec/PlistBuddy -c "Print :CFBundleIconName" "$WORK/partial.plist" 2>/dev/null)" \
    || fail "actool didn't name the icon"
/usr/libexec/PlistBuddy -c "Delete :CFBundleIconName" "$INFO" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleIconName string $name" "$INFO"
