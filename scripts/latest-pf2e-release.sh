#!/bin/sh
# Prints the newest release of the pf2e and sf2e systems in foundryvtt/pf2e as "<commit> <tag> [<tag>]": the
# commit and every system release tag on it (both systems are usually released together). Needs gh.
set -eu

TAGS="$(gh release list -R foundryvtt/pf2e --exclude-drafts --exclude-pre-releases --limit 30 \
    --json tagName,publishedAt \
    --jq '[.[] | select(.tagName | test("^(pf2e|sf2e)-[0-9]"))] | sort_by(.publishedAt) | reverse | .[:2] | .[].tagName')"
NEWEST="$(echo "$TAGS" | head -1)"
COMMIT="$(gh api "repos/foundryvtt/pf2e/commits/$NEWEST" --jq .sha)"
LINE="$COMMIT $NEWEST"
OTHER="$(echo "$TAGS" | sed -n 2p)"
if [ -n "$OTHER" ] && [ "$(gh api "repos/foundryvtt/pf2e/commits/$OTHER" --jq .sha)" = "$COMMIT" ]; then
    LINE="$COMMIT $OTHER $NEWEST"
fi
echo "$LINE"
