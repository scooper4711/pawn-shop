#!/bin/sh
# Packages the built app into build/Pawn-Shop-<VERSION>.dmg, with the 3D-printable pawn bases beside it.
set -eu

cd "$(dirname "$0")/.."

VERSION="${VERSION:-0.0.0}"
APP="build/Pawn Shop.app"
STAGING="build/dmg"
DMG="build/Pawn-Shop-$VERSION.dmg"

[ -d "$APP" ] || { echo "Making the disk image failed: $APP has not been built." >&2; exit 1; }

rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
# The bases' sources and ready-made STL files; the scripts that rebuild them stay in the repository.
mkdir -p "$STAGING/Pawn Bases"
cp -R pawn-bases/README.md pawn-bases/pawn_base.scad pawn-bases/slot_test.scad pawn-bases/stl "$STAGING/Pawn Bases/"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "Pawn Shop" -srcfolder "$STAGING" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGING"
echo "Built $DMG"
