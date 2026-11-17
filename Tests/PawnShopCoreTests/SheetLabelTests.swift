import ArtExtraction
import ArtExtractionTestSupport
import CoreGraphics
import Foundation
import PDFKit
import Testing
@testable import PawnShopCore

@Suite struct SheetLabelTests {
    let folder = temporaryFolder().appendingPathComponent("Library")
    let box = pawnSource("box", title: "Pathfinder Pawns: Monster Box")

    func upgradedLibrary(with pawns: [Pawn]) throws -> PawnLibrary {
        try saveVersion1Library(sources: [box], pawns: pawns, in: folder)
        return try PawnLibrary(folder: folder)
    }

    @Test func pointsASheetSavedBeforeAtTheKeyedPawnsAndLabelsThem() throws {
        let goblin = printedPawn("Goblin Warrior", digest: "aa", source: box.id)
        let custom = Pawn(name: "Hero", size: .medium, art: .custom(CustomArt(imageFile: "hero.png")))
        let library = try upgradedLibrary(with: [goblin, custom])
        let saved = """
            {"entries":[{"id":"\(UUID())","pawnID":"\(goblin.id)","count":2},
                        {"id":"\(UUID())","pawnID":"\(custom.id)","count":1},
                        {"id":"\(UUID())","itemID":"potion","count":1}],
             "settings":{"cutStyle":{"sharedLines":{}},"showsFoldLine":true,
                         "paper":{"paperSize":[612,792],"imageableRect":[[18,18],[576,756]]}}}
            """
        let sheet = try JSONDecoder().decode(PawnSheet.self, from: Data(saved.utf8))
        let labeled = library.labeled(sheet)
        let keyedID = try #require(library.pawn(id: goblin.id)).id
        #expect(labeled.entries.map(\.content) == [.pawn(keyedID), .pawn(custom.id), .item("potion")])
        #expect(labeled.entries.map(\.label) == [ArtReference(id: keyedID, name: "Goblin Warrior", product: box.title),
                                                 ArtReference(id: custom.id, name: "Hero", product: ""), nil])
        #expect(library.labeled(labeled) == labeled)
    }

    @Test func savesAndReadsLabels() throws {
        var entry = SheetEntry(pawnID: UUID(), count: 1)
        entry.label = ArtReference(id: entry.pawnID!, name: "Ogre", product: box.title)
        let sheet = PawnSheet(entries: [entry, SheetEntry(content: .item("potion"), count: 1)])
        let decoded = try JSONDecoder().decode(PawnSheet.self, from: JSONEncoder().encode(sheet))
        #expect(decoded == sheet)
    }

    @Test func leavesAPawnItDoesNotHaveAsItWas() throws {
        let library = try upgradedLibrary(with: [])
        var entry = SheetEntry(pawnID: UUID(), count: 1)
        entry.label = ArtReference(id: entry.pawnID!, name: "Ogre", product: box.title)
        let sheet = PawnSheet(entries: [entry])
        #expect(library.labeled(sheet) == sheet)
    }

    @Test func namesWhatIsMissingOnThePage() throws {
        let library = try upgradedLibrary(with: [])
        var labeled = SheetEntry(pawnID: UUID(), count: 1)
        labeled.label = ArtReference(id: labeled.pawnID!, name: "Ogre", product: "Monster Box")
        let unlabeled = SheetEntry(pawnID: UUID(), count: 1)
        let exporter = SheetExporter(sheet: PawnSheet(entries: [labeled, unlabeled]), library: library,
                                     renderer: PawnRenderer(library: library))
        let page = try #require(exporter.layout().pages.first)
        let labels = exporter.contents(of: page).map { content -> String in
            guard case .pawn(.missing(let label)) = content else { return "" }
            return label
        }
        #expect(labels == ["Ogre, from Monster Box", "Missing pawn"])
        let text = try #require(PDFDocument(data: exporter.pdfData())?.string)
        #expect(text.contains("Ogre, from Monster Box"))
    }
}
