import Foundation
import SheetPreviewFile
import Testing
@testable import PawnShopCore

@Suite struct SheetFileTests {
    private let sheet = PawnSheet(entries: [SheetEntry(pawnID: UUID(), count: 2)])

    @Test func keepsTheSheetAndItsPictures() throws {
        let file = SheetFile(sheet: sheet, previews: SheetPreviews(pages: [Data([1, 2, 3])]))
        #expect(try SheetFile(data: file.data()) == file)
    }

    @Test func opensASheetSavedBeforePictures() throws {
        let old = try JSONEncoder().encode(sheet)
        let file = try SheetFile(data: old)
        #expect(file.sheet == sheet && file.previews.pages.isEmpty)
    }

    @Test func olderVersionsCanStillReadTheSheet() throws {
        let data = try SheetFile(sheet: sheet, previews: SheetPreviews(pages: [Data([1])])).data()
        #expect(try JSONDecoder().decode(PawnSheet.self, from: data) == sheet)
    }

    @Test func badPicturesDoNotStopTheSheetOpening() throws {
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(sheet)) as? [String: Any])
        json["previewPages"] = ["not base64!"]
        let file = try SheetFile(data: JSONSerialization.data(withJSONObject: json))
        #expect(file.sheet == sheet && file.previews.pages.isEmpty)
    }
}
