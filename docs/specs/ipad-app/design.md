# iPad app: design

## Targets
- `PawnShopUI` (library) holds the SwiftUI app shared by both platforms. Platform code sits behind
  `#if os(macOS)` / `#if os(iOS)`, mostly in files of its own (`PadApp.swift`, `SheetPrinting.swift`,
  `LibraryModel+Choosing.swift`, `ImagePasteboard.swift`, `PlatformInput.swift`).
- `PawnShop` (Mac executable) is `main.swift` calling `PawnShopApp.main()`.
- `ios/PawnShop.xcodeproj` (scheme `PawnShop-iPad`) is the iPad and iPhone app. It links `PawnShopUI` from the
  local package and bundles `Generated/` (the item catalog, card art and fonts) as a folder resource, which
  `ItemCatalog` finds at `Bundle.main.resourceURL/Generated` as on the Mac. Signing, version, the App Group
  entitlement and the iCloud entitlements (pawn-shop design, "Syncing") follow Field Guide's `ios/` folder.
- `PawnShopCore` builds for iOS. `ScrollkeeperFolder` uses security-scoped bookmark options only on the Mac
  (on iOS a bookmark to a picked folder always carries access) and `NSHomeDirectory()` where `getpwuid` fails.

## Scenes
- iOS: `DocumentGroup` with the same `SheetWindow`, and the `LibraryCommands` menu (shared with the Mac).
  `Info.plist` exports the `pawnsheet` and `sheet-content` types, supports the document browser and opening in
  place, and shares the Documents folder (`UIFileSharingEnabled`) so new sheets have a home.
- The toolbar gets a `LibraryMenu` (R2.1); Settings… is a sheet (`PadSettingsView`).
- iOS shows a sheet's toolbar items only in a navigation bar, so the sheets that ask something end with
  `sheetToolbar(title:)`, which puts them in a `NavigationStack` with an inline title on iOS and leaves them
  as they are on the Mac, where the buttons sit at the sheet's foot (R2.6).
- `SheetWindow` hides the inspector while the window is narrower than 1100 points (R1.2), via
  `onGeometryChange`.
- In a compact horizontal size class `SheetWindow` shows a `TabView` of the same three views in place of the
  `NavigationSplitView` (R1.4): a split view there folds down to its sidebar, with no way to the detail or to
  the toolbar that sits on it.

## Choosing files
`LibraryModel.chooseAndImportPDFs()` and `askForScrollkeeperFolder()` show open panels on the Mac. On iOS they
set `isChoosingPDFs` / `isChoosingScrollkeeperFolder`, which `LibraryImporters` binds to file importers.
`importPDFs` starts security-scoped access to what was chosen and stops it when the imports are done; a picked
Scrollkeeper folder keeps its access until the app quits, as a remembered one does.

## Printing and export
- Export renders the PDF and presents `.fileExporter` with a `SheetPDF` on both platforms (on the Mac it replaces
  the modal save panel).
- `SheetOutput.print` on iOS uses `ActualSizePrinter`: `UIPrintInteractionController` with a
  `UIPrintPageRenderer` that draws each page at the paper's origin with no scaling, and a delegate whose
  `choosePaper` picks `UIPrintPaper.bestPaper(forPageSize:withPapersFrom:)` for the sheet's paper. Mapsmith's iPad
  app prints the same way; it moves to tabletop-kit when a third app needs it.
- `NamedPaper` (core) lists the paper sizes; `PaperSetup.named` reads and sets one (R3.1).

## Testing
- Unit tests cover `NamedPaper`.
- `ios/UITests` opens a sheet in both orientations, opens the Library menu and adds an item card, keeping
  screenshots. `CompactLayoutUITests` runs on an iPhone simulator only (`IPAD_SIMULATOR="iPhone 18 Pro"`) and
  checks the toolbar and the tabs. In the simulator a new document sometimes fails with "Unable to Import
  Document"; the test then opens one made earlier.
- `RenameUITests` writes a library with one custom pawn to a temporary folder, points the app at it with
  `PAWN_SHOP_LIBRARY`, and renames the pawn from its menu, checking that the sheet's Rename button is on screen.
