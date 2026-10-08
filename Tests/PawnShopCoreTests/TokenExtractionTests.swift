import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import PawnShopCore

/// A round token as a test PDF draws it: art clipped to a circle, a name along its rim or a label.
struct DrawnToken {
    var center: CGPoint
    var diameter: CGFloat = 90
    var art: CGImage? = tokenArt()
    /// Drawn letter by letter along the bottom of the token, twice (an outline and a fill), as path text is.
    var rimName: String?
    /// Label lines drawn across the middle: a token number, the name, the copyright line.
    var label: [String] = []

    var clip: CGRect {
        CGRect(x: center.x - diameter / 2, y: center.y - diameter / 2, width: diameter, height: diameter)
    }

    /// The same token where the back page prints it, mirrored for duplex.
    func mirrored(pageWidth: CGFloat) -> DrawnToken {
        var back = self
        back.center.x = pageWidth - center.x
        return back
    }

    func draw(_ context: CGContext) {
        if let art {
            context.saveGState()
            context.addEllipse(in: clip)
            context.clip()
            context.draw(art, in: clip.insetBy(dx: -1, dy: -1))
            context.restoreGState()
        }
        if let rimName {
            for _ in 0..<2 { drawRimName(rimName, context) }
        }
        for (index, line) in label.enumerated() {
            drawText(context, line, at: CGPoint(x: clip.minX + 12, y: center.y + 15 - CGFloat(index) * 10), size: 7)
        }
    }

    private func drawRimName(_ name: String, _ context: CGContext) {
        for (index, letter) in name.enumerated() {
            let angle = CGFloat.pi * (1.25 + 0.5 * CGFloat(index) / CGFloat(max(name.count - 1, 1)))
            let radius = diameter / 2 - 10
            let origin = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
            drawText(context, String(letter), at: origin, size: 5)
        }
    }
}

