# Pawn Shop: requirements

Paizo pawn PDFs are laid out for duplex printing, which rarely lines up, and a single sheet makes a floppy
pawn. Pawn Shop collects the pawns from those PDFs into a library and prints only the pawns you choose, each
as one strip on one side of the paper: the front below, the back above it turned 180°, head to head. The strip
is cut out and folded at the heads, giving a two-ply pawn.

## R1 Importing pawn PDFs
- R1.1 File ▸ Import PDF… and dropping PDFs on a window import them into the library.
- R1.2 Library ▸ Import from Scrollkeeper… finds every pawn, token and Battle Cards PDF in Scrollkeeper's
  downloads that is not yet imported and imports them all. A sandboxed Scrollkeeper keeps them in the Tableside
  Toolkit's shared App Group folder, which Pawn Shop reads without asking (Scrollkeeper's app-handoff
  requirements 5 and 6). When they are elsewhere (a folder the user chose in Scrollkeeper, or an older
  Scrollkeeper's `~/Library/Application Support/Scrollkeeper/Files`), the app asks the user to choose the folder
  the first time (the App Sandbox only lets it read folders the user picks), starting in it, and remembers the
  choice.
- R1.3 Every pawn in the PDF is found from its red cut outline, named from the label printed inside it, and
  sized (small, medium, large, huge) from the outline.
- R1.4 Each pawn's back is taken from the mirrored position on the following page. When there is none, the
  back is the front mirrored.
- R1.5 Pawns printed sideways are turned upright.
- R1.6 A pawn is a duplicate only when its artwork matches. Copies of the same art (on one page or reprinted
  in another product) are stored once; pawns with the same name and different art (1e and 2e, Pathfinder and
  Starfinder, variants) are kept apart.
- R1.7 Importing a PDF that is already in the library changes nothing, except a PDF read by an older version of
  the reader: it is read again once by each newer version, so improvements reach it. A PDF that gave no pawns is
  imported afresh, with no copy of it kept (R1.9) while it gives none; one that gave pawns keeps them, with their
  names, tags and corrections, gains the pawns found anew and loses those the newer reader no longer finds, each
  product listed once per pawn. At launch, the PDFs an older reader read are read again without being asked, in
  the background with progress, from the files they were imported from; one whose file can't be reached waits
  for its next import. A reading that finds nothing where pawns were found changes nothing and says so.
- R1.8 Importing shows progress, then a report of the pawns added, the pawns whose art was already in the
  library, and the outlines with no name printed.
- R1.9 The library keeps its own copy of each imported PDF, so pawns survive the original being moved. A PDF
  another app read from where it is gains a copy when Pawn Shop imports it.
- R1.10 Pawns with no name printed are imported as "Unknown <product title>" and marked as needing a name.
- R1.11 Heroes & Villains is the one product known to print no names. Its pawns take the name of the same art
  in another product, whichever is imported first; the rest need naming.
- R1.12 Library ▸ Review Unnamed Pawns… steps through the pawns needing a name, showing each large with its
  tags (R2.7) and a name field filled in with the name the tagging model suggests, so Return accepts it. Each
  name is saved as it is entered, so the review can be closed and resumed at any time.
- R1.13 Round tokens (token boxes such as the Alien Core Token Box, and adventures' token sheets) are imported
  as pawns, since folded pawns look better than flat tokens. A token is found from the circle its art is
  clipped to, sized from its cut circle (up to 1" medium, 2" large, 3" huge, larger gargantuan), and named
  from the label on the mirrored back page, or else from the name printed along its rim. The token's art is
  kept alone, without the page background, the cut line or the printed name, and printed as large as it fits
  above the pawn's name on white. A back page repeating the art gives the pawn's back; otherwise the back is
  the front mirrored.

- R1.14 Battle Cards (a PDF, or the folders it is in, named "… Battle Cards") are imported as pawns, so a deck
  bought without its pawns still gives pawns. A deck may be one PDF, with each card's art before its stat block
  or runs of stat blocks each followed by the same cards' art, or two PDFs ("… FRONT" with the stat blocks,
  "… BACKS" with the art), paired page by page (an art page prints no words or only a short credit, such as
  "Illustration by …"); importing either PDF of a pair imports the deck once. Each
  card's creature (the last picture of its own that its art side draws, transparent around the figure, not
  the background, frame or badges every card shares) is drawn alone, trimmed to its opaque part, as large
  as it fits above the pawn's name on white, standing on it. Its name comes from the stat block (Pathfinder:
  before "CREATURE n"; Starfinder: before "CR n" or "XP n"), its size from its size (up to medium a medium
  pawn, colossal a gargantuan one), and its traits from the trait line (Starfinder: size, type and subtypes),
  without rarity and alignment; traits show in the pawn's tooltip and preview. Hazards, continued stat blocks
  and rules pages are skipped.
