# Pawn Shop: requirements

Paizo pawn PDFs are laid out for duplex printing, which rarely lines up, and a single sheet makes a floppy
pawn. Pawn Shop collects the pawns from those PDFs into a library and prints only the pawns you choose, each
as one strip on one side of the paper: the front below, the back above it turned 180°, head to head. The strip
is cut out and folded at the heads, giving a two-ply pawn.

## R1 Importing pawn PDFs
- R1.1 File ▸ Import PDF… and dropping PDFs on a window import them into the library.
- R1.2 Library ▸ Import from Scrollkeeper… finds every pawn PDF in Scrollkeeper's Files folder
  (`~/Library/Application Support/Scrollkeeper/Files`) that is not yet imported and imports them all.
- R1.3 Every pawn in the PDF is found from its red cut outline, named from the label printed inside it, and
  sized (small, medium, large, huge) from the outline.
- R1.4 Each pawn's back is taken from the mirrored position on the following page. When there is none, the
  back is the front mirrored.
- R1.5 Pawns printed sideways are turned upright.
- R1.6 A pawn is a duplicate only when its artwork matches. Copies of the same art (on one page or reprinted
  in another product) are stored once; pawns with the same name and different art (1e and 2e, Pathfinder and
  Starfinder, variants) are kept apart.
- R1.7 Importing a PDF that is already in the library changes nothing.
- R1.8 Importing shows progress, then a report of the pawns added, the pawns whose art was already in the
  library, and the outlines with no name printed.
- R1.9 The library keeps its own copy of each imported PDF, so pawns survive the original being moved.
- R1.10 Pawns with no name printed are imported as "Unknown <product title>" and marked as needing a name.
- R1.11 Heroes & Villains is the one product known to print no names. Its pawns take the name of the same art
  in another product, whichever is imported first; the rest need naming.
- R1.12 Library ▸ Review Unnamed Pawns… steps through the pawns needing a name, showing each large with its
  tags (R2.7) and a name field filled in with the name the tagging model suggests, so Return accepts it. Each
  name is saved as it is entered, so the review can be closed and resumed at any time.

## R2 The library
- R2.1 The library is kept between launches and shared by every sheet.
- R2.2 Search matches names and product titles, ignoring case and accents, and the start of words in a pawn's
  tags (R2.7), so "man" does not find "woman".
- R2.3 Results can be filtered by size and by product.
- R2.4 Pawns with the same name are shown next to each other with their product, so the art can be compared.
- R2.5 A pawn can be removed from the library, or renamed.
- R2.6 Results can be filtered by game (Pathfinder or Starfinder) and to custom pawns only.
- R2.7 Each pawn is tagged in the background with keywords for what its art shows (person, creature, robot or
  vehicle, undead, role, weapons, armor, animals) by a vision model running locally in Ollama, without the
  printed name in view, and with art printed on its side (as its printed name shows) turned to read level. Tagging resumes at
  launch and after imports, skips quietly when Ollama is not running, and starts over when the model is changed.
  A pawn's tags show in its tooltip and preview. Pawns shown in the library grid are tagged first, then pawns
  needing a name, and for those alone the model also suggests a name of at most three words (R1.12). The user
  can correct a pawn's tags from its preview or context menu; tagging never changes corrected tags, even when
  the model is changed.
- R2.8 Space shows the selected pawn's front and back large over the window, with its name, size, products
  and tags. The arrow keys move the selection and the preview with it; Space, Escape or a click outside
  closes it.

## R3 Custom pawns
- R3.1 Library ▸ Add Custom Pawn… makes a pawn from an image (chosen, dropped, or pasted, such as one copied
  from Pluck) with a name and a size:
  small, medium, large, huge or gargantuan.
- R3.2 The image either fills the pawn (cropping what overflows) or fits whole above the name, with white
  around it; its position can be adjusted in a live preview either way.
- R3.3 The back is the mirrored front.

## R4 Sheets
- R4.1 A sheet is a document (`.pawnsheet`) with New, Open, Save and Open Recent.
- R4.2 A pawn is added to a sheet from the library with a number of copies.
- R4.3 The number of copies of each pawn can be raised or lowered, and a pawn removed.
- R4.4 The sheet's pages are previewed live as pawns are added and removed; a strip can be selected in the
  preview and deleted.
- R4.5 Strips are packed onto as many pages as needed, larger pawns first, within the printable area, upright
  or on their side, whichever takes fewer pages.
- R4.6 Each sheet has a cut style: shared cut lines (strips edge to edge, so one cut separates two pawns) or
  gaps (each strip outlined separately, with an adjustable gap). The fold line can be shown or hidden.
- R4.7 Paper size and margins come from File ▸ Page Setup… and are saved with the sheet.
- R4.8 A pawn missing from the library shows as a placeholder rather than breaking the sheet.

## R5 Output
- R5.1 File ▸ Export PDF… writes the pages at 100% scale.
- R5.2 File ▸ Print… prints the same pages without scaling.
- R5.3 Export and Print can override the sheet's cut style for that run.
- R5.4 Pawns from PDFs keep their vector labels and full-resolution art.

## R6 The app
- R6.1 macOS 15 or later.
- R6.2 The app has its own icon, legible at small sizes: a wizard on a pawn standing in its base.
