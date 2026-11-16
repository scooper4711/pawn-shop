# iPad app: requirements

Pawn Shop also runs on the iPad (and the iPhone, with the same layout in a compact width). It builds the same
library and prints the same sheets as the Mac app.

## R1 Sheets
- R1.1 Sheets are `.pawnsheet` documents in the system document browser, created, opened and saved as on the
  Mac, in On My iPad › Pawn Shop, iCloud Drive or wherever Files reaches.
- R1.2 A sheet shows the library, the pages and the inspector side by side. Where three columns don't fit
  (portrait), the inspector is hidden and opens from the toolbar, so it never covers the pages.
- R1.3 Pawns, items and spells are added by double-tapping, by dragging, or with Add to Sheet.

## R2 Library
- R2.1 The Library button in the toolbar has the Mac's Library menu: Import PDF…, Import from Scrollkeeper, Tag
  New Pawns, Review Unnamed Pawns…, Add Custom Pawn…, and also Export PDF… and Settings…. With a keyboard the
  Library menu is in the menu bar too.
- R2.2 Import PDF… shows the file browser for PDFs, JPEGs and folders (item decks sold as pictures), several at a
  time.
- R2.3 Import from Scrollkeeper reads Scrollkeeper's downloads from the Tableside Toolkit's App Group, where
  Scrollkeeper on the iPad keeps them. Without them it asks once for the folder in Files and remembers it.
- R2.4 Add Custom Pawn takes an image from the file browser or the clipboard.
- R2.5 Long-pressing a pawn shows the Mac's context menu, with Rename… and Edit Keywords….
- R2.6 Every sheet that asks something (Rename, Edit Keywords, Add Custom Pawn, Review Unnamed Pawns, and the
  Print and Export options) shows its title and its buttons in a bar at its top.

## R3 Printing
- R3.1 The iPad has no Page Setup. The inspector's Paper menu lists US Letter, US Legal, A4, A3 and Tabloid,
  each with a ¼ in margin; the sheet keeps its paper as on the Mac.
- R3.2 Print shows the system print panel and prints every page at 100%: pages are never scaled to the printer's
  printable area, and the printer is asked for the sheet's paper.
- R3.3 Export saves the sheet as a PDF through the system file browser.

## R4 Settings
- R4.1 Settings… shows the Mac's Tagging and Item Cards settings and the About screen.
- R4.2 Tagging can reach an Ollama server on the local network.

## R5 Unchanged
- R5.1 The updater stays Mac-only (the iPad app comes from the App Store).
- R5.2 The Mac app keeps working as before.
