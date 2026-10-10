import ArtExtraction
import ArtExtractionTestSupport
import CoreGraphics
import Foundation
import Testing
@testable import PawnShopCore

/// PDFs read again when the reader improves.
@Suite struct RereadingTests {
    let folder = temporaryFolder()
    let goblin = DrawnPawn(rect: CGRect(x: 20, y: 600, width: 81, height: 138), art: artImage(variant: 0),
                           name: "GOBLIN WARRIOR")
    let ogre = DrawnFigurePawn(rect: CGRect(x: 200, y: 300, width: 190, height: 148), head: .right,
                               art: creatureArt(variant: 1), name: "OGRE")

    func library() throws -> PawnLibrary { try PawnLibrary(folder: folder.appendingPathComponent("Library")) }

    /// A PDF with an outlined pawn and its back, then a page of pawns printed without outlines.
    func writeMixedPDF() throws -> URL {
        let url = folder.appendingPathComponent("Pathfinder Test Pawn Box PDF.pdf")
        try makePDF(pages: [
            { context in goblin.draw(context) },
            { context in goblin.mirrored(pageWidth: letterPage.width).draw(context) },
            { context in ogre.draw(context) }
        ]).write(to: url)
        return url
    }

    @Test func readsAPDFAgainWithANewerReaderKeepingItsPawns() throws {
        let file = try writeMixedPDF()
        var library = try library()
        try library.importPDF(at: file)
        // As an older reader left it: the outlined pawn renamed by the user, the outline-less one not found.
        let goblinID = try #require(library.pawns.first { $0.name == "Goblin Warrior" }?.id)
        try library.rename(goblinID, to: "Goblin Boss")
        try library.remove(Set(library.pawns.filter { $0.name == "Ogre" }.map(\.id)))
        library.sources[0].readerVersion = PawnExtractor.version - 1
        try library.save()
        library = try self.library()
        #expect(!library.hasImported(file))

        let report = try library.importPDF(at: file)
        #expect(report.reread)
        #expect(report.added == 1)
        #expect(library.pawns.map(\.name).sorted() == ["Goblin Boss", "Ogre"])
        #expect(library.pawns.allSatisfy { $0.appearances.count == 1 })
        #expect(library.sources.map(\.readerVersion) == [PawnExtractor.version])
        #expect(library.hasImported(file))
    }
}
