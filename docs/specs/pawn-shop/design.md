# Pawn Shop: design

A SwiftPM macOS app in the style of Flip Map Printer: `PawnShopCore` holds all logic and is unit tested;
`PawnShop` is a thin SwiftUI/AppKit layer; `scripts-build/bundle.sh` builds `Pawn Shop.app`.

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
- Not yet handled: pawns printed without outlines (the second half of Monster Core, Dawn of Flame), pages
  that are only a raster image (the second half of NPC Core), and terrain sets with rectangular outlines.

## Extraction (`PawnShopCore/Extraction`)
- `PageScanner` walks a page's content stream with `CGPDFScanner`, tracking `q`/`Q`/`cm`, recursing into
  form XObjects (with their `Matrix`), and building paths from `m l c v y re h`.
  - On `S`/`s`/`B`/`b` it records each subpath with two curves and otherwise straight edges as an `Outline`:
    its bounding rect in page space and the edge holding the curves (`headEdge`).
  - On `Do` of an image it records an `ImagePlacement`: the rect and the image's `ImageIdentity` (SHA-256
    of its data and a 16×24 grayscale thumbnail of its decoded pixels), computed once per image object.
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

## Library (`PawnShopCore/Library`)
- Stored under `~/Library/Application Support/Pawn Shop/`:
  - `Sources/<sha256>.pdf`: a copy of each imported PDF;
  - `Custom/<file>`: custom pawn art;
  - `library.json`: sources and pawns (`StoredLibrary`, with a version number). Thumbnails are stored as
    base64 data; the whole collection (about 8,000 pawns from 61 PDFs) is under 10 MB.
- `PawnSource`: id (SHA-256 of the file), title (from the file name, without product codes and " PDF"),
  import date, original path and byte count (to recognize a file again without hashing it), and the game,
  read from the title.
- `Pawn`: id, name, size, fingerprint, `art` (`.pdf(sourceID, front, back)` or `.custom(CustomArt)`) and
  `appearances` (each product printing the art, with its copies; the first supplies the faces).
  `CustomArt`: image file name, focus point (where the image sits when it overflows the outline), and
  whether the name is printed.
- `PawnLibrary`:
  - `prepareImport(of:)` hashes and extracts a PDF without touching the library, so it can run off the main
    thread; `commit(_:)` copies the file, adds the source, and merges each pawn into an existing one with the
    same name, size and matching art (adding an appearance) or adds it; then saves. A known file is a no-op.
  - `add`, `update` (rename) and `remove` (deleting custom art files) save immediately.
  - `search(_:)`: every word must appear (case- and diacritic-insensitive) in the name or a product title;
    filters by size, game, product and custom; ordered by name, then product, so same-name art sits together.
- `ScrollkeeperScanner` lists PDFs under Scrollkeeper's Files folder whose name contains "pawn".
- Importing all 61 PDFs takes about 25 seconds (release build); about 420 pawns merge across products, such as
  Monster Core reusing Bestiary art.

## Sheets and layout (`PawnShopCore/Sheet`)
- `PawnSheet` (Codable, the `.pawnsheet` document): entries (pawn id, count) and `SheetSettings`: cut style
  (`.shared` or `.gaps(points)`), show fold line, paper size and imageable rect.
- A pawn prints as a strip of `w × 2h`: the front face in the lower half, the back face rotated 180° in the
  upper half, heads meeting at the fold. Folding over a horizontal line and viewing from behind is a 180°
  rotation, so the back reads upright, and because Paizo's back art is already mirrored the silhouettes match.
- `SheetLayout.pages(for:settings:)` is shelf packing: strips sorted by size (largest first, then entry order),
  placed left to right in rows, rows top to bottom, new pages as needed. With shared cut lines strips touch;
  with gaps they are separated by the gap. Strips taller or wider than the printable area get a page each.
- `PawnRenderer` draws a face: the source PDF page clipped to the face rect and rotated upright (vector text
  and full-resolution art kept), or a custom image aspect-filled into the outline.
- `SheetExporter` renders the layout to PDF: strips, cut lines (hairline gray) and dashed fold lines.

## App (`PawnShop`)
- `DocumentGroup` for `.pawnsheet`. `LibraryModel` (`@Observable`, main actor) wraps the shared library.
- Window: library browser (search, size and source filters, thumbnail grid, add with count), sheet preview
  (pages from `SheetLayout`, select a strip, Delete removes a copy), inspector (entries with steppers, sheet
  settings).
- Menus: Import PDF…, Import from Scrollkeeper…, Add Custom Pawn…, Page Setup…, Export PDF… (⌘E), Print… (⌘P).
  Export and Print offer the cut style for that run. Printing uses zero margins, no scaling, no auto-rotate.
- Imports run in a background task with progress and end with a report.

## Icon
`scripts-build/make-icon.swift` draws the icon with CoreGraphics and `make-icon.sh` builds
`Resources/AppIcon.icns`: a folded paper pawn in a black base, in front of a brass three-ball pawnshop sign on
deep green.