- R1.15 A Battle Card and a pawn (or two decks' cards) showing the same painting are one pawn: the names match
  (equal, or the same after the last comma when at most one names a family, as "Elemental, Air, Invisible
  Stalker" and "Elemental, Invisible Stalker" do) and the figures' colors match. The pawn is drawn from
  whichever picture has more pixels, which is usually the card's, takes the printed pawn's size, and gains
  the card's traits. The import report counts the pawns that now use sharper art.
- R1.16 Pawns printed without cut outlines (the second half of the Monster Core Pawn Box, Dawn of Flame) are
  found from their pictures and the labels along their feet, as Tabletop Kit reads them, and drawn alone above
  their name on white, turned upright, like Battle Cards' creatures. Their size is estimated from the picture.
  Pages printed as one flattened picture (the second half of the NPC Core Pawn Box) are named in the import
  summary.

## R2 The library
- R2.1 The library is kept between launches and shared by every sheet. It is the art library Pawn Shop,
  Turnkeeper and Field Guide share (tabletop-kit shared libraries R1, R3): a PDF any of them read shows its pawns
  here without importing it again, and what another app changes shows while Pawn Shop is open, within a second.
- R2.1.1 Names, tags and tag corrections are kept with the shared art, so they help the other apps, and theirs
  show here (shared libraries R3.3). A custom pawn is a custom creature in the shared creature library (R3.4);
  how its art sits on its pawn, its tags, the sheets and the settings stay Pawn Shop's own (R3.5 and R4.8 there).
- R2.1.2 A pawn whose PDF Pawn Shop can't reach (another app read it from a file Pawn Shop wasn't given, or
  another device read it, R10) shows and prints from the picture saved with the art: the figure alone, as large as
  it fits above the pawn's name on white, standing on it, like a Battle Card's creature (R1.14), with the back the
  front mirrored. Importing the PDF here prints it at full resolution again (R5.4).
- R2.2 Search finds the pawns whose name, product titles, traits (R1.14) and tags (R2.7) together contain every
  word typed, anywhere in a word and ignoring case and accents, so "sword" also finds "longsword".
- R2.3 Results can be filtered by size and by product.
- R2.4 Pawns with the same name are shown next to each other with their product, so the art can be compared.
- R2.5 A pawn can be removed from the library, or renamed: Rename… is in its context menu and its preview
  (R2.8). A blank name changes nothing. Removing a pawn read from a PDF hides it in Pawn Shop and leaves the art
  to the other apps. Removing a custom pawn deletes its creature and art in every app (shared libraries R4.9),
  after Pawn Shop asks; where Turnkeeper shares the library on this device, the question says that the creature
  will be deleted from Turnkeeper and removed from all its encounters. A custom pawn whose creature has a stat block is only hidden, as a
  pawn read from a PDF is.
- R2.6 Results can be filtered by game (Pathfinder or Starfinder) and to custom pawns only.
- R2.7 Each pawn is tagged in the background with keywords for what its art adds to its name and traits
  (weapons, shields, armor, notable gear and clothing, animals with it, striking features) by a vision model
  running locally in Ollama. The model is told the pawn's name and traits and asked not to repeat them, and
  keywords made up only of words of the name and traits are left out, as search finds those anyway. Tagging
  never gives a gender. The art is shown without the printed name in view, and art printed on its side (as its
  printed name shows) is turned to read level. Tagging resumes at launch and after imports, skips quietly when
  Ollama is not running, and starts over when the model or the prompts (`TaggingPrompt.version`) change.
  A pawn's tags show in its tooltip and preview. Pawns shown in the library grid are tagged first, then pawns
  needing a name, and for those alone the model also guesses the ancestry or kind and role, and suggests a name
  of at most three words (R1.12). The user
  can correct a pawn's tags from its preview or context menu; tagging never changes corrected tags, even when
  the model is changed.
- R2.8 Space shows the selected pawn's front and back large over the window, with its name, size, products,
  traits and tags. The arrow keys move the selection and the preview with it; Space, Escape or a click outside
  closes it.
- R2.10 Clicking a tile selects it immediately. Dragging a tile, or the selection when the tile is part of it,
  from the library onto the sheet adds the add bar's number of copies of each, as a double-click does; this holds for pawns, items and spells.
- R2.9 Tagging is turned on and off in Settings; it is off until turned on, as it needs Ollama, which most
  people won't have. Turning it off stops tagging
  after the pawn in hand and keeps it from starting at launch, after imports or from Library ▸ Tag New Pawns;
  turning it back on resumes it. Settings shows how many of the library's pawns are tagged and how many are
  left, and while tagging runs the library shows a progress bar, with the numbers in its tooltip.
- R2.11 Settings has the model's name and the Ollama server's address, with `gemma3:12b` and
  `http://localhost:11434` used when they are empty or the address isn't an http or https one. A change takes
  effect on Return or on leaving the field: tagging carries on with the new model or server, and a new model
  tags every pawn again (R2.7). Settings says where the pictures go: this Mac, or the server's host.
- R2.12 Settings says that tagging is optional and that search works on names, products and traits without it,
  and links to `docs/tagging.md` in the repository: installing Ollama, the model to choose for the Mac's
  memory, using the keywords, and what to do when it fails. When tagging stops, Settings and the library's
  warning say what to do: that Ollama wasn't found at the server's address, or the `ollama pull` command for a
  model that isn't installed.
- R2.13 A server on the user's own network (a `.local` name or an IP address) can be reached over plain HTTP;
  any other needs HTTPS.
- R2.14 A pawn read from a PDF has the same ID on every device that imports the PDF, in any order of import: its
  art's ID (tabletop-kit shared libraries R2), from the picture Paizo embedded and the name printed with it. A pawn
  holding art printed by several products answers to the ID of each print. A custom pawn has its creature's
  random ID (R3.4).
- R2.15 The first launch of this version gives the library's pawns their IDs in place, without reading a PDF
  again. Each pawn keeps its old ID as an alias, so sheets saved before still find it, and the library file
  as it was is kept beside it (`library-v1.json`). Pawns whose art and name turn out to be the same merge, such as
  "Planetoid, Beetle" and "Planetoid Beetle". Moving into the shared library (R2.16) carries the aliases with it.
- R2.16 The first launch of the version using the shared library moves Pawn Shop's library into it once
  (shared libraries R6): every pawn keeps its ID and old IDs, its name, tags, corrections and products, and the kept
  PDFs and token pictures move rather than copy. Custom pawns move in a step of their own (R3.7). The PDFs whose other
  products' pawns Pawn Shop doesn't record by place are then read again in the background from Scrollkeeper's
  folder, with progress, so each pawn lists every product again; one it can't reach is read at the next Import
  from Scrollkeeper. Nothing the user sees changes otherwise. A move cut short says why and finishes at the next
  launch.

## R3 Custom pawns
- R3.1 Library ▸ Add Custom Pawn… makes a pawn from an image (chosen, dropped, or pasted, such as one copied
  from Pluck) with a name and a size, one of Paizo's six: tiny, small, medium, large, huge or gargantuan. Tiny
  prints the same pawn as Small.
- R3.2 The image either fills the pawn (cropping what overflows) or fits whole above the name, with white
  around it; its position can be adjusted in a live preview either way.
- R3.3 The back is the mirrored front.
- R3.4 A custom pawn is a custom creature in the creature library Pawn Shop shares with Turnkeeper and Field
  Guide (tabletop-kit shared libraries R4.6): a name, a size and art, without a stat block, under one ID.
  Turnkeeper lists it with its other custom creatures and can give it a stat block.
- R3.5 Every custom creature with art is a pawn here, with the creature's name and its size's pawn (Medium for
  a creature without one of the six sizes), whichever app made it; one without art is left out. Art given to a
  creature in Turnkeeper shows here within a second, drawn from the image the user added, or as the pawn of the
  art chosen for it from the library is. Pasted art on a creature from a bestiary is not a pawn.
- R3.6 Renaming a custom pawn renames its creature in every app, and a rename made in Turnkeeper shows here. The
  image's placement and scaling, whether the name is printed, and the tags are Pawn Shop's own (shared libraries
  R4.8); a creature made in Turnkeeper starts filled, centered and with its name printed. Changing the size after
  adding comes with editing a custom pawn (issue #20).
- R3.7 The first launch of this version moves the custom pawns into the creature library, once (shared libraries
  R6.6): each keeps its ID, name and size, so sheets saved before keep finding it, and its image moves rather
  than copies. A move cut short finishes at the next launch.

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
- R4.8 A pawn missing from the library shows as a placeholder rather than breaking the sheet. The placeholder
  and the sheet's list say what is missing, "Goblin Warrior, from Pathfinder Pawns: Monster Core Pawn Box", when
  the sheet was saved with the pawn in the library.
- R4.10 A sheet saves each pawn's ID with its name and product, never its art at printing quality (shared
  libraries R2.9); the only pictures it carries are its low-resolution page previews (R12). A sheet
  saved before stable IDs (R2.14) is pointed at the pawns' new IDs and labeled when it is opened.
- R4.9 A sheet can leave room for a base: blank paper below the foot of each face, front and back, so a base's
  slot hides it rather than the bottom of the name. The faces keep their size and the strip grows. The room
  is set in millimeters, defaults to 6 mm (the depth of the slot in the bases the app comes with, R7), and is
  off by default; it is saved with the sheet and can be changed when exporting or printing (R5.3).

## R5 Output
- R5.1 File ▸ Export PDF… writes the pages at 100% scale.
- R5.2 File ▸ Print… prints the same pages without scaling.
- R5.3 Export and Print can override the sheet's cut style for that run.
- R5.4 Pawns from PDFs keep their vector labels and full-resolution art.

## R6 The app
- R6.1 macOS 15 or later.
- R6.2 The app has its own icon, legible at small sizes: a wizard on a pawn standing in its base.
- R6.3 When it opens, the app asks GitHub whether a newer version has been released, and says so only when
  there is one. A switch in Settings turns this off.
- R6.4 Pawn Shop › Check for Updates… checks at any time and always reports the result. A newer version is
  downloaded to the Downloads folder only when the user agrees.
- R6.5 Pawn Shop › About Pawn Shop shows the notice Paizo's Community Use Policy requires, the Paizo
  Compatibility License's trademark line, credits for the item text, the Rexard art and the action icon font, and
  a link for reaching the author, then the full texts of the Open Game License and the ORC License the item text is
  used under. The README carries the same notices.
- R6.6 The app runs in the App Sandbox. On its first sandboxed launch the library and the settings move into the
  app's container; nothing else changes for the user.

## R7 Pawn bases
- R7.1 The disk image holds a Pawn Bases folder with ready-to-print STL bases for medium, large, huge and
  gargantuan pawns, each labeled 1–4 and blank, a slot test piece, and the OpenSCAD sources.
- R7.2 The base's size, label and slot curvature, and the slot width, are OpenSCAD Customizer parameters: a
  size dropdown, a label text field, and sliders.
- R7.3 A label of any length fits its flat spot: one character is full size, longer ones shrink.

## R8 Item cards
Players forget the consumables they are given at the table; a printed card for each is a reminder to use it.
- R8.1 The library pane has a Pawns | Items switch. Items lists every Pathfinder and Starfinder item from the
  pf2e system's equipment packs (consumables, weapons, armor, shields, ammunition, gear, treasure), searchable
  by name, trait and category, and filtered by game, kind (consumables by default) and level.
- R8.2 An item is added to a sheet with a number of copies, as a pawn is; one sheet holds pawns and item cards
  together, and they are packed together (R4.5).
- R8.3 An item prints as single-sided cards the size of Paizo's item decks (63 × 88 mm), cut like strips
  (R4.6) and with no fold line. Top to bottom: the name with "ITEM n", the traits (rarity first when it isn't
  common), the description, with Paizo's action icons for actions, a table of stats in a set order, and the
  source book. The stats are Level, Price, Bulk, Usage and Uses, then for weapons Damage, Hands, Range, Reload
  (left out when there is none) and Group, for armor AC, Dex Cap, Strength, Check and Speed, and for shields
  Hardness, HP and BT; empty ones are left out.
- R8.3.1 Every card's text is the same size, 7 points, close to Paizo's cards. Text that overruns its card by a
  little is set smaller instead, for that item's cards, down to the smallest size chosen in Settings › Item Cards
  (6.5 to 5.5 points, 6.25 unless changed), whenever that saves a card. Text that is longer still
  continues on a second card, or a third: the first card has the traits, stats and art, and every card the title
  and the text. Cards break between paragraphs, moving a paragraph whole to the next card unless that would leave
  much of the card empty, and otherwise between lines; a Heightened entry is never split. Each card of a set
  says "Card 1 of 3" after the source. Copies are of whole sets: two copies of a three-card spell are six cards,
  each set together.
- R8.4 The card's look comes from UI art in the Rexard packs, so cards use no Paizo art when the user owns no item
  deck: parchment in a wooden frame under a ribbon for Pathfinder; for Starfinder a light card, pale cyan with a
  thin cyan frame, the packs' dark corner brackets and a cyan name bar, with dark text, since a dark card prints
  poorly on an inkjet. Without that art, cards are drawn on white with a gray frame.
- R8.5 Item decks are imported like Battle Cards (R1.2, R1.14), including decks sold as pictures (a folder of
  JPGs). Their art adds no pawns; when a deck prints an item's art, the item's card shows it behind the text,
  40% opaque unless set otherwise in Settings › Item Cards (from none to solid, with a card to see it on). An item finds deck art printed under its own name, or else under its name without its grade ("Healing
  Potion (Minor)" finds "Healing Potion"), or under the name it had before the remaster, from the pf2e
  system's list of renamed items ("Thunderstone" is "Blasting Stone").
- R8.6 The item list, the Rexard art and the action icon font are built from local copies of the pf2e
  repository and the Rexard packs into `Generated/`, which is not committed, and bundled into the app; without
  it the Items list says how to build it. The item text is used under the ORC and OGL licenses, whose notices
  ship with it.
- R8.7 Settings › Item Cards has "Print card backgrounds", on by default. Off, item and spell cards print on
  white with a gray frame and a plain title bar, without the Rexard parchment, panel, ribbon and frame, to save
  ink; the art behind the text (R8.5) is unaffected.

## R9 Spell cards
Players forget what their spells do, and scrolls and wands carry spells too; a card for each spell is a
reminder at the table, whatever holds the spell.
- R9.1 The library pane's switch is Pawns | Items | Spells. Spells lists every Pathfinder and Starfinder spell,
  cantrip, focus spell and ritual from the pf2e system's spell packs, searchable by name, trait and book, and
  filtered by game, kind, rank and tradition.
- R9.2 A spell is added to a sheet with a number of copies, like an item, and prints as item cards do (R8.3.1,
  R8.4, R8.7), with "SPELL n", "CANTRIP n", "FOCUS n" or "RITUAL n" by the name. Under the traits come its
  stats as the books print them: Traditions, Cast (with the action icons), Range, Area, Targets, Defense and
  Duration ("sustained up to 1 minute"), with Cost and Requirements when it has them (a reaction's Trigger opens
  its text, as pf2e keeps it), and for a ritual Secondary Casters, Primary Check and Secondary Checks; empty ones
  are left out. Then the text, with its
  Heightened entries, and the source book.
- R9.3 A spell prints at its own rank: formulas on its rank are worked out ("1d6", not
  "floor(@item.level/2)d6"), and links that only apply effects in Foundry are left out.

## R10 Syncing between devices
The library is the same on the user's Macs, iPads and iPhones, so a sheet made on one opens complete on another
(issue #30). The shared art library's side is tabletop-kit's library sync; this is what Pawn Shop adds to it.
- R10.1 The art read from PDFs, with the names, tags and tag corrections given to pawns, syncs through the
  Tableside Toolkit's container in the user's private iCloud database (library sync R1, R2), whichever of the
  suite's apps is open. The PDFs never leave the device, and nothing is sent to anyone but the user's own iCloud.
- R10.2 Custom pawns sync as well, under the ID they have, so a sheet finds one on every device. The creature's
  name and size and its image sync with the creature library (library sync), and Pawn Shop adds what is its own:
  the image's placement and scaling, whether the name is printed, and the tags. Removing a custom pawn removes
  it everywhere. Of two changes to one pawn's placement or tags on two devices the later wins; they stay on a
  device that has a change to them still to send when another device removes them, and are sent again.
- R10.3 A device without a pawn's PDF draws the pawn from its saved picture (R2.1.2), on screen, in exported PDFs
  and in print. The picture is the figure as its PDF embeds it, about 300 pixels per inch at the pawn's size, up to
  1,024 pixels on its long side, which only the largest figures pass; so it prints about as sharply as from the
  PDF, without the frame and label printed around it there.
- R10.4 A picture the device doesn't have downloads from iCloud when its pawn is first shown (library sync R4.2).
  Opening a sheet, exporting and printing ask for every picture the sheet lacks at once. Until a picture arrives
  its pawn shows a placeholder, and tiles and pages are drawn again when it does. A picture no device has uploaded
  yet is asked for again every minute while its pawn is on screen or its sheet is open. Without a connection the
  placeholder stays, and an export or a print goes ahead with it.
- R10.5 Settings › Sync says whether the library syncs and, when it doesn't, why: the build has no iCloud, nobody
  is signed in to iCloud, iCloud is full, syncing is paused (R10.7), or it stopped after an error until the app
  next opens.
- R10.6 Settings › Sync sets how many downloaded pictures the device keeps (library sync R4.7, R4.9): those shown,
  with no limit (the default) or up to 250 MB, 500 MB, 1 GB or 2 GB, the least recently shown going first; or every
  picture, downloaded ahead of time, for use without a connection. It shows the size of the downloaded pictures and
  removes them on request; each comes back when next shown. The setting is the device's: Turnkeeper and Field Guide
  share it, so Pawn Shop sets no default of its own.
- R10.7 After the user deletes the library's iCloud data in the system's settings, syncing pauses on that device.
  Settings › Sync says so and offers to turn it back on, which uploads the library again (library sync R5.3).
- R10.8 Without iCloud the app works on the device alone, as before (library sync R2.4). A library opened with
  `PAWN_SHOP_LIBRARY` never syncs.
- R10.9 Not synced: pawns removed from Pawn Shop only (R2.5), which stay removed on that device alone; sheets,
  which are documents in iCloud Drive instead (R11); and settings. An item deck's art (R8.5) shows only on a device that has the
  deck.
- R10.10 A build syncs only when it is signed with the iCloud entitlements and names the container in its
  `Info.plist` (library sync R6): the iPad and iPhone app, the Mac App Store app, and a Developer ID build given a
  provisioning profile. Any other build works on the device alone.

## R11 Sheets in iCloud Drive
Sheets are documents, so they live in iCloud Drive rather than in the library (issue #29), and the same sheet opens on
each of the user's devices.
- R11.1 Pawn Shop has a folder of its own in iCloud Drive, named "Pawn Shop", as Pages and Numbers have. It
  appears in Finder and the Files app once the app has run with iCloud Drive on, before the first sheet is saved.
- R11.2 Saving a new sheet offers the Pawn Shop folder first: the Mac's save panel opens there, and the iPad's and
  iPhone's document browser creates new sheets there.
- R11.3 Sheets saved anywhere else open and save as before. Nothing is moved into the folder.
- R11.4 A sheet opened on another device, or by someone else, names each pawn that device's library lacks (R4.8)
  until its picture arrives (R10.4); it never shows a blank.
- R11.5 The folder is in the iPad and iPhone app and the Mac App Store app, and in a Developer ID build whose
  provisioning profile allows the folder's iCloud container. Any other build saves where the user chooses, as before.
- R11.6 Without iCloud Drive, or signed out of iCloud, sheets save on the device as before.

## R12 Sheets in Files and Quick Look

- R12.1 A saved sheet carries one small JPEG per page, 612 pixels wide, for at most 24 pages. They are too coarse to
  print or to serve as a copy of the art.
- R12.2 The pictures are drawn when the sheet is saved, so they always match it. Drawing them is not an edit: it is
  never undone and never marks a sheet as changed. A sheet saved earlier shows the app's document icon until it is
  next edited and saved.
- R12.3 A device lacking a pawn, a pawn's picture or an item of the sheet keeps the pictures already in the file
  rather than drawing placeholders. An item's card without art from an item deck counts as complete.
- R12.4 A sheet's thumbnail in Files on the iPhone and iPad, and in Finder on the Mac, is its first page, and Quick
  Look shows its saved pages on each.
- R12.5 Pictures that can't be read never stop a sheet from opening.
