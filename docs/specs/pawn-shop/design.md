# Pawn Shop: design

A SwiftPM macOS app in the style of Flip Map Printer: `PawnShopCore` holds all logic and is unit tested;
`PawnShop` is a thin SwiftUI/AppKit layer; `scripts/build-app.sh` builds `Pawn Shop.app`.

## Paizo pawn PDFs
Measured across 61 Pathfinder and Starfinder pawn PDFs:
- Most pawns have a cut outline: a stroked path of straight edges and two curves (`v`/`c`) that round the
  head corners. Outlines are drawn on the page or inside a form XObject; the stroke is red, but detection
  relies on shape and size, not color.
- Upright outline sizes (points): small 60×81, medium 81×138, large 138×180, huge 215×281. Mediums stand
  upright on the page; small, large and huge are printed sideways, with the curves on the left or right edge.
- Pages come in pairs: a front page followed by its back. The back page mirrors positions around the page's
  vertical axis (offset by any bleed) and flips the art horizontally. Cover and credit pages have no outlines.
- Art is clipped to a frame cell around each outline, so a clip to the outline never picks up a neighbor.
- The label sits inside the outline's foot: the name in the largest type (one or two lines), the copyright
  in fine print, and in some products a reference code (such as "B 62") in fine print in a corner. Some
  labels are drawn twice (fill and outline), so their text reads each chunk twice.
- A page holds several copies of a pawn that differ only in a colored badge. Newer PDFs reuse one image
  object for the copies; older ones embed each copy again with different compression. One name can also
  have different art.
- Token PDFs print round tokens instead. Each token's art is images clipped to a circle (a `W n` path of
  curves, sometimes cut flat on one side), reaching a 1/8" bleed past the cut. Measured on two:
  - Alien Core Token Box: art pages alternate with label pages, which mirror the art pages' positions and
    print each token's number, name and copyright on a dark disc. The red cut circles are one raster overlay
    across the page; colored bands at the foot tell copies apart. Clips are 90, 162 and 232 pt (1", 2", 3"
    cuts); art reaching past the circle is embedded as separately cropped images per copy.
  - Murder in Metal City Tokens: 62 pt clips on a full-page dark background image, the art transparent
    around the figure (a soft mask), the cut line a filled vector ring, and the name set along the rim one
    letter per text object, twice (outline and fill), with copy numbers ("Smog Scamp 2"). The second page is
    the duplex back. The font maps a hyphen through its ToUnicode CMap only.
- Not yet handled: pawns printed without outlines (the second half of Monster Core, Dawn of Flame), pages
  that are only a raster image (the second half of NPC Core), and terrain sets with rectangular outlines.

## Paizo Battle Cards
Measured across eleven decks (Bestiary 1–3, Monster Core, NPC, NPC Core, Abomination Vaults, Book of the Dead,
Fists of the Ruby Phoenix, Alien Archive 1 & 2 and 3 & 4), 289 × 425 pt cards (Starfinder 289 × 431):
- Layouts: one PDF with each card's art page just before its stat page (Bestiary); one PDF with runs of stat
  pages each followed by a run of the same cards' art (Monster Core, NPC Core: runs of about 110); or two PDFs,
  "… FRONT(S)" and "… BACKS", paired page by page. Art pages print no text, except Starfinder's, which print the
  name above the art. The NPC deck's combined PDF prints no art of its own, and the Deck of Endless NPCs is not
  a Battle Cards deck.
- An art page draws the background, frame and badges every card shares, then the card's own pictures. The
  creature is the last of those, an image with a soft mask that is transparent around the figure; first-edition
  decks draw a zoomed copy of it behind the frame, and the creature's canvas is often the whole card, with
  transparent margins.
- The creature's picture is the pawn box's painting, at about 2.9 times the pixels across (1.2 to 6.3) in the
  Bestiary deck, and some cards use different paintings from the pawn box (Giant Centipede, Flash Beetle, Orc
  Warrior).
- PDFKit reads stat pages in a mostly natural order: "AEON, ARBITER CREATURE 1" (a backspace sometimes follows
  the name), then the traits in capitals, wrapping onto the Perception line in Bestiary 2. On a few cards the
  alignment and size come before or after the name. Starfinder prints "NAME CR n", "XP n" and "LE Medium
  humanoid (human)", but sometimes the name shares its line with the type, or CR comes several lines down.
  Long stat blocks continue on a card headed "(Name; continued from card n)".
