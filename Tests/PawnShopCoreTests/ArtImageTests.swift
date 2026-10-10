import CoreGraphics
import Foundation
import Testing
import ArtExtractionTestSupport
@testable import PawnShopCore

@Suite struct ArtImageTests {
    let library: PawnLibrary
    let renderer: PawnRenderer

    init() throws {
        library = try PawnLibrary(folder: temporaryFolder())
        renderer = PawnRenderer(library: library)
    }

    /// How many pixels in rows `rows` (counted from the bottom) are near black.
    func darkPixels(in image: CGImage, rows: Range<Int>) -> Int {
        let canvas = Canvas(size: CGSize(width: image.width, height: image.height))
        canvas.context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let pixels = canvas.context.data!.bindMemory(to: UInt8.self, capacity: image.width * image.height * 4)
        var count = 0
        for row in rows {
            for column in 0..<image.width {
                let offset = ((image.height - 1 - row) * image.width + column) * 4
                if pixels[offset] < 90 && pixels[offset + 1] < 90 && pixels[offset + 2] < 90 { count += 1 }
            }
        }
        return count
    }

    @Test func paintsOutThePrintedNameButKeepsTheArt() throws {
        let folder = temporaryFolder()
        let goblin = DrawnPawn(rect: CGRect(x: 20, y: 600, width: 81, height: 138), art: artImage(), name: "GOBLIN")
        try library.importPDF(at: writePawnPDF([goblin], named: "Goblins.pdf", in: folder))
        let pawn = try #require(library.pawns.first)
        let printed = try #require(renderer.thumbnail(of: pawn, height: 138))
        let art = try #require(renderer.artImage(of: pawn, height: 138))
        // The name is printed 4 to 18 points above the foot; the art starts at 20.
        #expect(darkPixels(in: printed, rows: 4..<18) > 0)
        #expect(darkPixels(in: art, rows: 0..<19) == 0)
        #expect(darkPixels(in: art, rows: 20..<118) == darkPixels(in: printed, rows: 20..<118))
    }

    @Test func leavesTheNameOffCustomPawns() throws {
        writePNG(headRedImage(), to: library.customFolder.appendingPathComponent("hero.png"))
        let hero = Pawn(name: "Hero", size: .medium, art: .custom(CustomArt(imageFile: "hero.png", showsName: true)))
        let printed = try #require(renderer.thumbnail(of: hero, height: 138))
        let art = try #require(renderer.artImage(of: hero, height: 138))
        #expect(darkPixels(in: printed, rows: 0..<18) > 0)
        #expect(darkPixels(in: art, rows: 0..<18) == 0)
    }
}
