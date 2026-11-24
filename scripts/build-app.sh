#!/usr/bin/env bash
# Builds "build/Pawn Shop.app" from the Swift package (release configuration).
#
# Usage: scripts/build-app.sh [--install]   (--install moves it to /Applications)
#
# VERSION    version written to the bundle (default: scripts/version.sh marketing)
# UNIVERSAL  set to 1 to build for both Apple silicon and Intel
# TEAM_ID    the team that owns the App Group (default: read from the Developer ID certificate)
# SIGNING_IDENTITY  passed to scripts/sign-app.sh; "-" signs ad hoc, without the App Group
# PROVISIONING_PROFILE  Developer ID provisioning profile with iCloud; with a team, the app syncs its library
#            through iCloud (tabletop-kit's scripts/add-icloud-entitlements.sh, which ICLOUD_ENVIRONMENT also
#            affects; ICLOUD_ENTITLER names another copy), and, when the profile allows Pawn Shop's container,
#            keeps sheets in its iCloud Drive folder (scripts/add-icloud-documents.sh). Without it the library
#            stays on the Mac.
# THUMBNAIL_PROVISIONING_PROFILE, PREVIEW_PROVISIONING_PROFILE  the Quick Look extensions' Mac App Store profiles,
#            which CHANNEL=appstore needs (scripts/add-quicklook-extensions.sh)
# BUILD_NUMBER  CFBundleVersion, which must increase with every App Store upload (default: scripts/version.sh build)
# CHANNEL    "appstore" builds the Mac App Store package, build/appstore/Pawn Shop.pkg, from the same
#            sources, compiled with -DAPP_STORE so the updater is left out; needs TEAM_ID and the variables of
#            tabletop-kit's scripts/package-appstore.sh (PACKAGER names another copy; TRIAL=1 checks it without
#            them). PROVISIONING_PROFILE is then the Mac App Store profile, with iCloud.
set -euo pipefail

cd "$(dirname "$0")/.."
VERSION="${VERSION:-$(scripts/version.sh marketing)}"
BUILD_NUMBER="${BUILD_NUMBER:-$(scripts/version.sh build)}"
APP="build/Pawn Shop.app"
EXECUTABLE="PawnShop"

SWIFT_FLAGS=()
[[ "${CHANNEL:-}" == "appstore" ]] && SWIFT_FLAGS=(-Xswiftc -DAPP_STORE)

ARCHS=()
[[ "${UNIVERSAL:-0}" == "1" ]] && ARCHS=(--arch arm64 --arch x86_64)
# The app and its Quick Look extensions (scripts/add-quicklook-extensions.sh).
for product in "$EXECUTABLE" PawnShopThumbnail PawnShopPreview; do
    swift build -c release ${SWIFT_FLAGS[@]+"${SWIFT_FLAGS[@]}"} --product "$product" ${ARCHS[@]+"${ARCHS[@]}"}
done
# Asked rather than assumed: newer SwiftPM moved universal builds out of .build/apple, and a copy left there by an
# older toolchain would otherwise be bundled instead.
BIN_DIR="$(swift build -c release ${ARCHS[@]+"${ARCHS[@]}"} --show-bin-path)"
BINARY="$BIN_DIR/$EXECUTABLE"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/$EXECUTABLE"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp Resources/container-migration.plist "$APP/Contents/Resources/container-migration.plist"
if [[ -d Generated ]]; then
    ditto Generated "$APP/Contents/Resources/Generated"
else
    echo "Warning: Generated/ is missing; run \"make items\" to bundle the item cards." >&2
fi
cp ios/App/PrivacyInfo.xcprivacy "$APP/Contents/Resources/PrivacyInfo.xcprivacy"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" \
    -c "Set :CFBundleVersion $BUILD_NUMBER" "$APP/Contents/Info.plist"
# The entitlements turn on the App Sandbox. A build signed with the team's Developer ID also joins the Tableside
# Toolkit's App Group, where Scrollkeeper keeps its downloads: the team's ID takes the place of TEAM_ID. The team ID
# is read from the signing certificate, or from TEAM_ID in the environment. An ad hoc
# signature can't join the group, so its build leaves the group out and asks for Scrollkeeper's folder instead.
ENTITLEMENTS="build/PawnShop.entitlements"
if [[ "${SIGNING_IDENTITY:-}" != "-" ]]; then
    TEAM_ID="${TEAM_ID:-$(security find-identity -v -p codesigning \
        | sed -n 's/.*"Developer ID Application: .*(\([A-Z0-9]*\))"$/\1/p' | head -n 1)}"
fi
if [[ -n "${TEAM_ID:-}" ]]; then
    sed "s/TEAM_ID/$TEAM_ID/" Resources/PawnShop.entitlements > "$ENTITLEMENTS"
else
    cp Resources/PawnShop.entitlements "$ENTITLEMENTS"
    /usr/libexec/PlistBuddy -c "Delete :com.apple.security.application-groups" "$ENTITLEMENTS"
fi
if [[ "${CHANNEL:-}" == "appstore" ]]; then
    # Only the updater saves into Downloads, and the App Store build has none (review asks what each is for).
    /usr/libexec/PlistBuddy -c "Delete :com.apple.security.files.downloads.read-write" "$ENTITLEMENTS"
fi
# With a provisioning profile that allows iCloud, the app joins the toolkit's container and names it in its
# Info.plist, which turns syncing on (docs/specs/pawn-shop R10.10); an ad hoc signature can't carry them. The script
# is found beside the package after the build above resolved it, so it follows the dependency pin.
if [[ -n "${TEAM_ID:-}" && -n "${PROVISIONING_PROFILE:-}" && "${SIGNING_IDENTITY:-}" != "-" ]]; then
    "${ICLOUD_ENTITLER:-.build/checkouts/tabletop-kit/scripts/add-icloud-entitlements.sh}" "$APP" "$ENTITLEMENTS" \
        "$TEAM_ID" "$PROVISIONING_PROFILE"
    # Pawn Shop's folder in iCloud Drive, when the profile allows its container (R11.5).
    scripts/add-icloud-documents.sh "$ENTITLEMENTS" "$PROVISIONING_PROFILE"
fi
scripts/add-quicklook-extensions.sh "$APP" "$BIN_DIR"
scripts/sign-app.sh "$APP" "$ENTITLEMENTS"
echo "Built $APP ($VERSION, build $BUILD_NUMBER)"

if [[ "${CHANNEL:-}" == "appstore" ]]; then
    # The App Store build must not update itself (guideline 2.4.5(vii)).
    # grep reads the binary itself: piped from strings, grep -q leaving early fails the pipeline under pipefail.
    if grep -q -a -E "AppUpdater|api\.github\.com" "$APP/Contents/MacOS/$EXECUTABLE"; then
        echo "The App Store build still contains the updater." >&2
        exit 1
    fi
    # Found beside the package after "swift package resolve", so the script follows the dependency pin.
    "${PACKAGER:-.build/checkouts/tabletop-kit/scripts/package-appstore.sh}" "$APP" "$ENTITLEMENTS" \
        io.github.scooper4711.PawnShop
fi

if [[ "${1:-}" == "--install" ]]; then
    rm -rf "/Applications/Pawn Shop.app"
    ditto "$APP" "/Applications/Pawn Shop.app"
    # Leave only the installed copy registered, so Finder and Spotlight launch that one.
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
        -u "$APP" 2>/dev/null || true  # Fails when it was never registered, which is fine.
    rm -rf "$APP"
    echo "Installed to /Applications/Pawn Shop.app"
fi