- Reading all eleven decks takes about 35 seconds (release build); they give about 2,700 creatures.

## Extraction (`PawnShopCore/Extraction`)
- `PageScanner` walks a page's content stream with `CGPDFScanner`, tracking `q`/`Q`/`cm`, recursing into
  form XObjects (with their `Matrix`), and building paths from `m l c v y re h`.
  - On `S`/`s`/`B`/`b` it records each subpath with two curves and otherwise straight edges as an `Outline`:
    its bounding rect in page space and the edge holding the curves (`headEdge`).
  - On `Do` of an image it records an `ImagePlacement`: the rect, transform and stream, the circle it is
    clipped to (a `W` path of one subpath with at least three curves whose points all lie on a fitted circle,
    kept through `q`/`Q`), and the image's `ImageIdentity` (SHA-256 of its data and a 16×24 grayscale
    thumbnail of its decoded pixels), computed once per image object.
  - It records each piece of text shown (`Tj`, `TJ`, `'`, `"`) where its text matrix (`BT`, `Tm`, `Td`,
    `TD`) puts it, decoded through the font's ToUnicode CMap (`FontDecoder`: `bfchar` and `bfrange`).
- `TokenFinder` turns a page's clip circles 36–306 pt across, outside pawn outlines and with art images, into
  `FoundToken`s with their images, fingerprint and the text inside. `TokenPairing` pairs token pages like
  outline pages (most common mirror axis over same-row, same-size circles): a mirrored token is the back when
  it shows the same art, or when it carries words and the front has none (a label side). Names come from the
  token's text in lines (letters shown one by one join into a line), dropping lines without letters (token
  numbers), the copyright and repeated lines. The size is the clip less the bleed: under 1.5" medium, 2.5"
  large, 3.5" huge, else gargantuan. `TokenPicture` draws the token's own images alone, with their soft masks,
  clipped to the circle, into a PNG at the sharpest image's resolution (at most 600 dpi): the background, cut
  line, bands and printed names are left out. Same-name copies whose crops differ too much to match stay
  separate pawns (four in the Alien Core box).
- `PawnSize.classify(_:)` matches an outline's upright size to the table within ±4 pt.
- `PawnExtractor`:
  - pairs page *n* with *n+1* when at least half of *n*'s outlines have a same-size outline at the mirrored
    position on *n+1*; the mirror axis is the most common sum of centers of same-row, same-size outlines;
    paired back pages are not read as fronts;
  - gives each front outline its mirrored back (or none, in which case the back is the front mirrored);
  - names each pawn from the text inside the outline (`PDFKitLabelReader` reads runs with their font size):
    only text at least 80% of the largest size, copyright removed, doubled chunks read once, title case;
  - sets the rotation (0/90/180/270) that turns the head edge to the top;
  - fingerprints the art (`ArtFingerprint`): the digests of the images inside the outline (at least 20 pt
    across) plus the largest one's thumbnail. Pawns merge only when name and size are equal and the art
    matches: equal digests, or thumbnails with a correlation distance (100 × (1 − r)) of at most 20. Copies
    embedded separately measure up to about 10; different figures start above 40.

## Battle Cards (`PawnShopCore/Cards`)
- `CardDeck.containing(_:)` takes a PDF whose name, or one of its two enclosing folders, says "Battle Cards".
  A file naming a side (FRONT, FRONTS, BACK, BACKS) is paired with the file beside it whose name differs only
  in naming the other side; the BACKS file is the deck's `artFile`, which the library keeps. The title comes
  from the nearest enclosing folder naming the deck and starting with Pathfinder or Starfinder (as Scrollkeeper
  files them), without "(Download)" and "- PDF(s)", or else from the file name.
- `CardPairing` pairs pages: page *n* of both PDFs; or in one PDF, each art page with the page after it when
  such pairs cover over a third of the pages, else the *k*th page of each run of other pages with the *k*th of
  the run of art pages after it. An art page prints under 80 characters and no stat block: the NPC deck's
  combined PDF credits the illustrator on each art page.
- `CardExtractor` scans art pages with `PageScanner.images(on:)` (placements without identities, which are
  slow to compute) and digests each image once. Images on at least half the art pages, and on three or more,
  are shared; the creature is the last image drawn that is not shared, has a soft mask and is at least 20 pt
  across. It becomes an `ExtractedPawn` with the `.card(imageIndex:)` shape, a face on the art page whose rect
  is the creature's opaque bounds, the back the front mirrored, and the creature's digest and thumbnail as its
  fingerprint.
