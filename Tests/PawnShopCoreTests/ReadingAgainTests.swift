import ArtExtraction
import ArtExtractionTestSupport
import CoreGraphics
import Foundation
import SQLite3
import Testing
@testable import PawnShopCore

/// Reading PDFs again at launch once the reader is newer (R1.7).
@Suite struct ReadingAgainTests {
    let folder = temporaryFolder()

    func library() throws -> PawnLibrary { try PawnLibrary(folder: folder.appendingPathComponent("Library")) }

    /// The library as the next launch opens it, after an older reader, version `version`, read all its PDFs.
    func libraryReadByAnOlderReader(version: Int = 0) throws -> PawnLibrary {
        var database: OpaquePointer?
        defer { sqlite3_close(database) }
        let file = try library().folders.shared.appendingPathComponent("Library.sqlite").path
        try #require(sqlite3_open(file, &database) == SQLITE_OK)
        let update = "UPDATE sources SET readerVersion = \(version)"
        try #require(sqlite3_exec(database, update, nil, nil, nil) == SQLITE_OK)
        return try library()
    }

    func writePawnBox() throws -> URL {
        let pawn = DrawnPawn(rect: CGRect(x: 20, y: 600, width: 81, height: 138), art: artImage(variant: 0),
                             name: "GOBLIN WARRIOR")
        return try writePawnPDF([pawn], named: "Pathfinder Test Pawn Box.pdf", in: folder)
    }

    func readAgain(_ library: PawnLibrary) throws {
        for file in library.filesToReadAgain { try library.commitReadAgain(PawnLibrary.prepareImport(of: file)) }
    }

    @Test func readsAgainFromItsOriginalAPDFAnOlderReaderRead() throws {
        let box = try writePawnBox()
        try library().importPDF(at: box)
        #expect(try !library().hasFilesToReadAgain)

        let library = try libraryReadByAnOlderReader()
        #expect(library.hasFilesToReadAgain && library.filesToReadAgain == [box])
        try readAgain(library)
        #expect(library.sources.map(\.readerVersion) == [PawnExtractor.version])
        #expect(library.pawns.map(\.name) == ["Goblin Warrior"] && !library.hasFilesToReadAgain)
    }

    /// Image decks have a reader version of their own (pawn-shop#61): a deck the PDF reader read is read again.
    @Test func readsAgainAnImageDeckReadByThePDFReader() throws {
        let deck = folder.appendingPathComponent("Pathfinder Weapons & Armor Deck")
        try writeImageDeck(["DAGGER", "LONGSWORD", "WHIP"], in: deck)
        try library().importPDF(at: deck)
        #expect(try library().sources.map(\.readerVersion) == [PawnExtractor.imageDeckVersion])
        #expect(try !library().hasFilesToReadAgain)

        let library = try libraryReadByAnOlderReader(version: PawnExtractor.version)
        #expect(!library.hasImported(deck))
        #expect(library.filesToReadAgain.map { $0.resolvingSymlinksInPath().path }
                == [deck.resolvingSymlinksInPath().path])
        try readAgain(library)
        #expect(library.sources.map(\.readerVersion) == [PawnExtractor.imageDeckVersion])
        #expect(library.itemArt.count == 3 && library.hasImported(deck) && !library.hasFilesToReadAgain)
    }

    @Test func readsADeckInTwoPDFsAgainWithItsStatBlocks() throws {
        let deck = try writeSplitDeck(threeCards, in: folder)
        try library().importPDF(at: deck.fronts)

        let library = try libraryReadByAnOlderReader()
        #expect(library.filesToReadAgain == [deck.backs])
        try readAgain(library)
        #expect(library.pawns.map(\.name).sorted() == ["Aeon, Arbiter", "Dragon, Young Red", "Ghoul"])
    }

    @Test func leavesADeckAsItWasWhenReadingItAgainFindsNothing() throws {
        let deck = try writeSplitDeck(threeCards, in: folder)
        try library().importPDF(at: deck.fronts)
        try FileManager.default.removeItem(at: deck.fronts)

        let library = try libraryReadByAnOlderReader()
        #expect(throws: PawnLibraryError.nothingFoundAgain(deck.backs.lastPathComponent)) { try readAgain(library) }
        #expect(library.pawns.count == 3)
    }

    @Test func waitsForAnOriginalItCannotReach() throws {
        let box = try writePawnBox()
        try library().importPDF(at: box)
        try FileManager.default.removeItem(at: box)

        let library = try libraryReadByAnOlderReader()
        #expect(library.hasFilesToReadAgain && library.filesToReadAgain.isEmpty)
        #expect(library.pawns.count == 1)
    }

    @Test func leavesARemovedPDFRemoved() throws {
        let library = try library()
        try library.importPDF(at: writePawnBox())
        try library.shared.remove(sourceID: try #require(library.sources.first?.id))
        #expect(try !libraryReadByAnOlderReader().hasFilesToReadAgain)
    }
}
