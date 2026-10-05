import CoreGraphics
import Foundation
import Testing
@testable import PawnShopCore

/// A pawn as a test PDF draws it: outline, art and label.
struct DrawnPawn {
    var rect: CGRect
    var head: Edge = .top
    var art: CGImage?
    var name: String?

    /// The same pawn where the back page prints it, mirrored for duplex.
    func mirrored(pageWidth: CGFloat) -> DrawnPawn {
        var back = self
        back.rect.origin.x = pageWidth - rect.maxX
        back.head = [.left: .right, .right: .left][head] ?? head
        return back
    }

    func draw(_ context: CGContext) {
        if let art { context.draw(art, in: rect.insetBy(dx: 4, dy: 20)) }
        strokeOutline(context, rect, head: head)
        if let name {
            drawText(context, name, at: CGPoint(x: rect.minX + 6, y: rect.minY + 10), size: 8)
            drawText(context, "© 2019 PAIZO INC.", at: CGPoint(x: rect.minX + 6, y: rect.minY + 4), size: 4)
        }
    }
}

func pawnPDF(pages: [[DrawnPawn]]) -> Data {
    makePDF(pages: pages.map { pawns in { context in pawns.forEach { $0.draw(context) } } })
}

@Suite struct PawnExtractorTests {
    let goblin = artImage(variant: 0), otherGoblin = artImage(variant: 2), ogre = artImage(variant: 1)

    var fronts: [DrawnPawn] {
        [DrawnPawn(rect: CGRect(x: 20, y: 600, width: 81, height: 138), art: goblin, name: "GOBLIN WARRIOR"),
         DrawnPawn(rect: CGRect(x: 120, y: 600, width: 81, height: 138), art: goblin, name: "GOBLIN WARRIOR"),
         DrawnPawn(rect: CGRect(x: 220, y: 600, width: 81, height: 138), art: otherGoblin, name: "GOBLIN WARRIOR"),
         DrawnPawn(rect: CGRect(x: 20, y: 300, width: 180, height: 138), head: .right, art: ogre, name: "OGRE"),
         DrawnPawn(rect: CGRect(x: 320, y: 600, width: 81, height: 138), art: ogre)]
    }

    func extract(_ pages: [[DrawnPawn]]) throws -> ExtractionResult {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).pdf")
        try pawnPDF(pages: pages).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        return try PawnExtractor.extract(from: url)
    }

    @Test func countsCopiesOfTheSameArtOnly() throws {
        let result = try extract([fronts, fronts.map { $0.mirrored(pageWidth: letterPage.width) }])
        let goblins = result.pawns.filter { $0.name == "Goblin Warrior" }
        #expect(goblins.map(\.copies).sorted() == [1, 2])
        #expect(result.pawns.count == 3)
    }

    @Test func takesBacksFromTheMirroredPage() throws {
        let result = try extract([fronts, fronts.map { $0.mirrored(pageWidth: letterPage.width) }])
        let ogre = try #require(result.pawns.first { $0.name == "Ogre" })
        #expect(ogre.size == .large)
        #expect(ogre.front.rotation == 90)
        #expect(ogre.back.pageIndex == 1 && ogre.back.rotation == 270 && !ogre.back.mirrored)
        #expect(abs(ogre.back.rect.minX - (letterPage.width - 200)) < 0.5)
    }

    @Test func mirrorsTheFrontWhenThereIsNoBackPage() throws {
        let result = try extract([fronts])
        #expect(result.pawns.allSatisfy { $0.back == $0.front.mirroredCopy() })
    }

    @Test func reportsOutlinesWithoutALabel() throws {
        let result = try extract([fronts])
        #expect(result.unnamed.count == 1)
        #expect(abs((result.unnamed.first?.rect.minX ?? 0) - 320) < 0.5)
    }

    @Test func rejectsFilesThatAreNotPDFs() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).pdf")
        try Data("not a pdf".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(throws: PawnExtractionError.unreadable(url.lastPathComponent)) { try PawnExtractor.extract(from: url) }
        #expect(PawnExtractionError.unreadable("x.pdf").description.contains("x.pdf"))
    }

    @Test func pairsOnlyMirroredPages() {
        let front = Outline(rect: CGRect(x: 20, y: 600, width: 81, height: 138), headEdge: .top)
        let mirrored = Outline(rect: CGRect(x: 511, y: 600, width: 81, height: 138), headEdge: .top)
        let elsewhere = Outline(rect: CGRect(x: 300, y: 100, width: 81, height: 138), headEdge: .top)
        #expect(PagePairing.backs(for: [front], among: [mirrored]) == [mirrored])
        #expect(PagePairing.backs(for: [front], among: [elsewhere]) == nil)
        #expect(PagePairing.backs(for: [], among: [mirrored]) == nil)
    }
}
