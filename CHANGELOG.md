# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Sheets show their pages in Finder and in Quick Look on the Mac
- A link to the 3D-printable pawn bases, in the Help menu on the Mac and in Settings on the iPad
- Turnkeeper can open an encounter's or a scenario's pawns as a new sheet on the Mac
- Art pasted onto a bestiary creature in Turnkeeper is a pawn here, under the creature's name

### Fixed
- Image decks read by an earlier version are read again, so synced Weapons & Armor Deck items are no longer filed
  twice
- Flail and Glaive find their art when text recognition misreads their names
- The large preview opens from the context menu on the iPad and iPhone
- Item Cards settings says why the preview card has no art when no imported deck has any
- Pawn Shop's folder in iCloud Drive shows its icon
- Deleting a custom pawn says plainly what it does
- Paste Image no longer opens the image picker

## [2.1.0] - 2026-11-21

### Added
- Ask before deleting a custom pawn
- Make custom pawns custom creatures
- Show the iCloud Drive folder before the first save
- Offer Pawn Shop's iCloud Drive folder for sheets
- Sign builds for iCloud so the library syncs
- Fetch a pawn's picture when it is first shown
- Start syncing at launch and show it in Settings
- Ask iCloud for pictures a batch at a time
- Sync custom pawns in a zone on the toolkit's engine
- Work out what custom pawns have to sync
- Draw a pawn without its PDF from its saved picture
- Read PDFs again at launch when the reader is newer
- Follow other apps' changes to the shared art library
- Keep pawns in the toolkit's shared art library
- Give pawns the same IDs on every device
- Add the iPad app
- Build the core for the iPad and name paper sizes

### Fixed
- Keep a plain bookmark of Scrollkeeper's folder when a scoped one can't be made
- Keep the window answering while a library syncs in
- Keep asking for a picture while its pawn is on screen
- Wait a minute before asking again for a missing picture
- Draw a tile at once, then ask iCloud for its pictures
- Keep a page's PDF open while its pictures are read
- Read the action icons' font once, one thread at a time
- Pack sheet strips in columns when rows take more pages
- Show the pages, the sheet and Print on the iPhone
- Show the About screen from the iPad's menu bar
- Show the buttons of Rename and other sheets on the iPad

### Changed
- Ignore Xcode's per-user state wherever the project is
- Give the tag storage tests a file of their own
- Specify custom pawns as custom creatures
- Require tabletop-kit 1.12.0
- Describe sheets in iCloud Drive
- Specify Pawn Shop's folder in iCloud Drive
- Update tabletop-kit to 1.11.4
- Wrap the syncing design's long lines
- Name the record coder and how tiles ask for pictures
- Give picture requests time to meet in one round
- Describe syncing, where things are stored and privacy
- Keep a strip's place on the page beside its cut marks
- Time out CI jobs instead of waiting 6 hours
- Specify syncing the library between devices
- Require tabletop-kit 1.11.3
- Require tabletop-kit 1.11.2
- Require tabletop-kit 1.11.1
- Pin the GitHub actions to commit hashes
- Run the tests on the self-hosted Mac mini
- Require tabletop-kit 1.11.0
- Require tabletop-kit 1.10.0
- Require tabletop-kit 1.9.0
- Keep pawns in the toolkit's shared art library
- Require tabletop-kit 1.8.0
- Require tabletop-kit 1.7.0
- Require tabletop-kit 1.6.0
- Require tabletop-kit 1.5.0
- Require tabletop-kit 1.4.1
- Require tabletop-kit 1.4.0
- Drop the AI disclosure rule from CONTRIBUTING
- Specify the iPhone's tabs
- Keep the release checkout to one with block
- Number every build by the commits on main
- Number every build by the commits on main
- Specify About in the iPad's menu bar
- Specify renaming pawns and sheet buttons on the iPad
- Share the app between the Mac and the iPad in PawnShopUI
- Add the iPad app spec

[2.1.0]: https://github.com/scooper4711/pawn-shop/releases/tag/v2.1.0

## [2.0.1] - 2026-11-13

### Fixed
- Show the print dialog after the print options

[2.0.1]: https://github.com/scooper4711/pawn-shop/releases/tag/v2.0.1

## [2.0.0] - 2026-11-13

### Added
- Tag only what the art adds to a pawn's name and traits
- Tagging off by default, with server and model in Settings
- Build Pawn Shop for the Mac App Store without its updater

### Fixed
- Keep the add bar's count clear of the window corner
- Name items and spells in the empty sheet's hint
- Keep the art when hiding a PDF pawn's printed words on macOS 27
- Make the updater check fail when the updater is present
- Build with no extra flags under the CI shell

### Changed
- Say what deleting the app leaves on a Mac
- Say where the review notes live and drop a wrong comment
- Name Pawn Shop's App Store package correctly

