#!/bin/sh
# Fetches the pf2e release named in pf2e.release from the official repository into DIR (default build/pf2e),
# so every import, here or on GitHub, reads the same data. Only that one commit is downloaded, and nothing is
# fetched when DIR already holds it.
#
# Usage: scripts/fetch-pf2e.sh [DIR]
set -eu

cd "$(dirname "$0")/.."

DIR="${1:-build/pf2e}"
COMMIT="$(cut -d ' ' -f 1 pf2e.release)"

if [ "$(git -C "$DIR" rev-parse HEAD 2>/dev/null)" = "$COMMIT" ]; then
    exit 0
fi
echo "Fetching pf2e $(cut -d ' ' -f 2- pf2e.release) into $DIR..."
rm -rf "$DIR"
mkdir -p "$DIR"
git -C "$DIR" init --quiet
git -C "$DIR" fetch --quiet --depth 1 https://github.com/foundryvtt/pf2e.git "$COMMIT"
git -C "$DIR" -c advice.detachedHead=false checkout --quiet FETCH_HEAD
