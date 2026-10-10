# Pawn Shop: design

A SwiftPM macOS app in the style of Mapsmith: `PawnShopCore` holds all logic and is unit tested;
`PawnShop` is a thin SwiftUI/AppKit layer; `scripts/build-app.sh` builds `Pawn Shop.app`.

## Reading the PDFs
Finding pawns, tokens and Battle Cards creatures in Paizo's PDFs, and the measurements it relies on, are in
[Tabletop Kit](https://github.com/scooper4711/tabletop-kit) (`ArtExtraction`), described in its spec
(`docs/specs/tabletop-kit/design.md`). Pawn Shop's library uses its figures to compare paintings (below).

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
- Tagging (`PawnTaggingModel`): one pawn at a time, choosing the next afresh so pawns on screen go first, and
  saving every 10 pawns. `OllamaTagger.configured(by:)` reads the model and endpoint from user defaults, and
  `OllamaTagger.isOn(in:)` the switch, the user default `tagsPawns`, on unless turned off in Settings; the run
  checks it before each pawn. `TaggingProgress(of:by:)` counts the library's pawns still to tag (the same test
  as `pawnsNeedingTags`) against all of them, so the count includes pawns tagged in earlier runs. Settings has
  Updates and Tagging tabs; the Tagging tab's toggle, progress bar and status, and the library's progress bar
  (its tooltip has the counts), observe the model.
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
