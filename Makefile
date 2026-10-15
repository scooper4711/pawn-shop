.PHONY: build test lint coverage items app run install dmg release-dmg icon clean

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

# Builds the universal disk image for the version tag at HEAD and attaches it to its GitHub release.
release-dmg:
	scripts/release-dmg.sh

# Redraws Resources/AppIcon.icns from scripts/make-icon.swift.
icon:
	scripts/make-icon.sh

clean:
	rm -rf .build build coverage Generated
