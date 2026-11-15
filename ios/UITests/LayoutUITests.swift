import XCTest

/// A new sheet in both orientations: the library, the page and the inspector, and the Library menu. Each test
/// keeps a screenshot in the test results.
final class LayoutUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
        super.tearDown()
    }

    func testSheetInLandscape() {
        showNewSheet(.landscapeLeft)
    }

    func testSheetInPortrait() {
        showNewSheet(.portrait)
    }

    func testLibraryMenuOffersImportAndSettings() {
        showNewSheet(.landscapeLeft)
        app.buttons["Library"].firstMatch.tap()
        for action in ["Import PDF…", "Import from Scrollkeeper", "Add Custom Pawn…", "Settings…"] {
            XCTAssertTrue(app.buttons[action].waitForExistence(timeout: 5), "No \(action) in the Library menu")
        }
        keepScreenshot("Library menu")
    }

    func testItemsCanBeAddedToTheSheet() {
        showNewSheet(.landscapeLeft)
        app.buttons["Items"].firstMatch.tap()
        let search = app.searchFields.firstMatch.exists ? app.searchFields.firstMatch : app.textFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10), app.debugDescription)
        let card = app.staticTexts["Ablative Armor Plating (Lesser)"]
        XCTAssertTrue(card.waitForExistence(timeout: 10), app.debugDescription)
        card.doubleTap()
        // The page with the card replaces the empty sheet's hint.
        XCTAssertTrue(app.staticTexts["Empty Sheet"].waitForNonExistence(timeout: 10), app.debugDescription)
        keepScreenshot("Items")
    }

    private func showNewSheet(_ orientation: UIDeviceOrientation) {
        XCUIDevice.shared.orientation = orientation
        app.launch()
        createDocument()
        XCTAssertTrue(app.buttons["Pawns"].firstMatch.waitForExistence(timeout: 15), app.debugDescription)
        XCTAssertTrue(app.buttons["Print"].firstMatch.waitForExistence(timeout: 5), app.debugDescription)
        keepScreenshot("New sheet, \(orientation == .portrait ? "portrait" : "landscape")")
    }

    /// The document browser comes first: a sheet an earlier test made opens, or else a new one. In the simulator a
    /// new document sometimes fails with "Unable to Import Document"; the test then opens one that was made.
    private func createDocument() {
        let create = app.buttons["Create Document"]
        guard create.waitForExistence(timeout: 10) else { return }
        let existing = app.cells.matching(NSPredicate(format: "identifier CONTAINS '.pawnsheet'")).firstMatch
        if existing.waitForExistence(timeout: 3) {
            existing.tap()
            return
        }
        create.tap()
        let failure = app.alerts["Unable to Import Document"]
        if failure.waitForExistence(timeout: 3) {
            failure.buttons["OK"].tap()
            XCTAssertTrue(existing.waitForExistence(timeout: 5), "No sheet could be made or opened")
            existing.tap()
        }
    }

    private func keepScreenshot(_ name: String) {
        // Let a rotation finish first. The screen's screenshot, unlike the app's, isn't cropped to portrait.
        Thread.sleep(forTimeInterval: 1)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
