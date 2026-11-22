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

    @MainActor
    func testSheet() throws {
        app.launch()
        app.openSheet()
        app.buttons["Items"].firstMatch.tap()
        for name in ["Ablative Armor Plating (Lesser)", "Ablative Armor Plating (Major)",
                     "Ablative Shield Plating (Lesser)", "Ablative Shield Plating (Major)",
                     "Absolute Solvent (Lesser)", "Abysium Powder"] {
            let card = app.staticTexts[name]
            XCTAssertTrue(card.waitForExistence(timeout: 10), app.debugDescription)
            card.doubleTap()
        }
        try save("1-library")
        guard UIDevice.current.userInterfaceIdiom == .phone else { return }
        app.tabBars.buttons["Pages"].tap()
        try save("2-pages")
    }

    private func save(_ name: String) throws {
        Thread.sleep(forTimeInterval: 1.5)
        let file = folder.appendingPathComponent("\(name).png")
        try XCUIScreen.main.screenshot().pngRepresentation.write(to: file)
    }
}