- `CardStats.read(_:)` reads the stat page's PDFKit text (control characters become spaces). The name is the
  run of words in capitals starting the header's line, or one of the three lines above it; rarity, alignment
  and size words read beside it move to the traits, except after a comma ("Herd Animal, Huge"). Pathfinder's
  traits are the words in capitals between the header and "Perception"; Starfinder's are the size, type and
  subtypes of the first "[alignment] Size type (subtypes)" line, without a book reference after a semicolon.
- `Figure` (in Extraction) is one image as its page draws it: the image with its soft mask, and its opaque
  bounds in page space, found in a bitmap at most 512 px across (alpha above 24). `pixelArea` is those bounds in
  the image's own pixels. `palette()` counts the opaque pixels of the figure drawn 64 × 64 into 64 colors (four
  levels of red, green and blue); `paletteDistance` is 1 minus the Bhattacharyya coefficient. In the Bestiary,
  the same painting however cropped measured at most 0.013 and different paintings of the same creature 0.027
  or more, so 0.02 is the same painting. Thumbnails (16 × 24) cannot tell these apart, since a crop moves the
  figure in its frame, and Vision's feature prints rate young and adult dragons closer than one painting's crops.

## Library (`PawnShopCore/Library`)
- Stored under `~/Library/Application Support/Pawn Shop/`:
  - `Sources/<sha256>.pdf`: a copy of each imported PDF;
  - `Custom/<file>`: custom pawn art;
  - `Tokens/<file>`: tokens' art drawn alone (PNG), written when an import is committed;
  - `library.json`: sources and pawns (`StoredLibrary`, with a version number). Thumbnails are stored as
    base64 data; the whole collection (about 8,000 pawns from 61 PDFs) is under 10 MB.
- `PawnSource`: id (SHA-256 of the file), title (from the file name, without product codes and " PDF"),
  import date, original path and byte count (to recognize a file again without hashing it), the game, read
  from the title, and how many pawns the import found with which `PawnExtractor.version`. A source read by an
  older version that found nothing (for sources recorded before the count, one no pawn comes from) is not
  counted as imported; importing it again drops the record and reads it afresh. The version is raised when
  extraction improves (1: credited card art), so each empty PDF is read once per improvement, not on every
  import. A PDF with no pawns is not copied.
- `Pawn`: id, name, size, fingerprint, `needsName`, `traits` (from Battle Cards), `art` (`.pdf(sourceID, front,
  back)`, `.custom(CustomArt)`, `.token(TokenArt)`: source id and front and optional back picture files, or
  `.card(CardArt)`: source id, the art page and creature bounds as a face, and the image's index in drawing
  order, drawn straight from the kept PDF rather than stored as a picture, since PNGs of every deck's creatures
  would take over a gigabyte) and
  `appearances` (each product printing the art, with its copies; the first supplies the faces).
  `CustomArt`: image file name, scaling (`.fill` covers the face; `.fit` shows the whole picture in the area
  above the name band), focus point (where the image sits within its room to move: the overflow when filling,
  the free space when fitting), and whether the name is printed.
- `PawnLibrary`:
  - `prepareImport(of:)` hashes and extracts a PDF without touching the library, so it can run off the main
    thread; `commit(_:)` copies the file, adds the source, and merges each pawn into an existing one with the
    same name, size and matching art (adding an appearance) or adds it; then saves. A known file is a no-op.
  - `add`, `update`, `rename` (which clears `needsName`) and `remove` (deleting custom art and token pictures) save
    immediately.
  - Battle Cards (`SharperArt.swift`): when either the extracted pawn or a library pawn is a card, only equal
    digests merge them directly. Otherwise a named pawn is compared with the library pawns whose names match
    (`namesMatch`, found through an index by the part after the last comma, built for the import) by their
    figures' palettes; `FigureReader` finds a card's creature, or a printed pawn's largest image inside its front,
    in the kept PDFs, keeping the last 24 figures. A match adds the appearance (first when the imported picture
    has more pixels and becomes the art), takes a printed pawn's size and adds the traits. Into a copy of the
    real library (8,620 pawns), the Bestiary deck merged 340 of its 398 cards, 339 of them now drawn from the
    card; Monster Core, Bestiary 2 and Alien Archive 1 & 2 merged 318, 291 and 163.
  - Nameless pawns (`PawnMerging.swift`): an extracted pawn with no name merges into a pawn with the same art
    when its product is in `NamelessProducts` (Heroes & Villains) and `ArtFingerprint.isSameArt(as:)` holds:
    equal digests or a thumbnail distance of at most 15, stricter than the 20 used with equal names because
    across the whole library 16 and up were different figures. Otherwise it is added as
    "Unknown <product title>" with `needsName`. A named pawn imported later that matches such a pawn gives it
    its name. `pawnsNeedingNames` lists them in library order.
  - `search(_:)`: every word must appear (case- and diacritic-insensitive) in the name or a product title, or
    begin a word of a trait or tag;
    filters by size, game, product and custom; ordered by name, then product, so same-name art sits together.
