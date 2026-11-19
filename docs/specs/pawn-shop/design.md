# Pawn Shop: design

A SwiftPM macOS app in the style of Mapsmith: `PawnShopCore` holds all logic and is unit tested;
`PawnShop` is a thin SwiftUI/AppKit layer; `scripts/build-app.sh` builds `Pawn Shop.app`.

## Reading the PDFs
Finding pawns, tokens and Battle Cards creatures in Paizo's PDFs, and the measurements it relies on, are in
[Tabletop Kit](https://github.com/scooper4711/tabletop-kit) (`ArtExtraction`), described in its spec
(`docs/specs/tabletop-kit/design.md`). Pawn Shop's library uses its figures to compare paintings (below).

## Library (`PawnShopCore/Library`)
Pawns read from PDFs live in tabletop-kit's shared art library (`SharedLibraries`, its
`docs/specs/shared-libraries/`), which Turnkeeper and Field Guide read and write too. `PawnLibrary` keeps its API and
is a view over it, so the app above it changes little.

- **Where.** `SharedLibrary.standard(app: .pawnShop, fallback:)`: `Tableside/` in the App Group, or the library
  folder outside it (tests, `PAWN_SHOP_LIBRARY`). The store keeps the PDFs (`Sources/<sha256>.pdf`), each entry's
  picture and tokens' and drawn items' pictures (`Pictures/`), in `Library.sqlite`. Pawn Shop's own folder
  (`~/Library/Application Support/Pawn Shop/`, in the container) keeps `Custom/` (custom pawns' art) and
  `pawn-shop.json` (`OwnLibrary`: the custom pawns, and the IDs of pawns removed from Pawn Shop only).
- **Pawns** (`SharedPawns.swift`). Each creature entry (not an item) becomes a `Pawn`: its ID, size, traits,
  fingerprint and `needsName`; `appearances` from its prints (one per source, with copies, the drawn print's first).
  Its note (`ArtNote`) gives the name the user chose (`userName`, else the entry's name), tags, tag model,
  suggested name and `tagsCorrected` (`isCorrected`); a pawn needs a name while the entry does and no `userName` is
  set. `art` comes from the print it is drawn from, the sharpest Pawn Shop can reach: a figure (`.card`, from a
  Battle Card), else a pawn print (`.pdf` with its back, or the front mirrored), else a token (`.token`, its
  pictures in `Pictures/`). Without a reachable PDF, a pawn is drawn from the entry's picture (`.picture`,
  R2.1.2), as a card's creature is. Item entries become `ItemArtwork` the same way (`.figure` or `.drawn`).
- **Sources.** `PawnSource` from `SharedSource`: id, title, byte count, art found and reader version; the
  original path is the PDF's location for Pawn Shop when it has one. Only sources with pawns or items are listed.
- **Writing.** `rename`, `correctTags`, `setTags` and `setSuggestedName` write the pawn's note
  (`setNote(_:forArt:)`, which finds the art by any of its IDs). Custom pawns (`add`, `update`, `addCustomPawn`)
  and removals save `pawn-shop.json`; removing a pawn read from a PDF records its ID there and hides it.
- **Importing.** `prepareImport(of:)` is `ArtLibrary.prepare` (off the main thread); `commit(_:)` is the store's
  `commit(_:location: .kept)`, which claims the PDF, keys and merges its art (by key, then the same name and
  fingerprint or palette, then nameless art's rules: shared libraries R2.3a) and draws new pictures. Its
  `ArtImportReport` becomes an `ImportReport`; the outlines with no name printed come from the extraction.
  `hasImported` is the store's `contains`, unless the source was read by an older reader.
- **Reading again** (`ReadingAgain.swift`, R1.7). At launch `LibraryModel` reads again, in the background with
  progress, each PDF whose `readerVersion` is below `PawnExtractor.version`: from the path it was imported from
  (`OwnLibrary.importedFiles`, and `readAgain` for PDFs moved in), where that can be read, pawn PDFs before Battle
  Cards. It never reads the library's own copy: of a deck in two PDFs that is the art alone, and read without its
  stat blocks the deck's creatures would be taken out. `commitReadAgain` refuses a reading that finds nothing
  where the last one found art, and the summary says so. A PDF whose file can't be reached waits; a PDF another
  app took out of the library is not read.
- **Following changes** (R2.1). `LibraryModel` observes `SharedLibraryChange` and calls `refresh()`, which reads
  `changes(since:)` the last counter it saw: changed entries and notes are read again
  (`artEntries(changedSince:)`, `notes(changedSince:)`) and deleted art dropped, so a change doesn't read the
  whole library. On the iPad the app calls `close()` when it goes to the background (shared libraries R5.4).
- **Pawn IDs** (R2.14) are the store's: an entry's ID is its first print's `ArtKey`, pawns first, and any print
  key or alias finds it (`artEntry(id:)`), so sheets saved with an old ID still open (`labeled`). Before the move a
  version 1 library is still keyed in place first (`PawnKeys.swift`, R2.15), as below.
  - Version 1 libraries (`rekeyPawns`, R2.15): each extracted pawn is keyed from its art's source, its
    fingerprint, its front face, and its name, empty when the pawn needs a name or its first product is nameless,
    so a name it took later doesn't count. Pawns sharing a key merge into the first (products and traits); every
    old ID becomes an alias. On a copy of the real library (9,848 pawns, 78 custom, 4 without pictures, on
    flattened pages, keyed by place), one pair merged, and every pawn on the sheets saved with it was found
    (`RealLibraryUpgradeTests`, run when `TestData/library-v1.json` is there).
- **The move** (`LibraryMoving.swift`, `PawnShopMove.swift`, R2.16). At launch, while `library.json` exists and the
  store hasn't recorded Pawn Shop's move as finished, `PawnLibrary` reads it (keying a version 1 file first) and
  calls `moveIn` with a `LibraryMove`: each extracted pawn as keyed art (`keyedArt`) with one print, its ID as the
  key, from its art (a pawn's faces, a card's face and image index, a token's pictures renamed `<id>.png` and
  `<id>-back.png`); item art keyed by `ArtKey` as an import keys it, a drawn item's picture renamed `<key>.png`; the
  sources (`keyedSources`), kept when their PDF is, else referenced where they were imported from, a file that is
  gone as a reference that never resolves, so it is listed as missing; `aliases`; a note per pawn with its tags,
  tag model, suggested name and corrections; the kept PDFs (`keptPDFs`) and token and item pictures
  (`pictureFiles`). The name is the pawn's current one (the printed name isn't recorded). Art from a product
  printing no names keeps its stand-in name and `needsName`, and a name the user gave it is the note's
  `userName`. Custom pawns and the imported files' paths, sizes and digests go to `pawn-shop.json`, then
  `library.json` becomes `library.json.moved`.
  - A version 2 library records the faces of a pawn's first product only: 2,710 other prints in 65 of the 85
    PDFs have none. The sources of every pawn printed by more than one product move in with reader version 0 and
    are listed in `pawn-shop.json` (`readAgain`) with their original files. `LibraryModel` reads those again in
    the background, from Scrollkeeper's folder, pawn PDFs before Battle Cards (`filesToReadAgain`), like an
    import but telling only of failures; a file it can't reach is read again at the next Import from
    Scrollkeeper, which counts a source read by an older reader as not imported. A kept copy can't be read
    instead: a Battle Cards deck or a deck of pictures is recognized by its files' names. Each print then joins
    its pawn by key, or by name and fingerprint or colors as on any import, and the pawn lists every product
    again; a pawn whose ID was its art's other print's key keeps its note through the store's `retire`.
  - On the real library (`RealLibraryUpgradeTests`) the move takes about 5 seconds in a debug build; every
    pawn is found by its old ID, its tags and corrections and the names given to nameless art are kept, and the
    saved sheets open.
  - A move cut short finishes at the next launch (the store records its rows first, and moves files it hasn't).
  - `search(_:)`: every word must appear (case- and diacritic-insensitive) in the name, a product title, a
    trait or a tag;
    filters by size, game, product and custom; ordered by name, then product, so same-name art sits together.
- `ScrollkeeperScanner` lists PDFs under Scrollkeeper's Files folder whose name contains "pawn" or "token", and
  each Battle Cards deck once, as its art PDF (`PawnLibrary.importableFiles`).
- `ScrollkeeperFolder` finds that folder (R1.2). First the App Group: tabletop-kit's `TablesideShared` gives
  Scrollkeeper's folder there (`ToolkitGroup.scrollkeeperFolder()`), and its library list
  (`ScrollkeeperLibrary.read(from:)`) says whether the downloads are in its `Files`
  (`downloadFolderURL(in:)`); without a list Pawn Shop can read, `Files` is used when it holds anything. Then a
  folder the user picked, from a security-scoped bookmark in the defaults, accessed until the app quits; then
  Scrollkeeper's old folder when it can be listed, which is only outside the sandbox. `defaultLocation` is in the
  user's real home folder (`getpwuid`), as the sandbox gives the app its container instead. When none is
  readable, `LibraryModel` shows a folder picker starting at `suggestedLocation` (the folder the user chose in
  Scrollkeeper, from its list, else `defaultLocation`) and remembers the choice. When it finds nothing to import it
  names the folder with tabletop-kit's `FolderName` ("Scrollkeeper · On this Mac"), not its path. Because importing copies the art, the folder is only needed while importing.
- Importing all 61 PDFs takes about 25 seconds (release build); about 420 pawns merge across products, such as
  Monster Core reusing Bestiary art.

## Sheets and layout (`PawnShopCore/Sheet`)
- `PawnSheet` (Codable, the `.pawnsheet` document): entries (pawn id, count, and `label`, tabletop-kit's
  `ArtReference`: id, name and product title, for a device without the pawn; adding a pawn again adds to its
  entry) and `SheetSettings`: cut style (`.sharedLines` or `.gaps(points)`, default gap 0.1"), show fold line,
  and `PaperSetup` (paper size and imageable rect; Letter with ¼" margins by default).
- A pawn prints as a strip of `w × 2(h + r)`: the front face in the lower half, the back face rotated 180° in
  the upper half, heads meeting at the fold, each above `r`, the blank room for a base (`SheetSettings.footRoom`:
  `baseRoom` when `leavesRoomForBase`, else 0; `defaultBaseRoom` is the 6 mm `slot_depth` of
  `pawn_base.scad`, which a test checks). Sheets saved without these settings read as leaving no room. Folding over a horizontal line and viewing from behind is a 180°
  rotation, so the back reads upright, and because Paizo's back art is already mirrored the silhouettes match.
- `SheetLayout.arrange(_:settings:)` is shelf packing: strips sorted tallest first (then widest, then sheet
  order), placed left to right in rows from the top, rows top to bottom, new pages as needed, separated by the
  gap (none with shared cut lines). It packs once with strips upright and once on their side (foot left, head
  right) and keeps whichever needs fewer pages, upright on a tie: on Letter, sideways fits 18 medium strips a
  page against 14 upright. A strip that fits only the other way is turned. Gargantuan custom pawns are
  288×360 so their 10" strip fits on Letter.
- `PawnRenderer` (keeps opened PDFs and images) draws a face: the source PDF page clipped to the face rect
  and turned upright (vector text and full-resolution art kept), or a custom image covering the outline around
  its focus point, mirrored for the back, with the name in a band at the foot, or a token's picture cut round
  as large as fits above the name band, on white (the front mirrored for the back when it has no back
  picture), or a card's creature (`PawnRenderer+Cards`) as large as fits above the name band, centered and
  standing on it, drawn from its image in the kept PDF through the page's transform and clipped to its bounds,
  so a printed sheet embeds the full-resolution picture. `NameLayout` fits the name: one line at full size
  (60% of a 13% band) if it fits 92% of the width, else two lines at that size (the band grows), and only then
  smaller type, down to 3 pt. It draws strips with a hairline
  gray cut outline and a dashed fold line, a gray placeholder for a missing pawn, and face thumbnails.
- `PawnLibrary.labeled(_:)` points each pawn entry the library finds at the pawn's own ID, not an alias, and
  labels it; `SheetWindow` applies it whenever the entries change, and when the sheet opens, writing only when
  something changed so an up-to-date sheet isn't marked as edited. A missing pawn's placeholder and inspector row
  show `SheetEntry.missingDescription`.
- `SheetExporter` (sheet, library, renderer) builds the layout items (a missing pawn takes a medium strip),
  the layout, each page's drawing (shared by preview and print), and the PDF at 100% scale.

## Items (`PawnShopCore/Items`, `ItemImport`)
- `scripts/import-items.sh` (`make items`) fills the git-ignored `Generated/` from `PF2E_REPO` (default
  the release in `pf2e.release`, fetched into `build/pf2e` by `scripts/fetch-pf2e.sh`, as Field Guide does) and `REXARD_PACKS` (default `~/git/rexard-packs`): Tabletop Kit's `CardArtImport` copies the
  card pieces (`CardArtPieces.manifest`) to `Generated/CardArt`, the action icon font is copied to
  `Generated/Fonts`, and the `ItemImport` executable writes
  `Generated/Items/items.json`, an import report and the ORC and OGL licenses (`Items/Licenses`).
  `build-app.sh` copies `Generated/` into the bundle's resources when it exists; `PAWN_SHOP_GENERATED` points
  a build run from the command line at another copy (`GeneratedResources`).
- `ItemImport` (a thin executable over the `ItemCatalogImport` library, which the coverage gate includes) reads
  the `equipment` packs of both games (Tabletop Kit's `PackScanner` and `JSONValue`), leaving out virtual and
  bestiary-only items. Descriptions lose their tables (stats and variants the card has no room for), have
  `@item` formulas worked out from the item's data, and go through `RulesTextConverter` and back to plain text
  (`StatBlockText.plainText`): `**bold**`, `*italic*`, `---` rules, and ◆ ◆◆ ◆◆◆ ⤾ ◇ for actions, so the app
  doesn't need Tabletop Kit's Bestiary. Cards set those glyphs as Paizo's action icons in the Pathfinder-Icons
  font (Paizo Compatibility License), using its private-use code points U+E900 to U+E904, the same as Tabletop
  Kit's `ActionIcons`, at 0.88 times the text size and 0.068 of it below the baseline, matching the pf2e action
  font they replaced. `make items` copies `Pathfinder-Icons.ttf` unaltered from the private `Artwork` submodule
  to `Generated/Fonts`, which Core Text reads as it is; without it the glyphs stay as text. Trait, usage and weapon group names come from the
  slug maps in `src/scripts/config` (`ConfigLabels`) and the language files. Starfinder prices are in credits
  (the system keeps them as silver pieces). It builds each `CatalogItem`'s stats as ordered label and value
  rows, so the order lives in one place. Output is sorted with sorted keys, so the same input gives the same
  bytes.
- Spells (R9): `SpellReader` reads the `spells` packs of both games into `CatalogItem`s of kind `spell`,
  `cantrip`, `focus` or `ritual` (cantrip first, as a focus cantrip is a cantrip), with `traditions` and the
  stats `SpellStatRows` builds in the books' order. Descriptions go through Tabletop Kit's `RulesTextConverter`
  with the spell's rank as `@item.level` and `@item.rank` (`FormulaValues.level`), after `DescriptionCleaner`
  drops links into the effect packs. Spells are written to `items.json` with the items; their ids can't clash,
  being Foundry document ids. `ItemKind.cardLabel` is "ITEM", "SPELL", "CANTRIP", "FOCUS" or "RITUAL".
- `ItemCatalog` loads `items.json` from the bundle (empty when missing) and searches and filters it; an
  `ItemQuery` also filters by tradition.
- Item deck art: Tabletop Kit's `.item` and `.drawnItem` shapes are kept as `ItemArtwork` records
  (`StoredLibrary.itemArt`), a figure on a kept PDF page or a PNG in `Items/`, not as pawns.
  `ItemArtMatcher` finds an item's art by its name, then by its name without parentheses and grade words.
  Decks printed before the remaster use old names: `ItemImport` reads the renames from the Equipment table of
  pf2e's Remaster Changes journal (`RenameReader`: linked new items, rows naming several, "(various)" for every
  grade, removed items left out) into `Items/renames.json`, which `ItemCatalog.renames` loads, and the matcher
  files art under its new name as well as its own, its own winning. `ItemArtMatcher.deckMisprints` adds the
  names decks print wrongly ("Olefactory Obfuscator", "Feather Token, Boat") the same way, and
  `ItemArtMatcher.sharedArt` draws every "Scroll of Nth-rank Spell" with the first of the Potions & Talismans
  deck's five "Scroll" cards (page 50): players get spell cards rather than scroll cards, so one picture does.
- Sheets: `SheetEntry.content` is `.pawn(id)` or `.item(id)`; sheets saved with only a pawn id read as pawns.
  An item entry lays out as a 63 × 88 mm card. `SheetExporter.contents(of:)` resolves each placed strip to a
  `PlacedContent` (a pawn, or an `ItemCardContent` with its matched art) that export and the app's background
  page rendering both draw with `PawnRenderer.draw`. `ItemCardPainter` draws in card points (scaled to any
  size): the card's `fill`, then the Rexard background, nine-sliced so the parchment's torn edge stays a thin
  border (content is inset 13 pt to clear it and the frame), or for Starfinder, which has no background image so
  it prints well on an inkjet, a thin `frameStroke` inside its corner brackets, the deck art at `PawnRenderer.itemArtOpacity` (40% by default; the app sets it from the
  `itemArtOpacity` user default on both its renderers, and tiles and pages are drawn again when it changes), the title on the ribbon (placed so its flat face,
  measured as `ItemCardStyle.titleFace`, holds the name and its folds hang over the card's edges) or the
  Starfinder bar, rarity-colored trait chips, the description (`ItemCardText`, Palatino), the stats two to a row
  (a wide one alone; under the traits for spells, above the source for items), and the source line, centered
  clear of the Starfinder corners. Without the pieces, or with `PawnRenderer.printsCardBackgrounds` off (the
  `printsCardBackgrounds` user default, R8.7, which `ItemCardStyle.withoutBackground` applies), a card is white
  with a gray frame.
- Card sets (R8.3.1): `ItemCardLayout.cards(for:style:)` splits an item's text into `ItemCardPage`s (markup and
  text size) using the text areas `ItemCardGeometry` measures for a first card and a continuation card. It tries
  7 pt, then one card at each quarter point down to `PawnRenderer.smallestCardTextSize` (the
  `smallestCardTextSize` user default, 6.25 pt unless set), then pages at 7 pt, then at the smaller sizes when that
  saves a card. Changing the smallest size drops the renderer's laid-out pages.
  Paging takes whole paragraphs (a `---` rule is dropped at a break) and moves one to the next card unless more
  than a third of the card would stay empty; then, and for a paragraph longer than a card, it breaks between
  lines. A `**Heightened` paragraph always moves whole. `PawnRenderer` keeps each item's pages.
  `LayoutItem.cardsPerCopy` makes `ShelfPacker` place every card of a copy in turn (`PlacedStrip.card`), and
  `ItemCardContent.card` says which card of the set to draw.

## App (`PawnShop`)
- `DocumentGroup` for `.pawnsheet` (`PawnSheetDocument`, JSON). `LibraryModel` (`@Observable`, main actor) wraps
  the shared library: imports read each PDF off the main thread (`prepareImport`) and commit on the main
  thread, one at a time, with progress and a summary afterwards.
- Renderers and the figure reader keep only their last few PDFs, pages, figures and pictures (`BoundedCache`:
  8 PDFs, 24 pages, 24 figures, 100 MB of pictures), since an open PDF holds on to what it decoded: keeping
  every one took about 1 GB after browsing. Reading a PDF again costs some 20 ms a pawn.
- `BackgroundRenderer` renders thumbnails (kept in an `NSCache` of at most 150 MB, keyed by the pawn's id and a hash of its name,
  size and art, so a pawn given sharper art is drawn again) and preview pages on one background queue with its
  own `PawnRenderer`.
- Window: `LibraryBrowser` (search field, filter menu for size, game, product and custom; a lazy grid of
  tiles with name, size and short product title; a click selects at once (the double-click is a simultaneous gesture, so no click waits for it); double-click adds the chosen number of copies; a drag carries the selection (`DraggedContent`) with the add bar's copies to the sheet preview, which adds that many of each; context menu
  adds 1–6, renames or removes), `SheetPreview` (pages from `SheetExporter.layout()`, each rendered in the
  background; click a strip to select its pawn, Delete removes one copy), and `SheetInspector` (entries with
  steppers, cut style, gap and fold line, and the page count). PDFs dropped on the window are imported; that drop
  takes only file URLs, so the library's drags reach the sheet preview, which takes them over its whole area,
  empty or not.
- Menus: Library ▸ Import PDF… (⇧⌘I) and Import from Scrollkeeper; File ▸ Page Setup… (⇧⌘P), Export PDF… (⌘E)
  and Print… (⌘P), routed to the frontmost window through a focused scene value (`SheetActions`).
- `SheetOutput`: Page Setup stores the chosen paper size and imageable area in the sheet. Export and Print
  first show `OutputOptionsView` (cut style, gap, fold line, starting from the sheet's settings, applied to
  that run only), then write the exporter's PDF or print it with zero margins, no scaling and no
  auto-rotation. The inspector shows the paper size with a Page Setup button.
- Library ▸ Review Unnamed Pawns… (also a banner above the grid, and a "Needs a Name" filter) opens
  `ReviewNamesView`: the first pawn still needing a name, front and back large, its size and products, and a
  name field. Save and Next (Return) renames it, which saves and clears `needsName`; Skip passes it over for
  this review only. Closing the review loses nothing; reopening starts with the pawns still unnamed.
- Library ▸ Add Custom Pawn… (⌥⌘N) opens `AddCustomPawnView`: choose, drop or paste (⌘V or Paste Image; image data or a copied
  file) an image, name, size and whether
  the name prints, and Fill Pawn or Fit Whole Picture; the preview uses `PawnRenderer.artArea`, `artRect`,
  `nameLayout` and `nameBandHeight`, so it matches the printed front, and dragging moves the art within its room. `PawnLibrary.addCustomPawn(_:)` saves the image as
  PNG in `Custom/` and adds the pawn; the window also adds one copy to its sheet.
- Tagging prompts (`TaggingPrompt`): `named(_:traits:)` tells the model a pawn's name and traits and asks only
  for what the art adds; `unnamed` also asks for the ancestry or kind, the role and a name. A pawn's `tagModel`
  holds `TaggingPrompt.signature(model:)`, the model's name and the prompts' `version`, so raising the version
  tags every pawn again, as changing the model does. `PawnTags.normalized(_:name:traits:)` drops keywords made
  up only of words of the name and traits, and `PawnTags.gendered` words.
- Tagging (`PawnTaggingModel`): one pawn at a time, choosing the next afresh so pawns on screen go first, and
  saving every 10 pawns. The model keeps the model's name and the server's address as typed in
  Settings (user defaults `TaggingModel` and `OllamaURL`), and `OllamaTagger.configured(model:address:)` makes
  the tagger from them, with the defaults for an empty name or an address `endpoint(from:)` rejects. Settings'
  fields (`CommittedTextField`) hand a value on only on Return or on losing focus. `OllamaTagger.isOn(in:)`
  reads the switch, the user default `tagsPawns`, off until turned on in Settings. The run checks the switch
  and that the tagger is still the chosen one (`matches`) before each pawn, and starts over with the new
  tagger when it isn't. `explanation(of:)` words why a run stopped, and `TaggingSettingsText.serverNote(for:)`
  where the pictures go. `NSAllowsLocalNetworking` in the Info.plist lets plain HTTP reach a server on the
  user's network (R2.13). `TaggingProgress(of:by:)` counts the library's pawns still to tag (the same test
  as `pawnsNeedingTags`) against all of them, so the count includes pawns tagged in earlier runs. Settings has
  Updates and Tagging tabs; the Tagging tab's toggle, progress bar and status, and the library's progress bar
  (its tooltip has the counts), observe the model.
- For trying the app from a script: `PAWN_SHOP_LIBRARY` points it at another library folder, and
  `PAWN_SHOP_SNAPSHOT=<prefix>` draws each window, and the library and inspector panels on their own, to
  PNG files a few seconds after launch (drawing its own views needs no screen-recording access; glass panels
  come out blank in window drawings, hence the separate panels).
- The About panel is Tabletop Kit's (`AppNotices`): `AboutCommands` replaces the app menu's About item and
  `AboutInfo.pawnShop` (`About.swift`) fills in the app's name, credits and contact link.

## Syncing (`PawnShopCore/Sync`, R10)
The shared art library syncs itself: tabletop-kit's `TablesideSync` puts a `CKSyncEngine` on the store
(`LibrarySync`, its `docs/specs/library-sync/`), and names, tags and corrections are the store's notes, so they go
with it. Pawn Shop starts that engine, adds a zone of its own for custom pawns, and asks for pictures.

| Question | Decision |
|---|---|
| Where custom pawns sync | A zone `PawnShop` in the suite's container, on the toolkit's engine (CloudKit wants one `CKSyncEngine` per database), owned by `CustomPawnSync`, a `SyncZoneHandler`. |
| Record | One `CustomPawn` per pawn, named `pawn-<UUID>`: `format` Int64 (1), `title` String (the name, for the CloudKit Console), `payload` Bytes (`CustomPawnPayload` as JSON with sorted keys), `image` Asset (the PNG in `Custom/`). This is the record type to deploy to Production with the toolkit's. |
| Payload | The pawn's ID, name, size, the image's focus and scaling, whether the name prints, tags, tag model, whether the tags were corrected, and `modified`. Not the image's file name: a device names the file `<ID>.png`. Fields are only added, as optionals. |
| What needs uploading | `pawn-shop-sync.json` (`CustomPawnLedger`), the device's note of what the server holds: each record's archived system fields and the digest of its payload, and the iCloud account they describe. A pawn whose payload's digest isn't the noted one is saved; a noted record whose pawn is gone is deleted. |
| The image | Sent with every save of its record, as the toolkit sends custom art's: a custom pawn's image never changes, and leaving it out of a save isn't worth finding out the hard way what CloudKit does with a field a save doesn't name. |
| Conflicts | A record from another device replaces the pawn here, unless the pawn has changes still to send and its `modified` is later; then the pawn here stays and is sent. A deletion from another device removes the pawn unless it has changes still to send. `modified` is kept in `pawn-shop.json` (`customPawnsModified`). |
| Pause | The store's (`SharedLibrary.isSyncPaused`): deleting the app's iCloud data purges every zone of the container, so one switch covers both handlers, and `LibrarySync.resume()` turns both back on. |
| A device without the PDF | Prints as well as previews (R10.3). On the Monster Core and Bestiary pawn boxes (672 pawns read by another app, none reachable) the saved pictures' long sides have medians of 272 pixels for small pawns, 465 for medium, 596 for large and 623 for huge, the size their PDFs embed them at; only the largest reach the 1,024 cap. A device that only previewed would be of little use at the table. |
| Picture policy | The toolkit's default, on demand with no limit, on every kind of device: the setting is the device's and the suite's three apps share it. |
| Removed pawns | Not synced (R10.9): `OwnLibrary.hidden` stays the device's. Adding it later is one more record type in the zone, and moves nothing. |

- **The store's side** (`CustomPawnRecords.swift`, `CustomPawnSyncing.swift`, no CloudKit), on `PawnLibrary`:
  `customPawnCandidates()` (what to save and delete), `outgoingCustomPawn(_:)` (the payload, its digest, the image
  and the server's last known fields; nil when the server holds this content), `markSent`, `markDeleted`,
  `forgetSystemFields(of:)`, `forgetCustomPawnServer()` and `applyRemote(_:)`, which merges saved and deleted
  records in as the table says. A saved record whose digest is the noted one only renews the noted fields, even
  with its pawn gone: the pawn was removed here since, and merging the record in would undo a deletion still to
  send. A record without an image for a pawn this device doesn't have is left out. A payload this version can't
  read is noted as unreadable and its pawn isn't sent until a record it can read arrives; the version that raises
  `CustomPawnSync.format` must make devices fetch again, as the toolkit's rule for its own `format` says.
- **The handler** (`CustomPawnSync.swift`), on the main actor, as `PawnLibrary` is: it turns the above into
  `CKRecord`s and back. `settle` merges the server's record of a refused save (`serverRecordChanged`; it comes
  without its image, so the image here stays), forgets the fields of a record the server doesn't know
  (`unknownItem`), forgets the server and has the zone saved again (`zoneNotFound`), pauses (`userDeletedZone`) and
  holds back while iCloud is full (`quotaExceeded`) until a fetch or a change here. A purged zone pauses; a zone
  deleted any other way is uploaded again. An account that isn't the noted one forgets the server. Nothing is
  offered while syncing is paused. While the app is in the background on the iPad the handler closes the shared
  library after each call (shared libraries R5.4).
- **Starting** (`LibraryModel+Sync.swift`). At launch the app calls `LibrarySync.start(app:fallback:handlers:)` with
  the handler, unless `PAWN_SHOP_LIBRARY` is set; it gives nothing in a build that names no container or without
  an iCloud account, and `SyncStatus.withoutSync` then says which. The model follows `statusUpdates()`. A change to
  a custom pawn has no Darwin notification, so the model tells `LibrarySync.libraryChanged()` itself, which queues
  what every handler has to send; changes to notes reach it through the store's notification. Records merged in
  refresh the model. On the iPad the engine's library closes and opens with the app's.
- **Pictures** (R10.3, R10.4). `PawnArt.picture` is the entry's picture in `Pictures/`, drawn by
  `PawnRenderer+Pictures` as large as fits above the name band, standing on it, mirrored for the back.
  `Pawn.pictureFiles` names the files a pawn is drawn from (a token's too). `PictureRequests` gathers the names
  asked for within 50 ms into one `LibrarySync.fetchPictures(named:)`, which downloads those missing and notes
  all of them as shown, so a device with a limit keeps what is in use; names here and noted in the last half hour
  aren't asked again, nor is a picture that didn't arrive within a minute (no device may have uploaded it yet),
  except by an export or a print. `PawnThumbnail` asks before it draws, `SheetWindow` when a sheet opens or its entries change
  and before an export or a print. `LibraryModel.picturesFetched` counts the batches that brought something, and
  is part of the pages' render key; a thumbnail's cache key says whether its pictures are here, so a placeholder
  drawn without a connection isn't kept for the picture.
- **Settings** (`SyncSettingsView`, R10.5 to R10.7), a Sync tab on the Mac and a row on the iPad: the status in
  words (`SyncSettingsText`), a picker of `PictureKeeping` (the choices of R10.6 over `PicturePolicy`; a limit
  another app set that isn't one of them is listed as it is), the downloaded pictures' size with Remove Downloaded
  Pictures, and Turn Syncing Back On while paused.
- **Builds** (R10.10). `ios/PawnShop.entitlements` has the container, CloudKit and push; `ios/Info.plist` names the
  container as `$(TABLESIDE_SYNC_CONTAINER)`, set in `Signing.xcconfig` and emptied by the simulator scripts, whose
  unsigned builds CloudKit would stop, and has the `remote-notification` background mode for the engine's silent
  pushes. `build-app.sh` runs the toolkit's `add-icloud-entitlements.sh` (from `.build/checkouts`, or
  `ICLOUD_ENTITLER`) when `PROVISIONING_PROFILE` names a profile (Developer ID, or the Mac App Store's with
  `CHANNEL=appstore`) and the build isn't signed ad hoc; `release.yml` takes the profile from the
  `DEVELOPER_ID_PROVISIONING_PROFILE` secret, base64-encoded, and builds without iCloud when there is none.
  Before a release: the App ID needs iCloud with the container and Push Notifications, the profiles regenerated
  with them, and the record types deployed to Production in the CloudKit Console.
- **Known limits.** An item deck's art (R8.5) shows on a card only where the deck's PDF or pictures are: item
  art isn't drawn from saved pictures, nor asked for. A device that signs in to iCloud while Pawn Shop is open
  starts syncing when the app next opens. Two devices tagging with different models tag each other's pawns again for as long as both
  run: a pawn needs tagging when its tags aren't the device's model's (`Pawn.needsTagging`). The ledger is in Pawn
  Shop's folder and the engine's state in the shared library's, so restoring one without the other leaves them out
  of step until the records next change. Nothing here has run against iCloud yet: the end-to-end check is the
  toolkit's (library sync design), with a custom pawn added, renamed and removed on each side.

## Icon
`scripts/make-icon.swift` draws the icon with CoreGraphics and `make-icon.sh` builds
`Resources/AppIcon.icns`: a cream pawn with Paizo's rounded top and red cut line, standing in a black base on
green, with a wizard on it (pointed hat, white beard, blue robe, staff with a glowing orb). It uses few, bold
shapes so the pawn and the hat still read at 32 px.

## Releases
- App Sandbox (R6.6): `Resources/PawnShop.entitlements` allows network access (GitHub's update check and Ollama on
  localhost), printing, read-write access to files the user picks, app-scoped bookmarks (Scrollkeeper's folder),
  the Downloads folder (updates) and the Tableside Toolkit's App Group (`TEAM_ID.io.github.scooper4711.tableside`;
  `build-app.sh` puts in the team of the Developer ID certificate, or `TEAM_ID`, and leaves the group out of an ad
  hoc build). `build-app.sh` signs with them and copies
  `Resources/container-migration.plist` into the bundle, which makes macOS move `Application Support/Pawn Shop`
  and the preferences into the container on the first sandboxed launch.
- `make` wraps the scripts in `scripts/`: `build-app.sh` (release build, signed by `sign-app.sh`, `VERSION` written to
  the bundle, `UNIVERSAL=1` for Apple silicon and Intel, `--install` to move it to /Applications),
  `import-items.sh` (`make items`, see Items), `make-dmg.sh` (`build/Pawn-Shop-<VERSION>.dmg`, with `pawn-bases/` as a Pawn Bases folder, minus its build
  scripts) and `coverage.sh` (fails below 80% line or region coverage
  of `PawnShopCore`, and writes `coverage/sonar-coverage.xml`).
- GitHub Actions: `ci.yml` lints strictly, runs the coverage gate (tests reading Paizo's PDFs are skipped, as the
  PDFs are not in the repository), builds the app and sends coverage to SonarCloud; `release.yml` builds each pushed
  `v*` tag: it fetches the private `Artwork` submodule, imports the items with `REXARD_PACKS=Artwork/rexard`, tests,
  builds the universal app and attaches its disk image to the tag's release. Run by hand it keeps the image as a
  workflow artifact. `release-dmg.sh` (`make release-dmg`) does the same on a Mac, for the tag at HEAD, should the
  GitHub build fail, notarizing it with a notarytool keychain profile.
- **Signing.** `scripts/sign-app.sh` signs the app with the first Developer ID Application certificate in the
  keychain, with the hardened runtime and a secure timestamp, or ad hoc when there is none (`SIGNING_IDENTITY`
  overrides it). On GitHub, `scripts/add-signing-certificate.sh` puts the certificate from the
  `DEVELOPER_ID_CERTIFICATE` and `DEVELOPER_ID_CERTIFICATE_PASSWORD` secrets into a temporary keychain; without it a
  release fails and a trial build is signed ad hoc. For a release, `scripts/notarize.sh` signs the disk image, has
  Apple's notary service check it (the `NOTARY_APPLE_ID`, `NOTARY_TEAM_ID` and `NOTARY_PASSWORD` secrets, or a
  notarytool keychain profile on a Mac) and staples the ticket to it. The team ID is kept only in the secrets and
  the keychain.
- `pf2e-update.yml`, weekly, as in Field Guide: when pf2e has a newer release it switches `pf2e.release`
  (straight away when the release changes nothing under `packs`, `static` or `src/scripts/config`), imports the
  items, and when their fingerprint (`scripts/fingerprint.sh`: the JSON files in `Generated/Items`, kept in
  `import.sha256` by `make items`) changes it commits both through the API, tags the next patch version and calls
  `release.yml` for it, which leaves a draft release to publish.
- `coverage.sh` measures every test bundle (newer toolchains build one per test target) and gates
  `PawnShopCore` and `ItemCatalogImport` together.
- Updates (`PawnShopCore/Updates`): `AppUpdater` asks GitHub's `releases/latest` for the repository, compares
  the tag with the bundle version (`AppVersion`, number by number), and offers the release's `.dmg`. A 404,
  which GitHub answers before the first release, counts as up to date. Builds without a version (0.0.0) skip
  the launch check, which would otherwise always find an update. The app shows the results in app-modal
  alerts (`UpdateAlerts`), so they appear once however many sheet windows are open; the launch check is the
  user default `checksForUpdatesAtLaunch`, on unless turned off in Settings.
- Pawn bases (`pawn-bases/`): `pawn_base.scad` puts its Customizer parameters first, in Base, Fit and Hidden
  tabs, before any function or module, as the Customizer requires. A label's height is the size's label height
  times min(1, 1.6 / (characters + 0.6)), so one character keeps the original size and the ready-made 1–4
  bases are unchanged. `build.sh` renders all 21 STL files in parallel; `stl_to_binary.py` rewrites OpenSCAD
  2021's ASCII STL as binary, about a fifth of the size. The STL files are committed so the release workflow
  needs no OpenSCAD.
