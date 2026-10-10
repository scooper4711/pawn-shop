import CoreGraphics
import Foundation
import Testing
import ArtExtractionTestSupport
@testable import PawnShopCore

@Suite struct NameDirectionTests {
    @Test(arguments: [(5.0, 0.0, 0), (0, 5, 1), (-5, 1, 2), (1, -5, 3), (0, 0, 0)])
    func turnsWordsToReadLevel(dx: Double, dy: Double, turns: Int) {
        #expect(NameDirection.clockwiseQuarterTurns(toLevel: CGVector(dx: dx, dy: dy)) == turns)
    }

    @Test func movesVectorsWithoutTheTranslation() {
        let turned = CGVector(dx: 1, dy: 0)
            .applying(CGAffineTransform(rotationAngle: .pi / 2).translatedBy(x: 50, y: 50))
        #expect(abs(turned.dx) < 1e-9 && abs(turned.dy - 1) < 1e-9)
    }

    /// Where the red half of `headRedImage()` lands once turned: "top", "right", "bottom" or "left".
    func redSide(after turns: Int) throws -> String {
        let image = try #require(headRedImage().rotated(clockwiseQuarterTurns: turns))
        let canvas = Canvas(size: CGSize(width: image.width, height: image.height))
        canvas.context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let (width, height) = (image.width, image.height)
        let sides = ["top": (width / 2, height - 5), "right": (width - 5, height / 2),
                     "bottom": (width / 2, 5), "left": (5, height / 2)]
        // The red side is the one red at its edge where the opposite edge is blue.
        let opposite = ["top": "bottom", "right": "left", "bottom": "top", "left": "right"]
        return sides.keys.sorted().first { side in
            let (column, row) = sides[side]!, (oppositeColumn, oppositeRow) = sides[opposite[side]!]!
            return canvas.color(atX: column, y: row) == "red"
                && canvas.color(atX: oppositeColumn, y: oppositeRow) == "blue"
        } ?? "nowhere"
    }

    @Test func turnsImagesClockwise() throws {
        #expect(try redSide(after: 0) == "top")
        #expect(try redSide(after: 1) == "right")
        #expect(try redSide(after: 2) == "bottom")
        #expect(try redSide(after: 3) == "left")
        #expect(try redSide(after: -1) == "left")
        let image = headRedImage()
        #expect(image.rotated(clockwiseQuarterTurns: 4) === image)
        #expect(image.rotated(clockwiseQuarterTurns: 1).map { ($0.width, $0.height) } ?? (0, 0) == (80, 40))
    }
}

@Suite struct LevelArtTests {
    let library: PawnLibrary
    let renderer: PawnRenderer

    init() throws {
        library = try PawnLibrary(folder: temporaryFolder())
        renderer = PawnRenderer(library: library)
        // A starship printed on its side: a large pawn lying with its head to the right, its name read level.
        let starship = DrawnPawn(rect: CGRect(x: 20, y: 300, width: 180, height: 138), head: .right,
                                 art: headRedImage(), name: "HOARDMASTER")
        let goblin = DrawnPawn(rect: CGRect(x: 20, y: 600, width: 81, height: 138), art: headRedImage(),
                               name: "GOBLIN")
        try library.importPDF(at: writePawnPDF([starship, goblin], named: "Ships.pdf", in: temporaryFolder()))
    }

    func pawn(_ name: String) throws -> Pawn { try #require(library.pawns.first { $0.name == name }) }

    @Test func turnsArtPrintedOnItsSideToReadLevel() throws {
        let starship = try pawn("Hoardmaster")
        #expect(renderer.levelingTurns(of: starship) != 0)
        let art = try #require(renderer.artImage(of: starship, height: 138))
        #expect(art.width == 138 && art.height < art.width)
        let canvas = Canvas(size: CGSize(width: art.width, height: art.height))
        canvas.context.draw(art, in: CGRect(x: 0, y: 0, width: art.width, height: art.height))
        // As printed: the art's red half above its blue half.
        #expect(canvas.color(atX: art.width / 2, y: art.height * 70 / 100) == "red")
        #expect(canvas.color(atX: art.width / 2, y: art.height * 30 / 100) == "blue")
    }

    @Test func leavesUprightArtAlone() throws {
        let goblin = try pawn("Goblin")
        #expect(renderer.levelingTurns(of: goblin) == 0)
        let art = try #require(renderer.artImage(of: goblin, height: 138))
        #expect(art.height == 138 && art.width < art.height)
        let custom = Pawn(name: "Hero", size: .medium, art: .custom(CustomArt(imageFile: "missing.png")))
        #expect(renderer.levelingTurns(of: custom) == 0)
    }
}
