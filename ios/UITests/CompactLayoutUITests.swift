import UIKit
import XCTest

/// A sheet on the iPhone, where the library, the pages and the sheet's pawns are tabs under one toolbar.
final class CompactLayoutUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "The iPad shows columns, not tabs")
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        app.openSheet()
    }

    func testTheToolbarOffersTheLibraryMenuAndPrint() {
        XCTAssertTrue(app.buttons["Print"].firstMatch.isHittable, app.debugDescription)
        app.buttons["Library"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Import PDF…"].waitForExistence(timeout: 5), "No Import PDF… in the Library menu")
    }

    func testAnAddedItemShowsOnThePagesAndInTheSheet() {
        let card = "Ablative Armor Plating (Lesser)"
        app.buttons["Items"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts[card].waitForExistence(timeout: 10), app.debugDescription)
        app.staticTexts[card].doubleTap()

        app.tabBars.buttons["Pages"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Page 1 of'")).firstMatch
            .waitForExistence(timeout: 10), app.debugDescription)
        keepScreenshot("Pages")

        app.tabBars.buttons["Sheet"].tap()
        XCTAssertTrue(app.staticTexts[card].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.buttons["Print"].firstMatch.isEnabled, "Print is off with a card on the sheet")
        keepScreenshot("Sheet")
    }

    private func keepScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
