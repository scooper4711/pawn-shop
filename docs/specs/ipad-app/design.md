# iPad app: design

## Targets
- `PawnShopUI` (library) holds the SwiftUI app shared by both platforms. Platform code sits behind
  `#if os(macOS)` / `#if os(iOS)`, mostly in files of its own (`PadApp.swift`, `SheetPrinting.swift`,
  `LibraryModel+Choosing.swift`, `ImagePasteboard.swift`, `PlatformInput.swift`).
- `PawnShop` (Mac executable) is `main.swift` calling `PawnShopApp.main()`.
- `ios/PawnShop.xcodeproj` (scheme `PawnShop-iPad`) is the iPad and iPhone app. It links `PawnShopUI` from the
  local package and bundles `Generated/` (the item catalog, card art and fonts) as a folder resource, which
  `ItemCatalog` finds at `Bundle.main.resourceURL/Generated` as on the Mac. Signing, version and the App Group
  entitlement follow Field Guide's `ios/` folder.
- `PawnShopCore` builds for iOS. `ScrollkeeperFolder` uses security-scoped bookmark options only on the Mac
  (on iOS a bookmark to a picked folder always carries access) and `NSHomeDirectory()` where `getpwuid` fails.

## Scenes
- iOS: `DocumentGroup` with the same `SheetWindow`, and the `LibraryCommands` menu (shared with the Mac).
  `Info.plist` exports the `pawnsheet` and `sheet-content` types, supports the document browser and opening in
  place, and shares the Documents folder (`UIFileSharingEnabled`) so new sheets have a home.
- The toolbar gets a `LibraryMenu` (R2.1); Settings… is a sheet (`PadSettingsView`).
- `SheetWindow` hides the inspector while the window is narrower than 1100 points (R1.2), via
  `onGeometryChange`.

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
  screenshots. In the simulator a new document sometimes fails with "Unable to Import Document"; the test then
  opens one made earlier.
