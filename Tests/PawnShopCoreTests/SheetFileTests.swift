import ArtExtraction
import Foundation
import SheetPreviewFile
import TablesideShared
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
        #expect(json?["formatVersion"] as? Int == SheetFile.savedFormatVersion)
        // Format 1, so apps from before sheets could leave their settings out still open it.
        #expect(SheetFile.savedFormatVersion == 1 && json?["settings"] != nil)
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

    // MARK: Sheets another app made (format 2)

    @Test func aSheetWithoutSettingsGetsANewSheets() throws {
        let data = try file(format: 2) { $0["settings"] = nil }
        let file = try SheetFile(data: data)
        #expect(!file.hasSettings)
        #expect(file.sheet == PawnSheet(entries: sheet.entries, settings: SheetSettings()))
    }

    @Test func aSheetWithSettingsKeepsThem() throws {
        var changed = sheet
        changed.settings.showsFoldLine.toggle()
        let file = try SheetFile(data: SheetFile(sheet: changed).data())
        #expect(file.hasSettings && file.sheet == changed)
    }

    @Test func opensTheSheetFileTurnkeeperShares() throws {
        let goblin = UUID()
        let request = PawnSheetRequest(title: "Docks", lines: [
            .init(name: "Goblin Warrior", count: 3, pawnID: goblin), .init(name: "Ogre", count: 0),
            .init(name: "Spike Trap", count: 2)
        ])
        let file = try SheetFile(data: request.sheetFile(readerVersion: PawnExtractor.version))
        #expect(!file.hasSettings && file.sheet.settings == SheetSettings() && !file.isFromNewerReader)
        #expect(file.sheet.entries.map(\.count) == [3, 2])
        #expect(file.sheet.entries.first?.pawnID == goblin)
        #expect(file.sheet.entries.first?.label == ArtReference(id: goblin, name: "Goblin Warrior", product: ""))
        // A line without a pawn is a placeholder under an ID of its own, which says the creature's name.
        let trap = try #require(file.sheet.entries.last)
        #expect(trap.pawnID != nil && trap.label?.id == trap.pawnID && trap.missingDescription == "Spike Trap")
    }

    @Test func theKitWritesAFormatThisAppOpens() {
        #expect(PawnSheetRequest.sheetFileFormatVersion <= SheetFile.currentFormatVersion)
    }

    // MARK: The reader's version

    @Test func aSavedSheetSaysWhichReaderMadeItsLibrary() throws {
        let json = try JSONSerialization.jsonObject(with: SheetFile(sheet: sheet).data()) as? [String: Any]
        #expect(json?["readerVersion"] as? Int == PawnExtractor.version)
        #expect(try SheetFile(data: SheetFile(sheet: sheet).data()).readerVersion == PawnExtractor.version)
    }

    @Test func tellsASheetFromANewerReader() throws {
        let newer = try SheetFile(data: file(format: 1) { $0["readerVersion"] = PawnExtractor.version + 1 })
        let same = try SheetFile(data: file(format: 1) { $0["readerVersion"] = PawnExtractor.version })
        let older = try SheetFile(data: file(format: 1) { $0["readerVersion"] = PawnExtractor.version - 1 })
        let silent = try SheetFile(data: JSONEncoder().encode(sheet))
        #expect(newer.isFromNewerReader)
        #expect(!same.isFromNewerReader && !older.isFromNewerReader)
        #expect(silent.readerVersion == nil && !silent.isFromNewerReader)
        #expect(SheetFile.newerReaderNotice.contains("Update Pawn Shop"))
    }
}
