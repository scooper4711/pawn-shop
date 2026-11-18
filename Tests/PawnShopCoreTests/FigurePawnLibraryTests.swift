import ArtExtraction
import ArtExtractionTestSupport
import CoreGraphics
import Foundation
import Testing
@testable import PawnShopCore

/// Pawns printed without cut outlines.
@Suite struct FigurePawnLibraryTests {
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

    @Test func importsPawnsWithoutOutlinesAsTheirPicturesUpright() throws {
        let library = try library()
        try library.importPDF(at: writeMixedPDF())
        let figure = try #require(library.pawns.first { $0.name == "Ogre" })
        guard case .card(let art) = figure.art else { Issue.record("expected the picture alone"); return }
        #expect(art.face.rotation == 90)
        let picture = try #require(PawnRenderer(library: library).pictureAlone(of: figure, height: 200))
        #expect(picture.height > picture.width)
    }

    /// A page's pictures are read from their PDF, which once closed too early and crashed the app.
    @Test func readsAPageAgainAfterMorePDFsThanAreKeptOpen() throws {
        let folders = LibraryFolders(root: temporaryFolder(), shared: temporaryFolder())
        try FileManager.default.createDirectory(at: folders.sources, withIntermediateDirectories: true)
        let rects = [CGRect(x: 20, y: 600, width: 100, height: 146), CGRect(x: 130, y: 600, width: 100, height: 146)]
        let sources = (0...FigureReader.keptDocuments).map { "source\($0)" }
        for source in sources {
            let pawns = rects.map { DrawnFigurePawn(rect: $0, name: source.uppercased()) }
            try figurePawnPDF(pages: [pawns]).write(to: folders.sourceFile(id: source))
        }
        let reader = FigureReader(folders: folders)
        func art(_ source: String, picture: Int) -> CardArt {
            CardArt(sourceID: source, face: PawnFace(pageIndex: 0, rect: rects[picture], rotation: 0),
                    imageIndex: picture)
        }
        for source in sources { #expect(reader.figure(of: art(source, picture: 0)) != nil) }
        #expect(reader.figure(of: art(sources[0], picture: 1)) != nil)
    }
}
