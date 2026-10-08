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

/// The Monster Core 2 Pawn Box prints its first pages without backs, in a grid that lines up with the next page.
@Suite(.enabled(if: RealPDFs.named("Monster Core 2 Pawn Box") != nil))
struct RealBackPairingTests {
    let pawns = (try? PawnExtractor.extract(from: RealPDFs.named("Monster Core 2 Pawn Box")!).pawns) ?? []

    @Test func mirrorsFrontsThatHaveNoBackPage() throws {
        let fly = try #require(pawns.first { $0.name == "Fly, Giant" })
        #expect(fly.back == fly.front.mirroredCopy())
    }

    @Test func takesBacksFromThePageThatRepeatsTheArt() throws {
        let hag = try #require(pawns.first { $0.name == "Hag, Moon" })
        let spellblade = try #require(pawns.first { $0.name == "Munavri Spellblade" })
        #expect(hag.back.pageIndex == hag.front.pageIndex + 1 && !hag.back.mirrored)
        #expect(spellblade.back.pageIndex == spellblade.front.pageIndex + 1)
        #expect(hag.front.pageIndex != spellblade.front.pageIndex - 1)
    }
}
