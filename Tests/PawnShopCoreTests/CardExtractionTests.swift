import CoreGraphics
import Foundation
import Testing
@testable import PawnShopCore

@Suite struct CardDeckTests {
    let folder = temporaryFolder()

    @Test func takesAOneFileDeckAsItIs() throws {
        let file = try writeCardDeck(threeCards, in: folder)
        let deck = try #require(CardDeck.containing(file))
        #expect(deck == CardDeck(artFile: file, statsFile: nil))
        #expect(deck.title == "Pathfinder Test Battle Cards")
    }

    @Test func findsBothFilesOfATwoFileDeckFromEither() throws {
        let deck = try writeSplitDeck(threeCards, in: folder)
        let expected = CardDeck(artFile: deck.backs, statsFile: deck.fronts)
        #expect(CardDeck.containing(deck.fronts) == expected && CardDeck.containing(deck.backs) == expected)
        #expect(expected.title == "Test Battle Cards")
    }

    @Test func titlesADeckFromTheFoldersScrollkeeperKeepsItIn() throws {
        let product = folder.appendingPathComponent("Starfinder Alien Archive 1 & 2 Battle Cards")
        let download = product.appendingPathComponent("Starfinder Alien Archive 1 & 2 Battle Cards (Download) - PDFs")
        try FileManager.default.createDirectory(at: download, withIntermediateDirectories: true)
        let deck = try writeSplitDeck(threeCards, base: "PZO7425 Alien Archive 1 & 2 Battle Cards", in: download)
        #expect(CardDeck.containing(deck.backs)?.title == "Starfinder Alien Archive 1 & 2 Battle Cards")
        let single = folder.appendingPathComponent("Pathfinder Bestiary Battle Cards")
        try FileManager.default.createDirectory(at: single, withIntermediateDirectories: true)
        let file = try writeCardDeck(threeCards, named: "Pathfinder Bestiary Battle Cards - PDF.pdf", in: single)
        #expect(CardDeck.containing(file)?.title == "Pathfinder Bestiary Battle Cards")
    }

    @Test func titlesADeckFromItsFileNameWithoutTheDownloadWords() throws {
        let file = try writeCardDeck(threeCards, named: "PZO2 Pathfinder Bestiary Battle Cards - PDF.pdf", in: folder)
        #expect(CardDeck.containing(file)?.title == "Pathfinder Bestiary Battle Cards")
    }

    @Test func leavesOtherPDFsAlone() {
        #expect(CardDeck.containing(folder.appendingPathComponent("Pathfinder Pawns- Bestiary Box.pdf")) == nil)
    }

    @Test func importsEachDeckOnceAsItsArtFile() throws {
        let deck = try writeSplitDeck(threeCards, in: folder)
        let pawns = folder.appendingPathComponent("Pawns.pdf")
        #expect(PawnLibrary.importableFiles([deck.fronts, pawns, deck.backs, pawns]) == [deck.backs, pawns])
    }

    @Test func findsDecksInScrollkeepersFolderOnce() throws {
        let product = folder.appendingPathComponent("Pathfinder Bestiary 2 Battle Cards")
        try FileManager.default.createDirectory(at: product, withIntermediateDirectories: true)
        let deck = try writeSplitDeck(threeCards, base: "PZO2219 Bestiary 2 Battle Cards", in: product)
        try Data().write(to: product.appendingPathComponent("Readme.txt"))
        #expect(ScrollkeeperScanner.pawnPDFs(in: folder).map(\.lastPathComponent) == [deck.backs.lastPathComponent])
    }
}

@Suite struct CardPairingTests {
    @Test func pairsEachArtPageWithTheStatPageAfterIt() {
        let pairs = CardPairing.pairs(textless: [true, false, true, false, false, true, false])
        #expect(pairs == [.init(art: 0, stats: 1), .init(art: 2, stats: 3), .init(art: 5, stats: 6)])
    }