[2.0.0]: https://github.com/scooper4711/pawn-shop/releases/tag/v2.0.0

## [1.3.1] - 2026-10-20

[1.3.1]: https://github.com/scooper4711/pawn-shop/releases/tag/v1.3.1

## [1.3.0] - 2026-10-20

### Added
- Run Pawn Shop in the App Sandbox
- Remember the Scrollkeeper folder the user picks

### Fixed
- Switch the bundle ID to io.github.scooper4711.PawnShop
- Accept drags on the empty sheet and carry copies
- Select library tiles at once and add drag-to-sheet
- Bundle the universal binary from where SwiftPM built it

### Changed
- Run the weekly pf2e update off the hour
- Specify running in the App Sandbox
- Specify instant selection and drag-to-add
- Follow pf2e releases weekly, as Field Guide does
- Keep a fingerprint of the imported items in import.sha256
- Build and attach the release disk image on GitHub
- Import items from the pf2e release pinned in pf2e.release

[1.3.0]: https://github.com/scooper4711/pawn-shop/releases/tag/v1.3.0

## [1.2.0] - 2026-10-15

### Added
- Let the user choose the smallest card text size
- Print Starfinder cards light, for inkjet printers
- Add the Spells pane and the card background setting
- Import spells and work out their formulas
- Continue long cards onto more cards and allow plain backgrounds
- Add spell kinds, card labels and traditions to the catalog
- List the bundled licenses in the About panel
- Name the bundled licenses as the About panel titles them
- Show Paizo's notices in the About panel
- Draw item card action icons with Pathfinder-Icons
- Draw item art at 40% opacity by default
- Set how visible item art is in Settings
- Draw item art at an adjustable opacity, 30% by default
- Draw every spell scroll with the deck's first scroll
- Find deck art printed under a misspelled name
- Find deck art printed under an item's name before the remaster
- Import the items the remaster renamed
- Switch the library between pawns and items
- Put item cards on sheets beside pawns
- Draw item cards with their art faint behind the text
- Find an item's art from its deck by name
- Import the items of the pf2e system for item cards
- Search a catalog of Pathfinder and Starfinder items
- Import item decks from Scrollkeeper and dropped folders
- Keep the art of item decks for item cards
- Read imported PDFs again when the reader improves
- Draw pawns printed without outlines upright

### Fixed
- Keep only the last few PDFs and pictures in memory
- Leave Reload off the cards of weapons that need none
- Match deck art named with curly apostrophes
- Keep the card's text inside the parchment's torn edge

### Changed
- Describe the smallest text size setting
- Specify a setting for the smallest card text size
- Specify light Starfinder cards
- Describe spell cards, card sets and plain backgrounds
- Cover spell cards, card sets on sheets and plain backgrounds
- Cover splitting card text over cards
- Update Tabletop Kit to 0.15.0
- Say a spell's trigger opens its text
- Specify spell cards, card sets and plain card backgrounds
- Say the toolkit is Mac apps, two also on the iPad
- Specify the license texts in Pawn Shop's About panel
- Rename the suite the Tableside Toolkit
- List every Society Toolkit app
- Remove the statement about the use of AI
- Show both games' items and an item card in the screenshot
- Retake the README screenshot with the blog-art pawns
- Open the README with the problem Pawn Shop solves
- Show sample pawns made from Paizo blog art
- Specify the About panel's Paizo notices
- Update Artwork to include the Rexard and Community Use art
- Describe the Pathfinder-Icons action font
- Note the private Artwork submodule
- Fetch the Artwork submodule when a key is set
- Add the private Artwork submodule
- Wrap a long expectation in the item import tests
- Build release disk images locally with the item cards
- Snapshot the item browser and item cards in the inspector
- Measure the coverage of every test bundle and the item import
- Depend on Tabletop Kit 0.9.0
- Bundle the item catalog and the cards' Rexard art
- Specify item cards
- Depend on Tabletop Kit 0.2.0
- Describe pawns without outlines and rereading
- Use Tabletop Kit's test PDF drawing
- Use Tabletop Kit's art extraction
- Point the extraction design at Tabletop Kit

[1.2.0]: https://github.com/scooper4711/pawn-shop/releases/tag/v1.2.0

## [1.1.0] - 2026-10-09

### Added
- Show the tagging count only in the progress bar's tooltip
- Turn tagging on and off in Settings and show its progress

### Changed
- Refer to Flip Map Printer by its new name, Mapsmith
- Add the Society Toolkit section to the README
- Describe the tagging switch and progress in the README
- Specify turning tagging off and showing its progress

[1.1.0]: https://github.com/scooper4711/pawn-shop/releases/tag/v1.1.0

## [1.0.0] - 2026-10-09

### Added
- Initial release

[1.0.0]: https://github.com/scooper4711/pawn-shop/releases/tag/v1.0.0
