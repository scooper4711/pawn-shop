import UIKit
import XCTest

/// Renames a pawn from its menu in the library, in a library made for the test with one custom pawn.
final class RenameUITests: XCTestCase {
    private var app: XCUIApplication!
    private var libraryFolder: URL!

    override func setUpWithError() throws {
        continueAfterFailure = false
        libraryFolder = FileManager.default.temporaryDirectory
            .appendingPathComponent("RenameUITests-\(UUID().uuidString)", isDirectory: true)
        try TestLibrary.write(pawnNamed: "Test Goblin", to: libraryFolder)
        app = XCUIApplication()
        app.launchEnvironment["PAWN_SHOP_LIBRARY"] = libraryFolder.path
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: libraryFolder)
    }

    func testRenamingAPawnFromItsMenu() {
        app.launch()
        app.openSheet()
        let tile = app.staticTexts["Test Goblin"].firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 15), app.debugDescription)
        tile.press(forDuration: 1.2)
        let rename = app.buttons["Rename…"]
        XCTAssertTrue(rename.waitForExistence(timeout: 5), "The pawn's menu has no Rename…")
        rename.tap()

        let field = app.textFields["Name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), app.debugDescription)
        field.tap()
        let current = field.value as? String ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count) + "Goblin Archer")
        let confirm = app.buttons["Rename"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "The rename sheet has no Rename button")
        XCTAssertTrue(confirm.isHittable, "The rename sheet's Rename button isn't on screen")
        confirm.tap()

        XCTAssertTrue(app.staticTexts["Goblin Archer"].firstMatch.waitForExistence(timeout: 5),
                      "The pawn kept its old name")
        XCTAssertFalse(app.staticTexts["Test Goblin"].exists)
    }
}

extension XCUIApplication {
    /// The document browser comes first: a sheet an earlier test made opens, or else a new one. In the simulator a
    /// new document sometimes fails with "Unable to Import Document"; the test then opens one that was made.
    func openSheet() {
        let create = buttons["Create Document"]
        if create.waitForExistence(timeout: 10) {
            let existing = cells.matching(NSPredicate(format: "identifier CONTAINS '.pawnsheet'")).firstMatch
            if existing.waitForExistence(timeout: 3) {
                existing.tap()
            } else {
                create.tap()
                let failure = alerts["Unable to Import Document"]
                if failure.waitForExistence(timeout: 3) {
                    failure.buttons["OK"].tap()
                    existing.tap()
                }
            }
        }
        let pawns = buttons["Pawns"].firstMatch
        XCTAssertTrue(pawns.waitForExistence(timeout: 15), debugDescription)
        // A sheet made by an earlier test may open on its items.
        pawns.tap()
    }
}

/// A pawn library on disk, written as Pawn Shop saves one: its index and the custom pawn's art.
private enum TestLibrary {
    static func write(pawnNamed name: String, to folder: URL) throws {
        let custom = folder.appendingPathComponent("Custom", isDirectory: true)
        try FileManager.default.createDirectory(at: custom, withIntermediateDirectories: true)
        try art().write(to: custom.appendingPathComponent("art.png"))
        let index: [String: Any] = ["version": 1, "sources": [], "itemArt": [], "pawns": [pawn(named: name)]]
        try JSONSerialization.data(withJSONObject: index)
            .write(to: folder.appendingPathComponent("library.json"))
    }

    private static func pawn(named name: String) -> [String: Any] {
        let art: [String: Any] = ["imageFile": "art.png", "focus": [0.5, 0.5], "showsName": true, "scaling": "fill"]
        return ["id": UUID().uuidString, "name": name, "size": "medium", "appearances": [], "needsName": false,
                "art": ["custom": ["_0": art]], "fingerprint": ["imageDigests": [], "thumbnail": ""]]
    }

    /// A plain green square.
    private static func art() throws -> Data {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 60, height: 60)).image { context in
            UIColor.systemGreen.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 60, height: 60))
        }
        return try XCTUnwrap(image.pngData())
    }
}