    @Test func pairsRunsOfStatPagesWithTheRunsOfArtAfterThem() {
        let pairs = CardPairing.pairs(textless: [false, false, false, true, true, true, false, true, true])
        #expect(pairs == [.init(art: 3, stats: 0), .init(art: 4, stats: 1), .init(art: 5, stats: 2),
                          .init(art: 7, stats: 6)])
    }

    @Test func pairsTheSamePagesOfTwoFiles() {
        #expect(CardPairing.pairs(artPages: 3, statPages: 2) == [.init(art: 0, stats: 0), .init(art: 1, stats: 1)])
    }
}

@Suite struct CardExtractionTests {
    let folder = temporaryFolder()

    func extract(_ url: URL) throws -> ExtractionResult { try PawnExtractor.extract(from: url) }

    @Test(arguments: [CardLayout.alternating, .blocks])
    func findsEachCreatureWithItsNameSizeAndTraits(layout: CardLayout) throws {
        let result = try extract(try writeCardDeck(threeCards, layout: layout, in: folder))
        #expect(result.pawns.map(\.name) == ["Aeon, Arbiter", "Ghoul", "Dragon, Young Red"])
        #expect(result.pawns.map(\.size) == [.medium, .medium, .large])
        #expect(result.pawns.map(\.traits) == [["tiny", "aeon", "monitor"], ["medium", "ghoul", "undead"],
                                               ["large", "dragon", "fire"]])
    }

    @Test func takesTheCreatureAloneTrimmedToItsOpaquePart() throws {
        let pawn = try #require(try extract(try writeCardDeck(threeCards, in: folder)).pawns.first)
        // The background, the faded copy and the frame come first on the page; the creature is drawn last.
        #expect(pawn.shape == .card(imageIndex: 3))
        #expect(pawn.front.pageIndex == 0 && pawn.back == pawn.front.mirroredCopy())
        let rect = pawn.front.rect
        #expect(abs(rect.minX - creatureBounds.minX) < 3 && abs(rect.maxX - creatureBounds.maxX) < 3)
        #expect(abs(rect.minY - creatureBounds.minY) < 3 && abs(rect.maxY - creatureBounds.maxY) < 3)
        #expect(pawn.fingerprint.imageDigests.count == 1 && !pawn.fingerprint.thumbnail.isEmpty)
    }

    @Test func readsATwoFileDeck() throws {
        let deck = try writeSplitDeck(threeCards, in: folder)
        let result = try extract(deck.fronts)
        #expect(result.pawns.map(\.name) == ["Aeon, Arbiter", "Ghoul", "Dragon, Young Red"])
        #expect(result.pawns.map(\.front.pageIndex) == [0, 1, 2])
    }

    @Test func skipsCardsWithoutACreatureOrAStatBlock() throws {
        var cards = threeCards
        cards.append(DrawnCard(name: "SPIKED PIT", traits: "TRAP", creature: nil))
        cards.append(DrawnCard(name: "(Ghoul; continued from card 2)", creature: creatureArt(variant: 1, scale: 3)))
        let result = try extract(try writeSplitDeck(cards, in: folder).backs)
        #expect(result.pawns.map(\.name) == ["Aeon, Arbiter", "Ghoul", "Dragon, Young Red"])
    }

    @Test func countsTheSameCardPrintedTwiceAsCopies() throws {
        let result = try extract(try writeCardDeck(threeCards + [threeCards[1]], in: folder))
        #expect(result.pawns.map(\.copies) == [1, 2, 1])
    }

    @Test func reportsAnUnreadableDeck() throws {
        let file = folder.appendingPathComponent("Broken Battle Cards.pdf")
        try Data("not a PDF".utf8).write(to: file)
        #expect(throws: PawnExtractionError.unreadable("Broken Battle Cards.pdf")) { try extract(file) }
        let deck = try writeSplitDeck(threeCards, in: folder)
        try Data("not a PDF".utf8).write(to: deck.fronts)
        #expect(throws: PawnExtractionError.unreadable(deck.fronts.lastPathComponent)) { try extract(deck.backs) }
    }
}
