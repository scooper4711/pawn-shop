#!/usr/bin/env bash
# Puts the Quick Look extensions into a built Mac app and signs them, before the app itself is signed: Finder's
# thumbnail of a sheet and its Quick Look preview (docs/specs/pawn-shop R12). The iPad project builds the same
# sources (Sources/PawnShopThumbnail and Sources/PawnShopPreview) as extensions of its own.
#
# Usage: scripts/add-quicklook-extensions.sh <app> <bin-dir>
#   <app>      the app bundle, whose Info.plist already holds its identifier, version and build number
#   <bin-dir>  where swift build put the PawnShopThumbnail and PawnShopPreview executables
#
# TEAM_ID, SIGNING_IDENTITY and CHANNEL as for scripts/build-app.sh. A Mac App Store build signs the extensions
# with APP_SIGNING_IDENTITY when it is set (the packager re-signs only the app), and needs each extension's Mac App
# Store profile, without which TestFlight refuses the package (ITMS-90889). Without both profiles the package
# leaves the extensions out, with a warning, so the rest still ships:
# THUMBNAIL_PROVISIONING_PROFILE  for io.github.scooper4711.PawnShop.Thumbnail
# PREVIEW_PROVISIONING_PROFILE    for io.github.scooper4711.PawnShop.Preview
# TRIAL=1 builds an App Store package without them, as the packager's trial does.
set -euo pipefail

APP="${1:?app bundle}"
BIN="${2:?directory of the built executables}"
APP_INFO="$APP/Contents/Info.plist"

app_value() { /usr/libexec/PlistBuddy -c "Print :$1" "$APP_INFO"; }

is_store_build() { [[ "${CHANNEL:-}" == "appstore" && "${TRIAL:-0}" != "1" ]]; }

# Usage: add_extension <name> <identifier suffix> <display name> <profile>
add_extension() {
    local name="$1" identifier display="$3" profile="$4"
    identifier="$(app_value CFBundleIdentifier).$2"
    local appex="$APP/Contents/PlugIns/$name.appex"
    rm -rf "$appex"
    mkdir -p "$appex/Contents/MacOS"
    cp "$BIN/$name" "$appex/Contents/MacOS/$name"
    write_info "$appex/Contents/Info.plist" "$name" "$identifier" "$display"
    local entitlements="build/$name.entitlements"
    write_entitlements "$entitlements" "$identifier"
    if is_store_build; then cp "$profile" "$appex/Contents/embedded.provisionprofile"; fi
    sign "$appex" "$entitlements"
}

# The iPad's NSExtension dictionary (ios/<kind>Info.plist), with the keys Xcode adds there written out.
write_info() {
    local plist="$1" name="$2" identifier="$3" display="$4" kind="${2#PawnShop}"
    sed "s/\$(PRODUCT_MODULE_NAME)/$name/" "ios/${kind}Info.plist" > "$plist"
    /usr/libexec/PlistBuddy \
        -c "Add :CFBundleDevelopmentRegion string en" \
        -c "Add :CFBundleDisplayName string $display" \
        -c "Add :CFBundleExecutable string $name" \
        -c "Add :CFBundleIdentifier string $identifier" \
        -c "Add :CFBundleInfoDictionaryVersion string 6.0" \
        -c "Add :CFBundleName string $name" \
        -c "Add :CFBundlePackageType string XPC!" \
        -c "Add :CFBundleShortVersionString string $(app_value CFBundleShortVersionString)" \
        -c "Add :CFBundleVersion string $(app_value CFBundleVersion)" \
        -c "Add :LSMinimumSystemVersion string $(app_value LSMinimumSystemVersion)" \
        -c "Add :NSHumanReadableCopyright string $(app_value NSHumanReadableCopyright 2>/dev/null || echo '')" \
        "$plist"
}

# Sandboxed, reading only the file Quick Look hands them; a store build also names the extension and the team.
write_entitlements() {
    local file="$1" identifier="$2"
    cp Resources/QuickLookExtension.entitlements "$file"
    if is_store_build; then
        : "${TEAM_ID:?TEAM_ID is the developer team}"
        /usr/libexec/PlistBuddy \
            -c "Add :com.apple.application-identifier string $TEAM_ID.$identifier" \
            -c "Add :com.apple.developer.team-identifier string $TEAM_ID" "$file"
    fi
}

sign() {
    if [[ "${CHANNEL:-}" == "appstore" && -n "${APP_SIGNING_IDENTITY:-}" ]]; then
        SIGNING_IDENTITY="$APP_SIGNING_IDENTITY" scripts/sign-app.sh "$1" "$2"
    else
        scripts/sign-app.sh "$1" "$2"
    fi
}

if is_store_build && [[ ! -f "${THUMBNAIL_PROVISIONING_PROFILE:-}" || ! -f "${PREVIEW_PROVISIONING_PROFILE:-}" ]]; then
    # GitHub shows the ::warning:: line on the run's summary.
    echo "::warning::No Mac App Store profiles for the Quick Look extensions: the package leaves them out."
    exit 0
fi
add_extension PawnShopThumbnail Thumbnail "Pawn Shop Thumbnail" "${THUMBNAIL_PROVISIONING_PROFILE:-}"
add_extension PawnShopPreview Preview "Pawn Shop Preview" "${PREVIEW_PROVISIONING_PROFILE:-}"
