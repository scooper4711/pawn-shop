import CoreGraphics
import Foundation
import Testing
import ArtExtractionTestSupport
@testable import PawnShopCore

/// Which Battle Cards files the library imports.
@Suite struct CardImportTests {
    let folder = temporaryFolder()

    @Test func importsEachDeckOnceAsItsArtFile() throws {
        let deck = try writeSplitDeck(threeCards, in: folder)
        let pawns = folder.appendingPathComponent("Pawns.pdf")
        #expect(PawnLibrary.importableFiles([deck.fronts, pawns, deck.backs, pawns]) == [deck.backs, pawns])
    }

    @Test func findsDecksInScrollkeepersFolderOnce() throws {
        let product = folder.appendingPathComponent("Pathfinder Bestiary 2 Battle Cards")
        try FileManager.default.createDirectory(at: product, withIntermediateDirectories: true)
        let deck = try writeSplitDeck(threeCards, base: "PZO2219 Bestiary 2 Battle Cards", in: product)
        try Data().write(to: product.appendingPathComponent("Readme.txt"))
        #expect(ScrollkeeperScanner.pawnPDFs(in: folder).map(\.lastPathComponent) == [deck.backs.lastPathComponent])
    }
}
