import CoreGraphics
import Testing
@testable import PawnShopCore

@Suite(.enabled(if: RealPDFs.named("Starfinder Core Rulebook Pawn") != nil))
struct RealOutlineTests {
    let core = RealPDFs.document(RealPDFs.named("Starfinder Core Rulebook Pawn")!)!

    @Test func classifiesEveryOutlineOnAFrontPage() throws {
        let outlines = OutlineScanner.outlines(on: try #require(core.page(at: 2))).filter { $0.size != nil }
        #expect(outlines.count == 29)
        #expect(outlines.filter { $0.size == .medium }.allSatisfy { $0.headEdge == .top })
        #expect(outlines.contains { $0.size == .large && [.left, .right].contains($0.headEdge) })
    }

    @Test func findsNoOutlinesOnTheCover() throws {
        #expect(OutlineScanner.outlines(on: try #require(core.page(at: 1))).filter { $0.size != nil }.isEmpty)
    }
}
