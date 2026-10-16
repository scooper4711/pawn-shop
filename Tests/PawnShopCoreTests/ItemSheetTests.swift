import CoreGraphics
import Foundation
import PDFKit
import Testing
import ArtExtraction
import ArtExtractionTestSupport
@testable import PawnShopCore

/// Item cards on sheets, beside pawns.
@Suite struct ItemSheetTests {
    @Test func savesPawnsAsBeforeAndItemsBesideThem() throws {
        let pawnID = UUID()
        var sheet = PawnSheet()
        sheet.add(pawnID)
        sheet.add(.item("pathfinder/Potion"), copies: 2)
        sheet.add(.item("pathfinder/Potion"))
        #expect(sheet.entries.map(\.count) == [1, 3] && sheet.entries[1].itemID == "pathfinder/Potion")
        let json = String(bytes: try JSONEncoder().encode(sheet), encoding: .utf8) ?? ""
        #expect(json.contains("\"pawnID\":\"\(pawnID.uuidString)\"") && json.contains("\"itemID\""))
        #expect(try JSONDecoder().decode(PawnSheet.self, from: Data(json.utf8)) == sheet)
        #expect(sheet.entries[0].pawnID == pawnID && sheet.entries[0].itemID == nil && sheet.entries[1].pawnID == nil)
    }

    @Test func readsSheetsSavedBeforeItems() throws {
        let id = UUID(), pawnID = UUID()
        let old = #"{"entries":[{"id":"\#(id)","pawnID":"\#(pawnID)","count":2}],"settings":"#
            + String(bytes: try JSONEncoder().encode(SheetSettings()), encoding: .utf8)! + "}"
        let sheet = try JSONDecoder().decode(PawnSheet.self, from: Data(old.utf8))
        #expect(sheet.entries == [SheetEntry(id: id, pawnID: pawnID, count: 2)])
    }

    @Test func laysOutCardsBesidePawnsAndShowsTheirArt() throws {
        let library = try PawnLibrary(folder: temporaryFolder())
        let potion = catalogItem("Healing Potion (Minor)", level: 1)
        var sheet = PawnSheet()
        sheet.add(.item(potion.id), copies: 3)
        sheet.add(.item("pathfinder/Missing"))
        var exporter = SheetExporter(sheet: sheet, library: library, renderer: PawnRenderer(library: library))
        exporter.catalog = ItemCatalog(items: [potion])
        #expect(exporter.layoutItems().map(\.stripSize) == [ItemCard.size, ItemCard.size])
        let page = try #require(exporter.layout().pages.first)
        #expect(page.count == 4)
        let contents = exporter.contents(of: page)
        let names = contents.map { content in
            if case .card(let card) = content { return card?.item.name ?? "missing" }
            return "pawn"
        }
        #expect(names.sorted() == ["Healing Potion (Minor)", "Healing Potion (Minor)", "Healing Potion (Minor)",
                                   "missing"])
        let pdf = try #require(PDFDocument(data: exporter.pdfData()))
        #expect(pdf.pageCount == 1 && pdf.string?.contains("POTION") == true)
        #expect(pdf.string?.contains("Missing item") == true)
    }

    @Test func drawsAnUnknownEntryAsAMissingPawn() throws {
        let library = try PawnLibrary(folder: temporaryFolder())
        let exporter = SheetExporter(sheet: PawnSheet(), library: library, renderer: PawnRenderer(library: library))
        let placed = PlacedStrip(entryID: UUID(), copy: 0, rect: CGRect(x: 0, y: 0, width: 10, height: 10),
                                 sideways: false)
        guard case .pawn(nil) = exporter.contents(of: [placed]).first else {
            Issue.record("expected a missing pawn")
            return
        }
    }
}

@Suite struct SheetContentBatchTests {
    @Test func addingSeveralContentsMergesWithExistingEntries() {
        let pawnID = UUID()
        var sheet = PawnSheet()
        sheet.add(pawnID)
        sheet.add([.pawn(pawnID), .item("torch")], copies: 2)
        #expect(sheet.entries.map(\.count) == [3, 2])
    }

    @Test func contentSurvivesEncoding() throws {
        let contents: [SheetContent] = [.pawn(UUID()), .item("torch")]
        let decoded = try JSONDecoder().decode([SheetContent].self, from: JSONEncoder().encode(contents))
        #expect(decoded == contents)
    }
}
