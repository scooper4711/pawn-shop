#!/bin/sh
# Builds Generated/, which the app bundles and the repository leaves out: every Pathfinder and Starfinder item
# from the pf2e system repository with its action icon font, and the item cards' art from the user's Rexard
# packs. Neither may be
# published in the repository: the item text is used under the ORC and OGL licenses (copied alongside it), and
# the Rexard art only inside the app.
#
# PF2E_REPO     the pf2e system repository (default ~/git/pf2e)
# REXARD_PACKS  the folder holding the user's Rexard UI packs (default ~/git/rexard-packs)
set -eu

cd "$(dirname "$0")/.."

PF2E_REPO="${PF2E_REPO:-$HOME/git/pf2e}"
REXARD_PACKS="${REXARD_PACKS:-$HOME/git/rexard-packs}"

mkdir -p Generated

echo "Copying the cards' art from $REXARD_PACKS..."
# Tabletop Kit's tool, built from this package's copy of it.
swift build -c release --product CardArtImport
BIN_PATH="$(swift build -c release --show-bin-path)"
"$BIN_PATH/CardArtImport" "$REXARD_PACKS" Generated/CardArt

echo "Copying the action icon font..."
mkdir -p Generated/Fonts
cp "$PF2E_REPO/static/fonts/pathfinder-2e-actions.woff2" Generated/Fonts/

echo "Importing the items from $PF2E_REPO..."
swift build -c release --product ItemImport
"$BIN_PATH/ItemImport" --pf2e "$PF2E_REPO" --out Generated
