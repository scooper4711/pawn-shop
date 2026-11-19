import ArtExtraction
import ArtExtractionTestSupport
import CoreGraphics
import Foundation
import SharedLibraries
import Testing
@testable import PawnShopCore

/// Pawns drawn from the picture saved with their art, on a device that can't reach their PDF (R2.1.2, R10.3).
@Suite struct SavedPictureTests {
    let folder = temporaryFolder()
    let library: PawnLibrary
    let goblin: Pawn

    /// A library whose goblin another app read from a PDF Pawn Shop wasn't given.
    init() throws {
        let sharedFolder = folder.appendingPathComponent("Shared")
        let drawn = DrawnPawn(rect: CGRect(x: 20, y: 600, width: 81, height: 138), art: artImage(variant: 0),
                              name: "GOBLIN WARRIOR")
        let pdf = try writePawnPDF([drawn], named: "Pathfinder Test Pawn Box.pdf", in: folder)
        try SharedLibrary(folder: sharedFolder, app: .turnkeeper).add(pdf, keeping: false)
        library = try PawnLibrary(folder: folder.appendingPathComponent("Pawn Shop"),
                                  shared: try SharedLibrary(folder: sharedFolder, app: .pawnShop))
        goblin = try #require(library.pawns.first)
    }

    var picture: URL { library.folders.pictures.appendingPathComponent(goblin.pictureFiles[0]) }

    @Test func drawsAPawnWithoutItsPDFFromItsSavedPicture() throws {
        guard case .picture(let art) = goblin.art else { Issue.record("\(goblin.art)"); return }
        #expect(goblin.name == "Goblin Warrior" && goblin.pictureFiles == [art.picture])
        #expect(goblin.art.sourceID == library.sources.first?.id)
        #expect(library.sourceTitle(of: goblin) == "Pathfinder Test Pawn Box")
        #expect(FileManager.default.fileExists(atPath: picture.path))
        #expect(PawnRenderer(library: library).uprightSize(of: goblin) == PawnSize.medium.outlineSize)
    }

    @Test func standsThePictureOnTheNameAndMirrorsItForTheBack() throws {
        writePNG(leftRedImage(), to: picture)
        let renderer = PawnRenderer(library: library)
        let rect = CGRect(x: 0, y: 0, width: 81, height: 138)
        let area = PawnRenderer.areaAboveName(goblin.name, in: rect)
        let front = Canvas(size: rect.size), back = Canvas(size: rect.size)
        renderer.drawFace(of: goblin, side: .front, in: rect, context: front.context)
        renderer.drawFace(of: goblin, side: .back, in: rect, context: back.context)

        let foot = Int(area.minY) + 4
        #expect(front.color(atX: 10, y: foot) == "red" && front.color(atX: 70, y: foot) == "blue")
        #expect(back.color(atX: 10, y: foot) == "blue" && back.color(atX: 70, y: foot) == "red")
        #expect(front.color(atX: 40, y: Int(rect.maxY) - 4) == "other", "white above a picture wider than tall")
    }

    @Test func showsAPlaceholderUntilThePictureIsHere() throws {
        try FileManager.default.removeItem(at: picture)
        let renderer = PawnRenderer(library: library)
        let missing = try #require(renderer.thumbnail(of: goblin, height: 138))
        writePNG(leftRedImage(), to: picture)
        let drawn = try #require(renderer.thumbnail(of: goblin, height: 138))
        #expect(missing.dataProvider?.data != drawn.dataProvider?.data, "a missing picture isn't remembered")
        #expect(renderer.artImage(of: goblin, height: 60)?.height == 60)

        var unnamed = goblin
        unnamed.art = .picture(PictureArt(sourceID: "", picture: ""))
        #expect(unnamed.pictureFiles.isEmpty && renderer.thumbnail(of: unnamed, height: 60) != nil)
    }

    @Test func namesThePicturesAPawnIsDrawnFrom() throws {
        let hero = try library.addCustomPawn(NewCustomPawn(image: headRedImage(), name: "Hero"))
        let token = Pawn(name: "Nitpick", size: .medium,
                         art: .token(TokenArt(sourceID: "s", frontPicture: "front.png", backPicture: "back.png")))
        #expect(hero.pictureFiles.isEmpty && token.pictureFiles == ["front.png", "back.png"])
    }

    @Test func drawsFromThePDFAgainOncePawnShopImportsIt() throws {
        let pdf = folder.appendingPathComponent("Pathfinder Test Pawn Box.pdf")
        try library.importPDF(at: pdf)
        let imported = try #require(library.pawn(id: goblin.id))
        guard case .pdf = imported.art else { Issue.record("\(imported.art)"); return }
        #expect(imported.pictureFiles.isEmpty)
    }
}
