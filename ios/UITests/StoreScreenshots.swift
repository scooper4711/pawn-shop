import XCTest

/// The App Store's pictures, from the app's demo content: tabletop-kit's `store-screenshots.sh`.
/// Skipped unless the script names the folder to save into.
final class StoreScreenshots: XCTestCase {
    private var app: XCUIApplication!
    private var folder: URL!

    override func setUpWithError() throws {
        let path = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] ?? ""
        try XCTSkipIf(path.isEmpty, "Set SCREENSHOT_DIR to make the store screenshots.")
        folder = URL(fileURLWithPath: path)
        continueAfterFailure = false
        app = XCUIApplication()
        XCUIDevice.shared.orientation = .portrait
    }

    /// Every iconic on a sheet, from a library of Paizo's Community Use iconics that `STORE_LIBRARY` names.
    @MainActor
    func testPawns() throws {
        let library = try copyOfStoreLibrary()
        defer { try? FileManager.default.removeItem(at: library) }
        app.launchEnvironment["PAWN_SHOP_LIBRARY"] = library.path
        app.launch()
        newSheet(named: "Untitled 2")
        app.buttons["Pawns"].firstMatch.tap()
        for name in Self.iconics { addToSheet(name) }
        try save("1-iconics")
        guard UIDevice.current.userInterfaceIdiom == .phone else { return }
        app.tabBars.buttons["Pages"].tap()
        try save("2-iconics-pages")
    }

    @MainActor
    func testItems() throws {
        app.launch()
        newSheet(named: "Untitled")
        app.buttons["Items"].firstMatch.tap()
        for name in ["Ablative Armor Plating (Lesser)", "Ablative Armor Plating (Major)",
                     "Ablative Shield Plating (Lesser)", "Ablative Shield Plating (Major)",
                     "Absolute Solvent (Lesser)", "Abysium Powder"] {
            addToSheet(name)
        }
        try save("3-items")
    }

    private static let iconics = ["Ezren", "Feiya", "Fumbus", "Harsk", "Jirelle", "Korakai", "Kyra", "Lem", "Lini",
                                  "Merisiel", "Quinn", "Sajan", "Seelah", "Seltyiel", "Seoni", "Valeros", "Yoon"]

    private func copyOfStoreLibrary() throws -> URL {
        let path = ProcessInfo.processInfo.environment["STORE_LIBRARY"] ?? ""
        try XCTSkipIf(path.isEmpty, "Set STORE_LIBRARY to the library to show.")
        let copy = FileManager.default.temporaryDirectory
            .appendingPathComponent("StoreScreenshots-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.copyItem(at: URL(fileURLWithPath: path), to: copy)
        return copy
    }

    /// In the simulator a new document sometimes fails with "Unable to Import Document" though its file was made, or
    /// the tap does nothing: the sheet is then opened from the browser, or made again. `testItems` runs first, so it
    /// makes "Untitled".
    @MainActor
    private func newSheet(named name: String) {
        let create = app.buttons["Create Document"]
        let pawns = app.buttons["Pawns"].firstMatch
        XCTAssertTrue(create.waitForExistence(timeout: 15), app.debugDescription)
        for _ in 0..<4 {
            create.tap()
            if pawns.waitForExistence(timeout: 6) { return }
            openAfterFailedImport(named: name)
            if pawns.waitForExistence(timeout: 6) { return }
        }
        XCTFail("No sheet could be made or opened: \(app.debugDescription)")
    }

    @MainActor
    private func openAfterFailedImport(named name: String) {
        let failure = app.alerts["Unable to Import Document"]
        guard failure.exists else { return }
        failure.buttons["OK"].tap()
        let identifier = NSPredicate(format: "identifier BEGINSWITH %@", "\(name).pawnsheet")
        let sheet = app.cells.matching(identifier).firstMatch
        if sheet.waitForExistence(timeout: 3) { sheet.tap() }
    }

    @MainActor
    private func addToSheet(_ name: String) {
        let tile = app.staticTexts[name].firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 15), app.debugDescription)
        for _ in 0..<8 where !tile.isHittable {
            app.scrollViews.firstMatch.swipeUp(velocity: .slow)
        }
        tile.doubleTap()
    }

    private func save(_ name: String) throws {
        Thread.sleep(forTimeInterval: 1.5)
        let file = folder.appendingPathComponent("\(name).png")
        try XCUIScreen.main.screenshot().pngRepresentation.write(to: file)
    }
}
