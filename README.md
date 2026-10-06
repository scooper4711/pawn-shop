# Pawn Shop

A Mac app for printing Paizo pawns without duplex printing. Paizo's pawn PDFs put each pawn's back on the
next page, mirrored, which rarely lines up, and a single sheet makes a floppy pawn. Pawn Shop collects the
pawns from those PDFs into a library, and prints only the pawns you choose, each as one strip on one side of
the paper: the front below, the back above it turned upside down, head to head. Cut the strip out and fold it
at the heads: the pawn is two sheets thick, and the base holds both.

## Use
- **Import:** Library › Import from Scrollkeeper imports every pawn PDF that
  [Scrollkeeper](https://github.com/scooper4711/scrollkeeper) downloaded. Library › Import PDF… (⇧⌘I) or
  dropping PDFs on a window imports others. Each pawn is found from its cut outline, named from its label,
  sized (small, medium, large, huge) and turned upright. Copies of the same art are stored once, also when
  another product reprints them; pawns that share a name but not their art (1e and 2e, variants) are kept
  apart. The library keeps its own copy of each PDF in `~/Library/Application Support/Pawn Shop`.
- **Find:** search by name or product, and filter by size, game, product or custom pawns. Pawns with the same
  name sit next to each other, so you can pick the art you like. Right-click to rename or remove a pawn.
- **Build a sheet:** a sheet is a document (File › New, Save, Open Recent). Double-click a pawn, or set the
  copies and press Add to Sheet. The middle of the window shows the pages as they will print; click a strip
  and press Delete to remove a copy, or change copies in the inspector on the right. Strips are packed
  upright or on their side, whichever needs fewer pages.
- **Cut style:** shared cut lines (strips touch, so one cut separates two pawns) or gaps between strips, and
  an optional dashed fold line. The sheet remembers its choice, and Export and Print can change it for one
  run.
- **Print:** File › Page Setup… (⇧⌘P) picks the paper; File › Export PDF… (⌘E) or Print… (⌘P). Print at
  100% scale (Actual Size).
- **Your own art:** Library › Add Custom Pawn… (⌥⌘N): choose or drop an image, name it, pick a size from small
  to gargantuan, and drag the preview to place the art. The back is the front mirrored.

## Not handled yet
- Pawns printed without cut outlines (the second half of the Monster Core Pawn Box, Dawn of Flame).
- Pages that are a single picture with no text (the second half of the NPC Core Pawn Box).
- Terrain collections with rectangular outlines (Dungeon Decor, Traps & Treasures, Tech Terrain).

These import with fewer pawns, or none; the import summary names PDFs where nothing was found.

## Build
Requires macOS 15+ and Xcode 16+ (Swift 6).

```sh
swift test                         # unit tests
swiftlint                          # lint
scripts-build/bundle.sh            # builds "build/Pawn Shop.app"
scripts-build/bundle.sh --install  # …and moves it to /Applications
scripts-build/make-icon.sh         # redraws Resources/AppIcon.icns
```

Tests that read real pawn PDFs use `TestData/`, which is gitignored because the PDFs are copyrighted. Link
your Scrollkeeper downloads there to run them; they are skipped when the folder is empty.

To try the app without touching your library, set `PAWN_SHOP_LIBRARY` to another folder. With
`PAWN_SHOP_SNAPSHOT=<prefix>` the app also draws its windows to `<prefix>-*.png` a few seconds after launch:

```sh
open -n --env PAWN_SHOP_LIBRARY="$PWD/tmp/library" --env PAWN_SHOP_SNAPSHOT="$PWD/tmp/snap" \
     -a "$PWD/build/Pawn Shop.app"
```

See `docs/specs/pawn-shop/` for the requirements and design.

## Layout
- `Sources/PawnShopCore/Extraction`: reading pawn PDFs (outlines, labels, art fingerprints, page pairing)
- `Sources/PawnShopCore/Library`: the library, search, custom pawns
- `Sources/PawnShopCore/Sheet`: sheets, page layout, rendering and PDF export
- `Sources/PawnShop`: the SwiftUI app
