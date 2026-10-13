#!/bin/sh
# Builds Generated/, which the app bundles and the repository leaves out: every Pathfinder and Starfinder item
# from the pf2e system repository, the item cards' art from the user's Rexard packs, and Paizo's
# Pathfinder-Icons font from the private Artwork submodule. None may be published in the repository: the item
# text is used under the ORC and OGL licenses (copied alongside it), the Rexard art only inside the app, and the
# font under the Paizo Compatibility License, which forbids altering or redistributing it.
#
# PF2E_REPO     the pf2e system repository (default ~/git/pf2e)
# ARTWORK       the toolkit-artwork checkout (default the Artwork submodule)
# REXARD_PACKS  the folder holding the user's Rexard UI packs (default ~/git/rexard-packs)
set -eu

cd "$(dirname "$0")/.."

PF2E_REPO="${PF2E_REPO:-$HOME/git/pf2e}"
REXARD_PACKS="${REXARD_PACKS:-$HOME/git/rexard-packs}"
ARTWORK="${ARTWORK:-Artwork}"

mkdir -p Generated

echo "Copying the cards' art from $REXARD_PACKS..."
# Tabletop Kit's tool, built from this package's copy of it.
swift build -c release --product CardArtImport
BIN_PATH="$(swift build -c release --show-bin-path)"
"$BIN_PATH/CardArtImport" "$REXARD_PACKS" Generated/CardArt

echo "Copying the action icon font..."
mkdir -p Generated/Fonts
rm -f Generated/Fonts/pathfinder-2e-actions.woff2
if [ -f "$ARTWORK/pathfinder-icons/Pathfinder-Icons.ttf" ]; then
    cp "$ARTWORK/pathfinder-icons/Pathfinder-Icons.ttf" Generated/Fonts/
else
    echo "Warning: $ARTWORK has no Pathfinder-Icons font (git submodule update --init); cards show the glyphs as text." >&2
fi

echo "Importing the items from $PF2E_REPO..."
swift build -c release --product ItemImport
"$BIN_PATH/ItemImport" --pf2e "$PF2E_REPO" --out Generated
