#!/bin/sh
# Gives a Mac build Pawn Shop's folder in iCloud Drive (docs/specs/pawn-shop R11.5): adds iCloud Documents with
# Pawn Shop's container to the entitlements to sign with, next to the CloudKit ones tabletop-kit's
# add-icloud-entitlements.sh added. Only when the provisioning profile allows the container: macOS stops an app
# that claims an entitlement its profile lacks, and a profile made before the container was added won't have it.
# Run after add-icloud-entitlements.sh; it can run again on the same file.
#
# Usage: scripts/add-icloud-documents.sh <entitlements> <provisioning profile>
# The profile may also be its decoded property list (security cms -D -i <profile>).
set -eu

CONTAINER="iCloud.io.github.scooper4711.PawnShop"
UBIQUITY="com.apple.developer.ubiquity-container-identifiers"

if [ $# -ne 2 ]; then
    echo "Usage: $0 <entitlements> <provisioning profile>" >&2
    exit 2
fi
ENTITLEMENTS="$1"
PROFILE="$2"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
DECODED="$WORK/profile.plist"
if ! security cms -D -i "$PROFILE" > "$DECODED" 2>/dev/null || ! plutil -lint -s "$DECODED"; then
    cp "$PROFILE" "$DECODED"
fi

# Whether the profile's entitlements allow the container for iCloud Documents, by name or by a wildcard.
profile_allows_container() {
    INDEX=0
    while VALUE="$(/usr/libexec/PlistBuddy -c "Print :Entitlements:$UBIQUITY:$INDEX" "$DECODED" 2>/dev/null)"; do
        case "$VALUE" in
            "$CONTAINER" | *"*") return 0 ;;
        esac
        INDEX=$((INDEX + 1))
    done
    return 1
}

# Adds a string to an array of the entitlements unless it is there, creating the array when it is missing.
add_to_array() {
    /usr/libexec/PlistBuddy -c "Print :$1" "$ENTITLEMENTS" >/dev/null 2>&1 \
        || /usr/libexec/PlistBuddy -c "Add :$1 array" "$ENTITLEMENTS"
    if ! /usr/libexec/PlistBuddy -c "Print :$1" "$ENTITLEMENTS" | grep -q -x "    $2"; then
        /usr/libexec/PlistBuddy -c "Add :$1: string $2" "$ENTITLEMENTS"
    fi
}

# Puts a string first in an array of the entitlements, moving it there when it is already listed. Pawn Shop's own
# container comes before the suite's, as in the iPad app: iCloud Drive draws the folder with the app's icon only then.
put_first_in_array() {
    add_to_array "$1" "$2"
    INDEX=0
    while VALUE="$(/usr/libexec/PlistBuddy -c "Print :$1:$INDEX" "$ENTITLEMENTS" 2>/dev/null)"; do
        if [ "$VALUE" = "$2" ]; then
            /usr/libexec/PlistBuddy -c "Delete :$1:$INDEX" -c "Add :$1:0 string $2" "$ENTITLEMENTS"
            return
        fi
        INDEX=$((INDEX + 1))
    done
}

if ! profile_allows_container; then
    echo "Left out iCloud Drive: the provisioning profile doesn't allow $CONTAINER."
    exit 0
fi
add_to_array com.apple.developer.icloud-services CloudDocuments
put_first_in_array com.apple.developer.icloud-container-identifiers "$CONTAINER"
add_to_array "$UBIQUITY" "$CONTAINER"
echo "Added iCloud Drive ($CONTAINER)"
