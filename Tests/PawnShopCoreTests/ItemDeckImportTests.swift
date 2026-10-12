import Foundation
import Testing
import ArtExtractionTestSupport
@testable import PawnShopCore

/// Item decks give items' art for their cards, not pawns.
@Suite struct ItemDeckImportTests {
    let folder = temporaryFolder()
    var libraryFolder: URL { folder.appendingPathComponent("Library") }

    @Test func keepsAPDFDecksItemArtApartFromThePawns() throws {
        let deck = try writeCardDeck(threeItems, named: "PZO2230 Guns Deck.pdf",
                                     in: try product("Pathfinder Guns Deck"))
        let library = try PawnLibrary(folder: libraryFolder)
        let report = try library.importPDF(at: deck)
        #expect(library.pawns.isEmpty && report.added == 0)
        #expect(report.itemArtAdded == 3 && library.itemArt.map(\.name).contains("Healing Potion"))
        #expect(library.itemArt.allSatisfy { if case .figure = $0.picture { true } else { false } })
        #expect(FileManager.default.fileExists(atPath: library.fileURL(forSource: library.sources[0].id).path))
    }

    @Test func writesTheItemsOfADeckSoldAsPicturesAndKeepsNoCopyOfTheFolder() throws {
        let deck = try product("Pathfinder Weapons & Armor Deck")
        try writeImageDeck(["DAGGER", "LONGSWORD", "WHIP"], in: deck)
        #expect(PawnLibrary.isImportable(deck.appendingPathComponent("Deck Backs1.jpg")))
        #expect(PawnLibrary.importableFiles([deck.appendingPathComponent("Deck Backs1.jpg")])
                .map { $0.resolvingSymlinksInPath().path } == [deck.resolvingSymlinksInPath().path])
        let library = try PawnLibrary(folder: libraryFolder)
        let report = try library.importPDF(at: deck)
        #expect(report.itemArtAdded == 3 && library.pawns.isEmpty)
        #expect(library.hasImported(deck.appendingPathComponent("Deck Fronts2.jpg")))
        for artwork in library.itemArt {
            guard case .drawn(let file) = artwork.picture else { Issue.record("expected a drawn item"); continue }
            #expect(FileManager.default.fileExists(atPath: library.folders.items.appendingPathComponent(file).path))
        }
        #expect(!FileManager.default.fileExists(atPath: library.fileURL(forSource: library.sources[0].id).path))
    }

    @Test func importingADeckAgainAddsNoArt() throws {
        let deck = try writeCardDeck(threeItems, named: "Guns Deck.pdf", in: try product("Pathfinder Guns Deck"))
        let library = try PawnLibrary(folder: libraryFolder)
        try library.importPDF(at: deck)
        let again = try library.importPDF(at: deck)
        #expect(again.wasImported && library.itemArt.count == 3)
        let reopened = try PawnLibrary(folder: libraryFolder)
        #expect(reopened.itemArt == library.itemArt)
    }

    private func product(_ name: String) throws -> URL {
        let url = folder.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
