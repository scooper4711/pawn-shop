# Pawn Shop: design

A SwiftPM macOS app in the style of Flip Map Printer: `PawnShopCore` holds all logic and is unit tested;
`PawnShop` is a thin SwiftUI/AppKit layer; `scripts-build/bundle.sh` builds `Pawn Shop.app`.

## Paizo pawn PDFs
Measured across the Pathfinder and Starfinder pawn collections:
- Each pawn has a cut outline: a stroked path of straight edges and two curves (`v`/`c`) that round the head
  corners. Outlines are drawn on the page or inside a form XObject; the stroke is red, but detection relies on
  shape and size, not color.
- Outline sizes (points): small 81×60, medium 81×138, large 180×138, huge 281×216. Sideways pawns have the
  sizes swapped, with the curves on the left or right edge.
- Pages come in pairs: a front page followed by its back. The back page mirrors positions
  (`x′ = width − x − w`) and flips the art horizontally. Cover and credit pages have no outlines.
- Art is clipped to a frame cell around each outline, so a clip to the outline never picks up a neighbor.
- The label sits inside the outline's foot: the name (one or two lines), then `© 20xx PAIZO INC.`
- A page holds several copies of a pawn that differ only in a colored badge; one name can also have different
  art.

## Extraction (`PawnShopCore/Extraction`)
- `OutlineScanner` walks a page's content stream with `CGPDFScanner`, tracking `q`/`Q`/`cm`, recursing into form
  XObjects (with their `Matrix`), and building paths from `m l c v y re h`. On `S`/`s`/`B`/`b` it records each
  subpath with two curves and otherwise straight edges as an `Outline`: its bounding rect in page space and the
  edge holding the curves (`headEdge`).
- `PawnSize.classify(_:)` matches an outline's upright size to the table within ±4 pt.
- `PawnExtractor` takes a `CGPDFDocument` plus a label reader:
  - pairs page *n* with *n+1* when at least half of *n*'s outlines have a same-size outline at the mirrored
    position on *n+1*; paired back pages are not read as fronts;
  - gives each front outline its mirrored back (or none, in which case the back is the front mirrored);
  - names each pawn from the text inside the outline (`PDFKitLabelReader` uses `PDFPage.selection(for:)`),
    dropping the copyright line, joining lines and collapsing spaces;
  - sets the rotation (0/90/180/270) that turns the head edge to the top.
- `ArtFingerprint` is a 64-bit dHash of the face rendered upright at low resolution with the label foot masked.
  Two faces match when their Hamming distance is at most a small threshold. Pawns merge only when their art
  matches; same-name pawns with different art stay apart.

## Library (`PawnShopCore/Library`)
- Stored under `~/Library/Application Support/Pawn Shop/`:
  - `Sources/<sha256>.pdf`: a copy of each imported PDF;
  - `Custom/<id>.png`: custom pawn art;
  - `library.json`: sources (id = SHA-256, title, import date) and pawns.
- `Pawn`: id, name, size, fingerprint, `art` (`.pdf(front: PawnFace, back: PawnFace)` or
  `.custom(imageFile, offset)`), `appearances` (source id and copies in that source).
  `PawnFace`: source id, page index, rect, rotation, mirrored flag (for a missing back).
- `PawnLibrary` imports a PDF (no-op when its hash is known), merges by fingerprint, adds custom pawns,
  removes pawns, and searches: case- and diacritic-insensitive over name and source titles, filtered by size
  and source, ordered by name so same-name pawns sit together.
- `ScrollkeeperScanner` lists PDFs under Scrollkeeper's Files folder whose name contains "Pawn".

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