- `ScrollkeeperScanner` lists PDFs under Scrollkeeper's Files folder whose name contains "pawn" or "token", and
  each Battle Cards deck once, as its art PDF (`PawnLibrary.importableFiles`).
- Importing all 61 PDFs takes about 25 seconds (release build); about 420 pawns merge across products, such as
  Monster Core reusing Bestiary art.

## Sheets and layout (`PawnShopCore/Sheet`)
- `PawnSheet` (Codable, the `.pawnsheet` document): entries (pawn id, count; adding a pawn again adds to its
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
- `SheetExporter` (sheet, library, renderer) builds the layout items (a missing pawn takes a medium strip),
  the layout, each page's drawing (shared by preview and print), and the PDF at 100% scale.

## App (`PawnShop`)
- `DocumentGroup` for `.pawnsheet` (`PawnSheetDocument`, JSON). `LibraryModel` (`@Observable`, main actor) wraps
  the shared library: imports read each PDF off the main thread (`prepareImport`) and commit on the main
  thread, one at a time, with progress and a summary afterwards.
- `BackgroundRenderer` renders thumbnails (kept in an `NSCache`, keyed by the pawn's id and a hash of its name,
  size and art, so a pawn given sharper art is drawn again) and preview pages on one background queue with its
  own `PawnRenderer`.
- Window: `LibraryBrowser` (search field, filter menu for size, game, product and custom; a lazy grid of
  tiles with name, size and short product title; double-click adds the chosen number of copies; context menu
  adds 1–6, renames or removes), `SheetPreview` (pages from `SheetExporter.layout()`, each rendered in the
  background; click a strip to select its pawn, Delete removes one copy), and `SheetInspector` (entries with
  steppers, cut style, gap and fold line, and the page count). PDFs dropped on the window are imported.
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
- For trying the app from a script: `PAWN_SHOP_LIBRARY` points it at another library folder, and
  `PAWN_SHOP_SNAPSHOT=<prefix>` draws each window, and the library and inspector panels on their own, to
  PNG files a few seconds after launch (drawing its own views needs no screen-recording access; glass panels
  come out blank in window drawings, hence the separate panels).

## Icon
`scripts/make-icon.swift` draws the icon with CoreGraphics and `make-icon.sh` builds
`Resources/AppIcon.icns`: a cream pawn with Paizo's rounded top and red cut line, standing in a black base on
green, with a wizard on it (pointed hat, white beard, blue robe, staff with a glowing orb). It uses few, bold
shapes so the pawn and the hat still read at 32 px.

## Releases
- `make` wraps the scripts in `scripts/`: `build-app.sh` (release build, ad-hoc signed, `VERSION` written to
  the bundle, `UNIVERSAL=1` for Apple silicon and Intel, `--install` to move it to /Applications),
  `make-dmg.sh` (`build/Pawn-Shop-<VERSION>.dmg`, with `pawn-bases/` as a Pawn Bases folder, minus its build
  scripts) and `coverage.sh` (fails below 80% line or region coverage
  of `PawnShopCore`, and writes `coverage/sonar-coverage.xml`).
- GitHub Actions: `ci.yml` lints strictly, runs the coverage gate (tests reading Paizo's PDFs are skipped, as
  the PDFs are not in the repository), builds the app and sends coverage to SonarCloud; `release.yml` builds a
  universal disk image for each pushed `v*` tag and attaches it to the tag's GitHub release.
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
