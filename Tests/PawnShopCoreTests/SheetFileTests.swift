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

    private func file(format: Int, changing change: (inout [String: Any]) -> Void = { _ in }) throws -> Data {
        var json = try #require(JSONSerialization.jsonObject(with: SheetFile(sheet: sheet).data()) as? [String: Any])
        json["formatVersion"] = format
        change(&json)
        return try JSONSerialization.data(withJSONObject: json)
    }

    @Test func aSavedSheetSaysItsFormat() throws {
        let json = try JSONSerialization.jsonObject(with: SheetFile(sheet: sheet).data()) as? [String: Any]
        #expect(json?["formatVersion"] as? Int == SheetFile.currentFormatVersion)
    }

    @Test func aSheetWithoutAFormatIsTheFirst() throws {
        #expect(try SheetFile(data: JSONEncoder().encode(sheet)).sheet == sheet)
    }

    @Test func opensItsOwnFormatAndIgnoresKeysAddedLater() throws {
        let data = try file(format: SheetFile.currentFormatVersion) { $0["paperColor"] = "ivory" }
        #expect(try SheetFile(data: data).sheet == sheet)
    }

    @Test func refusesANewerFormatWhateverItHolds() throws {
        let newer = SheetFile.currentFormatVersion + 1
        let unchanged = try file(format: newer)
        #expect(throws: SheetFileError.newerFormat(newer)) { try SheetFile(data: unchanged) }
        let changed = try file(format: newer + 3) { $0["entries"] = "all different now" }
        #expect(throws: SheetFileError.newerFormat(newer + 3)) { try SheetFile(data: changed) }
    }

    @Test func theRefusalSaysToUpdate() {
        let message = SheetFileError.newerFormat(4).localizedDescription
        #expect(message.contains("newer version of Pawn Shop") && message.contains("sheet format 4"))
    }
}
