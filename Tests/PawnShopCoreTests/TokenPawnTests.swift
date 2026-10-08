import CoreGraphics
import Foundation
import Testing
@testable import PawnShopCore

/// A picture whose left half is red and right half blue, to tell a face from its mirror image.
func leftRedImage(side: Int = 60) -> CGImage {
    let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    context.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: side / 2, height: side))
    context.setFillColor(red: 0, green: 0, blue: 1, alpha: 1)
    context.fill(CGRect(x: side / 2, y: 0, width: side / 2, height: side))
    return context.makeImage()!
}

@Suite struct TokenLibraryTests {
    let folder = temporaryFolder()

    func importTokens() throws -> PawnLibrary {
        let url = folder.appendingPathComponent("PZO1 Starfinder Test Tokens PDF.pdf")
        let tokens = [DrawnToken(center: CGPoint(x: 100, y: 600), rimName: "NITPICK"),
                      DrawnToken(center: CGPoint(x: 300, y: 400), diameter: 162, art: tokenArt(variant: 1),
                                 rimName: "OGRE")]
        try tokenPDF(pages: [tokens, tokens.map { $0.mirrored(pageWidth: letterPage.width) }]).write(to: url)
        let library = try PawnLibrary(folder: folder.appendingPathComponent("Library"))
        #expect(try library.importPDF(at: url).added == 2)
        return library
    }

    @Test func keepsATokensPicturesInTheTokenFolder() throws {
        let library = try importTokens()
        let ogre = try #require(library.pawns.first { $0.name == "Ogre" })
        guard case .token(let art) = ogre.art else { Issue.record("not a token"); return }
        #expect(ogre.size == .large && art.backPicture != nil && art.pictures.count == 2)
        #expect(art.pictures.allSatisfy {
            FileManager.default.fileExists(atPath: library.folders.tokens.appendingPathComponent($0).path)
        })
        #expect(library.sourceTitle(of: ogre) == "Starfinder Test Tokens")
        #expect(library.sourceTitles(of: ogre) == ["Starfinder Test Tokens"] && !ogre.isCustom)
    }

    @Test func removesATokensPicturesWithIt() throws {
        let library = try importTokens()
        let ogre = try #require(library.pawns.first { $0.name == "Ogre" })
        guard case .token(let art) = ogre.art else { Issue.record("not a token"); return }
        try library.remove([ogre.id])
        #expect(art.pictures.allSatisfy {
            !FileManager.default.fileExists(atPath: library.folders.tokens.appendingPathComponent($0).path)
        })
        let reopened = try PawnLibrary(folder: library.folder)
        #expect(reopened.pawns.map(\.name) == ["Nitpick"])
    }

    @Test func reportsATokenPictureThatCannotBeWritten() throws {
        let library = try PawnLibrary(folder: folder.appendingPathComponent("Library"))
        try FileManager.default.removeItem(at: library.folders.tokens)
        let url = folder.appendingPathComponent("Tokens.pdf")
        try tokenPDF(pages: [[DrawnToken(center: CGPoint(x: 100, y: 600), rimName: "NITPICK")]]).write(to: url)
        #expect(throws: PawnLibraryError.self) { try library.importPDF(at: url) }
    }

    @Test func namesTheSourceOfEachKindOfArt() {
        let face = PawnFace(pageIndex: 0, rect: .zero, rotation: 0)
        #expect(PawnArt.pdf(sourceID: "a", front: face, back: face).sourceID == "a")
        #expect(PawnArt.token(TokenArt(sourceID: "b", frontPicture: "f.png")).sourceID == "b")
        #expect(PawnArt.custom(CustomArt(imageFile: "c.png")).sourceID == nil)
    }
}

@Suite struct TokenRendererTests {
    let library: PawnLibrary
    let renderer: PawnRenderer

    init() throws {
        library = try PawnLibrary(folder: temporaryFolder())
        writePNG(leftRedImage(), to: library.folders.tokens.appendingPathComponent("front.png"))
        writePNG(headRedImage(), to: library.folders.tokens.appendingPathComponent("back.png"))
        renderer = PawnRenderer(library: library)
    }

    func token(back: String? = nil, front: String = "front.png") -> Pawn {
        Pawn(name: "Nitpick", size: .medium,
             art: .token(TokenArt(sourceID: "s", frontPicture: front, backPicture: back)))
    }

    /// Draws one face of a medium pawn, 81 × 138.
    func face(_ pawn: Pawn, side: PawnSide) -> Canvas {
        let canvas = Canvas(size: CGSize(width: 81, height: 138))
        renderer.drawFace(of: pawn, side: side, in: CGRect(x: 0, y: 0, width: 81, height: 138),
                          context: canvas.context)
        return canvas
    }

    @Test func drawsTheTokenAboveItsNameOnWhite() {
        let canvas = face(token(), side: .front)
        let circle = PawnRenderer.tokenCircle(in: PawnRenderer.areaAboveName("Nitpick", in: CGRect(
            x: 0, y: 0, width: 81, height: 138)))
        #expect(renderer.uprightSize(of: token()) == PawnSize.medium.outlineSize)
        #expect(canvas.color(atX: 20, y: Int(circle.midY)) == "red")
        #expect(canvas.color(atX: 60, y: Int(circle.midY)) == "blue")
        // Outside the circle, and in the name band, the face is white.
        #expect(canvas.color(atX: 2, y: Int(circle.maxY) - 2) == "other")
        #expect(canvas.color(atX: 40, y: 2) == "other")
    }

    @Test func mirrorsTheFrontWhenTheTokenHasNoBack() {
        let canvas = face(token(), side: .back)
        let middle = Int(PawnRenderer.tokenCircle(in: PawnRenderer.areaAboveName("Nitpick", in: CGRect(
            x: 0, y: 0, width: 81, height: 138))).midY)
        #expect(canvas.color(atX: 20, y: middle) == "blue" && canvas.color(atX: 60, y: middle) == "red")
    }

    @Test func drawsTheBackPictureWhenThereIsOne() {
        let canvas = face(token(back: "back.png"), side: .back)
        let circle = PawnRenderer.tokenCircle(in: PawnRenderer.areaAboveName("Nitpick", in: CGRect(
            x: 0, y: 0, width: 81, height: 138)))
        #expect(canvas.color(atX: 40, y: Int(circle.maxY) - 10) == "red")
        #expect(canvas.color(atX: 40, y: Int(circle.minY) + 10) == "blue")
    }

    @Test func drawsAPlaceholderForAMissingPicture() {
        let canvas = face(token(front: "gone.png"), side: .front)
        #expect(canvas.color(atX: 40, y: 80) == "other")
    }

    @Test func showsTheTaggerOnlyTheTokensArt() throws {
        let image = try #require(renderer.artImage(of: token(), height: 138))
        #expect(image.height == 138 && image.width == 81)
        let middle = pixel(of: image, x: 10, y: 69)
        #expect(middle[0] > 200 && middle[2] < 60)
    }

    @Test func centersTheLargestCircleInAnArea() {
        #expect(PawnRenderer.tokenCircle(in: CGRect(x: 10, y: 20, width: 80, height: 120))
                    == CGRect(x: 10, y: 40, width: 80, height: 80))
        #expect(PawnRenderer.tokenCircle(in: CGRect(x: 0, y: 0, width: 100, height: 50))
                    == CGRect(x: 25, y: 0, width: 50, height: 50))
    }
}
