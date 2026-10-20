# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
