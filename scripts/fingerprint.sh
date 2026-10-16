#!/bin/sh
# Prints a SHA-256 fingerprint of the imported items (the item list and the remaster renames), which "make items"
# keeps in import.sha256. The weekly pf2e update releases only when a new pf2e release changes it. The cards' art
# and fonts are left out: they come from the Artwork repository, not from pf2e.
set -eu

cd "$(dirname "$0")/../Generated"
find Items -type f -name '*.json' -print0 | LC_ALL=C sort -z | xargs -0 shasum -a 256 | shasum -a 256 | cut -d ' ' -f 1
