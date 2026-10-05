import Testing
@testable import PawnShopCore

@Suite(.enabled(if: RealPDFs.named("Starfinder Core Rulebook Pawn") != nil && RealPDFs.named("Skull & Shackles") != nil
                && RealPDFs.named("Bestiary Pawn Box") != nil))
struct RealExtractionTests {
    @Test func extractsEveryPawnOfACollection() throws {
        let result = try PawnExtractor.extract(from: RealPDFs.named("Starfinder Core Rulebook Pawn")!)
        #expect(result.unnamed.isEmpty)
        let android = try #require(result.pawns.first { $0.name == "Android Abolitionist" })
        #expect(android.size == .medium && android.copies == 2)
        #expect(android.back.pageIndex == android.front.pageIndex + 1)
        let ship = try #require(result.pawns.first { $0.name == "Atech Immortal" })
        #expect(ship.size == .large && ship.front.rotation % 180 == 90)
    }

    @Test func keepsDifferentArtWithTheSameNameApart() throws {
        let pirates = try PawnExtractor.extract(from: RealPDFs.named("Skull & Shackles")!).pawns
            .filter { $0.name == "Pirate" }
        #expect(pirates.count == 2)
    }

    @Test func mergesCopiesEmbeddedSeparately() throws {
        let thugs = try PawnExtractor.extract(from: RealPDFs.named("Bestiary Pawn Box")!).pawns
            .filter { $0.name == "Bugbear Thug" }
        #expect(thugs.map(\.copies) == [2])
    }
}
