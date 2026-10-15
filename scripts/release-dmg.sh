#!/bin/sh
# Builds the universal disk image for the version tag at HEAD and attaches it to that tag's GitHub release,
# creating a draft release if there is none. GitHub's release workflow does this for every tag; this is the
# fallback should that build fail. It needs Generated/ (make items).
set -eu

cd "$(dirname "$0")/.."

[ -d Generated/Items ] || { echo "Releasing failed: Generated/ is missing; run \"make items\" first." >&2; exit 1; }
TAG="$(git describe --tags --exact-match HEAD 2>/dev/null)" \
    || { echo "Releasing failed: HEAD has no version tag." >&2; exit 1; }
VERSION="${TAG#v}"
export VERSION

UNIVERSAL=1 scripts/build-app.sh
scripts/make-dmg.sh

gh release view "$TAG" >/dev/null 2>&1 || gh release create "$TAG" --draft --title "$TAG" --generate-notes
gh release upload "$TAG" "build/Pawn-Shop-$VERSION.dmg" --clobber