/// A picture with an opaque disc in its lower half and nothing (transparent) above, so a PDF embeds it with a
/// soft mask.
func tokenArt(variant: Int = 0) -> CGImage {
    let context = CGContext(data: nil, width: 60, height: 60, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.setFillColor(CGColor(srgbRed: variant == 0 ? 0.9 : 0.1, green: 0.5, blue: 0.2, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: 60, height: 30))
    context.setFillColor(CGColor(srgbRed: 0.1, green: 0.1, blue: variant == 0 ? 0.8 : 0.3, alpha: 1))
    context.fillEllipse(in: CGRect(x: 10 + variant * 10, y: 5, width: 20, height: 20))
    return context.makeImage()!
}

/// A dark picture covering the page behind the tokens.
func darkBackground() -> CGImage {
    let context = CGContext(data: nil, width: 8, height: 8, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    context.setFillColor(CGColor(srgbRed: 0.15, green: 0.05, blue: 0.25, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
    return context.makeImage()!
}

func tokenPDF(pages: [[DrawnToken]], background: Bool = false) -> Data {
    makePDF(pages: pages.map { tokens in
        { context in
            if background { context.draw(darkBackground(), in: CGRect(origin: .zero, size: letterPage)) }
            for token in tokens { token.draw(context) }
        }
    })
}

func extractTokens(_ pages: [[DrawnToken]], background: Bool = false) throws -> ExtractionResult {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).pdf")
    try tokenPDF(pages: pages, background: background).write(to: url)
    defer { try? FileManager.default.removeItem(at: url) }
    return try PawnExtractor.extract(from: url)
}

/// The pixel at (`column`, `row`) from the top left as RGBA bytes.
func pixel(of image: CGImage, x column: Int, y row: Int) -> [UInt8] {
    let context = CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.draw(image, in: CGRect(x: -column, y: row - image.height + 1, width: image.width, height: image.height))
    return Array(UnsafeBufferPointer(start: context.data!.bindMemory(to: UInt8.self, capacity: 4), count: 4))
}

func image(fromPNG data: Data) -> CGImage? {
    CGImageSourceCreateWithData(data as CFData, nil).flatMap { CGImageSourceCreateImageAtIndex($0, 0, nil) }
}

@Suite struct TokenExtractionTests {
    @Test func namesATokenFromTheNameAlongItsRim() throws {
        let token = DrawnToken(center: CGPoint(x: 100, y: 600), rimName: "SMOG SCAMP 2")
        let result = try extractTokens([[token]])
        let pawn = try #require(result.pawns.first)
        #expect(result.pawns.count == 1 && result.unnamed.isEmpty)
        #expect(pawn.name == "Smog Scamp 2" && pawn.size == .medium)
        guard case .token(let pictures) = pawn.shape else { Issue.record("not a token"); return }
        #expect(pictures.back == nil && pawn.back == pawn.front.mirroredCopy())
        #expect(abs(pawn.front.rect.width - 90) < 1)
    }

    @Test func namesTokensFromTheirLabelsOnTheBackPage() throws {
        let fronts = [DrawnToken(center: CGPoint(x: 100, y: 600)),
                      DrawnToken(center: CGPoint(x: 200, y: 600), art: tokenArt(variant: 1))]
        var backs = fronts.map { $0.mirrored(pageWidth: letterPage.width) }
        backs[0].art = darkBackground()
        backs[0].label = ["3", "AEON GUARD,", "SPECIALIST", "© 2026 PAIZO INC."]
        backs[1].art = darkBackground()
        backs[1].label = ["12", "AKATA", "© 2026 PAIZO INC."]
        let result = try extractTokens([fronts, backs])
        #expect(result.pawns.map(\.name) == ["Aeon Guard, Specialist", "Akata"])
        #expect(result.pawns.allSatisfy { $0.back == $0.front.mirroredCopy() })
    }

    @Test func takesTheBackFromADuplexPageRepeatingTheArt() throws {
        let front = DrawnToken(center: CGPoint(x: 100, y: 600), rimName: "NITPICK")
        let result = try extractTokens([[front], [front.mirrored(pageWidth: letterPage.width)]])
        let pawn = try #require(result.pawns.first)
        #expect(result.pawns.count == 1 && pawn.name == "Nitpick")
        #expect(pawn.back.pageIndex == 1 && !pawn.back.mirrored)
        guard case .token(let pictures) = pawn.shape else { Issue.record("not a token"); return }
        #expect(pictures.back != nil)
    }

    @Test func countsCopiesAndSizesTokensByTheirCut() throws {
        let tokens = [DrawnToken(center: CGPoint(x: 100, y: 600), rimName: "OGRE"),
                      DrawnToken(center: CGPoint(x: 200, y: 600), rimName: "OGRE"),
                      DrawnToken(center: CGPoint(x: 150, y: 400), diameter: 162, rimName: "GIANT"),
                      DrawnToken(center: CGPoint(x: 400, y: 300), diameter: 232, rimName: "DRAGON")]
        let result = try extractTokens([tokens])
        #expect(result.pawns.map(\.copies) == [2, 1, 1])
        #expect(result.pawns.map(\.size) == [.medium, .large, .huge])
    }

    @Test func reportsTokensWithoutANameAndIgnoresBadgesAndCoverArt() throws {
        let tokens = [DrawnToken(center: CGPoint(x: 100, y: 600)),
                      DrawnToken(center: CGPoint(x: 300, y: 700), diameter: 20, rimName: "BADGE"),
                      DrawnToken(center: CGPoint(x: 306, y: 300), diameter: 400, rimName: "COVER")]
        let result = try extractTokens([tokens])
        #expect(result.pawns.count == 1 && result.pawns[0].name.isEmpty)
        #expect(result.unnamed.count == 1)
    }

    @Test func leavesThePageBackgroundAndPrintedNameOutOfThePicture() throws {
        let token = DrawnToken(center: CGPoint(x: 100, y: 600), rimName: "VORZA")
        let pawn = try #require(try extractTokens([[token]], background: true).pawns.first)
        guard case .token(let pictures) = pawn.shape, let picture = image(fromPNG: pictures.front)
        else { Issue.record("no token picture"); return }
        let middle = picture.width / 2
        // Above the art's opaque half the art is transparent: the dark page must not show through.
        #expect(pixel(of: picture, x: middle, y: picture.height / 4)[3] == 0)
        #expect(pixel(of: picture, x: 2, y: 2)[3] == 0)
        #expect(pixel(of: picture, x: middle, y: picture.height * 3 / 4)[3] == 255)
        // The name along the rim is left out too: the letters' row shows only art.
        let rim = pixel(of: picture, x: middle, y: picture.height - picture.height / 9)
        #expect(rim[3] == 0 || rim[0] > 100 || rim[1] > 100)
    }

    @Test func pairsOnlyTokensMirroredWithTheirBacks() throws {
        let page = PageScanner.scan(document(tokenPDF(pages: [[DrawnToken(center: CGPoint(x: 100, y: 600))]]))
                                        .page(at: 1)!)
        let fronts = TokenFinder.tokens(on: page)
        #expect(fronts.count == 1)
        #expect(TokenPairing.backs(for: fronts, among: []) == nil)
        #expect(TokenPairing.backs(for: [], among: fronts) == nil)
        // Other art where the back would be, with no label, is the front of another token.
        let other = PageScanner.scan(document(tokenPDF(pages: [[
            DrawnToken(center: CGPoint(x: letterPage.width - 100, y: 600), art: artImage(variant: 1))
        ]])).page(at: 1)!)
        #expect(TokenPairing.backs(for: fronts, among: TokenFinder.tokens(on: other)) == nil)
    }

    @Test func joinsLettersSetOneByOneIntoALine() {
        let glyphs = ["3", "AEON GUARD,", "S", "P", "Y", " ", "1", "© 2026 PAIZO INC."].map {
            TextGlyph(text: $0, origin: .zero)
        }
        #expect(FoundToken.lines(of: glyphs) == ["3", "AEON GUARD,", "SPY 1", "© 2026 PAIZO INC."])
    }

    @Test func sizesTokensByTheirBase() {
        #expect(PawnSize.token(diameter: 54) == .medium)
        #expect(PawnSize.token(diameter: 72) == .medium)
        #expect(PawnSize.token(diameter: 144) == .large)
        #expect(PawnSize.token(diameter: 214) == .huge)
        #expect(PawnSize.token(diameter: 288) == .gargantuan)
    }
}
