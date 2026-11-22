.PHONY: build test lint coverage items app run install dmg appstore icon ipad-install ipad-simulator ipad-uitests clean

build:
	swift build

test:
	swift test

lint:
	swiftlint --strict --quiet

# Runs the tests and fails when PawnShopCore's line or region coverage is below 80%.
coverage:
	scripts/coverage.sh

# Builds Generated/ (the item catalog and the item cards' art) from pf2e.release and the Rexard packs.
items:
	scripts/import-items.sh

app:
	scripts/build-app.sh

run: app
	open "build/Pawn Shop.app"

# Builds the app and moves it to /Applications, replacing an earlier copy.
install:
	scripts/build-app.sh --install

dmg: app
	scripts/make-dmg.sh

# Builds the Mac App Store package, build/appstore/Pawn Shop.pkg (see scripts/build-app.sh for the variables).
appstore:
	swift package resolve
	CHANNEL=appstore scripts/build-app.sh

# Redraws Resources/AppIcon.icns and the iPad's icon from scripts/make-icon.swift.
icon:
	scripts/make-icon.sh

# Builds the iPad app and installs it on a connected iPad. IPAD names the iPad.
ipad-install:
	scripts/install-ipad.sh

# Builds the iPad app and starts it in a simulator. IPAD_SIMULATOR names the simulator.
ipad-simulator:
	scripts/run-ipad-simulator.sh

# Runs the iPad UI tests, which screenshot the window in both orientations.
ipad-uitests:
	scripts/run-ipad-uitests.sh

# Archives the app for the App Store and exports build/ipad/export/*.ipa, versioned from git. Upload it with
# `make testflight`.
.PHONY: ipad-archive testflight
ipad-archive:
	.build/checkouts/tabletop-kit/scripts/archive-ios.sh ios/PawnShop.xcodeproj PawnShop-iPad build/ipad

# Uploads the newest build (the .ipa from ipad-archive or the .pkg from appstore) to TestFlight, with this release's
# notes from the tableside-store checkout next to this repository (TABLESIDE_STORE).
TABLESIDE_STORE ?= ../tableside-store
TESTFLIGHT_NOTES = $(TABLESIDE_STORE)/pawn-shop/testflight/what-to-test.txt
TESTFLIGHT_BUILD ?= $(shell ls -t build/ipad/export/*.ipa build/appstore/*.pkg 2>/dev/null | head -n 1)
testflight:
	@test -f "$(TESTFLIGHT_NOTES)" || { echo "testflight failed: $(TESTFLIGHT_NOTES) not found; set TABLESIDE_STORE"; exit 1; }
	@test -n "$(TESTFLIGHT_BUILD)" || { echo "testflight failed: no build; run make ipad-archive or make appstore"; exit 1; }
	.build/checkouts/tabletop-kit/scripts/testflight.sh io.github.scooper4711.PawnShop "$(TESTFLIGHT_BUILD)" "$(TESTFLIGHT_NOTES)"

clean:
	rm -rf .build build coverage Generated ios/build
