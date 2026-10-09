import CoreGraphics
import Foundation
import Testing
@testable import PawnShopCore

/// Writes a library file holding `sources` and `pawns` into `folder`.
func saveLibrary(sources: [PawnSource], pawns: [Pawn], in folder: URL) throws {
    try JSONEncoder().encode(StoredLibrary(sources: sources, pawns: pawns))
        .write(to: folder.appendingPathComponent(PawnLibrary.indexFile))
}

@Suite struct CardLibraryTests {
    let folder = temporaryFolder()

    func library() throws -> PawnLibrary { try PawnLibrary(folder: folder.appendingPathComponent("Library")) }

    /// A pawn PDF printing the Aeon, Arbiter card's creature, smaller, in `variant`'s colors.
    func pawnBox(variant: Int = 0, name: String = "AEON, ARBITER") throws -> URL {
        let pawn = DrawnPawn(rect: CGRect(x: 20, y: 600, width: 81, height: 138),
                             art: creatureArt(variant: variant), name: name)
        return try writePawnPDF([pawn], named: "Pathfinder Bestiary Pawn Box.pdf", in: folder)
    }

    @Test func importsADeckAsPawnsDrawnFromTheCards() throws {
        let library = try library()
        let report = try library.importPDF(at: try writeCardDeck(threeCards, in: folder))
        #expect(report.sourceTitle == "Pathfinder Test Battle Cards" && report.added == 3)
        let pawn = try #require(library.pawns.first)
        guard case .card(let art) = pawn.art else { Issue.record("not a card"); return }
        #expect(art.imageIndex == 3 && art.sourceID == library.sources.first?.id)
        #expect(pawn.traits == ["tiny", "aeon", "monitor"])
        #expect(try PawnLibrary(folder: library.folder).pawns == library.pawns)
    }

    @Test func importsATwoFileDeckOnceFromEitherFile() throws {
        let deck = try writeSplitDeck(threeCards, in: folder)
        let library = try library()
        let prepared = try PawnLibrary.prepareImport(of: deck.fronts)
        #expect(prepared.file == deck.backs && prepared.title == "Test Battle Cards")
        try library.commit(prepared)
        #expect(library.hasImported(deck.fronts) && library.hasImported(deck.backs))
        #expect(library.pawns.count == 3)
    }

    @Test func readsAgainOnlyWhatAnOlderReaderFoundNothingIn() throws {
        let empty = try writeCardDeck(threeCards.map { DrawnCard(name: $0.name, creature: nil) }, in: folder)
        let library = try library()
        let first = try library.importPDF(at: empty)
        let source = try #require(library.sources.first)
        let copy = library.fileURL(forSource: source.id)
        #expect(first.added == 0 && !FileManager.default.fileExists(atPath: copy.path))
        #expect(source.pawnsFound == 0 && source.readerVersion == PawnExtractor.version)
        // The current reader found nothing, so it doesn't try again.
        let again = try library.importPDF(at: empty)
        #expect(library.hasImported(empty) && again.wasImported)
        var older = source
        older.readerVersion = PawnExtractor.version - 1
        try saveLibrary(sources: [older], pawns: [], in: library.folder)
        try writeCardDeck(threeCards, in: folder)
        let reopened = try PawnLibrary(folder: library.folder)
        #expect(!reopened.hasImported(empty))
        #expect(try reopened.importPDF(at: empty).added == 3)
        #expect(reopened.sources.count == 1 && reopened.hasImported(empty))
    }

    @Test func keepsAProductImportedWhenItsPawnsAreRemoved() throws {
        let deck = try writeCardDeck(threeCards, in: folder)
        let library = try library()
        try library.importPDF(at: deck)
        try library.remove(Set(library.pawns.map(\.id)))
        let again = try library.importPDF(at: deck)
        #expect(library.hasImported(deck) && again.wasImported)
    }

    @Test func triesAgainAnOlderProductThatNoPawnComesFrom() throws {
        let deck = try writeCardDeck(threeCards, in: folder)
        let library = try library()
        try library.importPDF(at: deck)
        let older = try #require(library.sources.first)
        let unrecorded = PawnSource(id: older.id, title: older.title, importedAt: older.importedAt,
                                    originalPath: older.originalPath, byteCount: older.byteCount)
        try saveLibrary(sources: [unrecorded], pawns: [], in: library.folder)
        let reopened = try PawnLibrary(folder: library.folder)
        #expect(!reopened.hasImported(deck))
        #expect(try reopened.importPDF(at: deck).added == 3)
    }

    @Test func drawsAPawnBoxPawnFromTheSharperCard() throws {
        let library = try library()
        try library.importPDF(at: try pawnBox())
        let report = try library.importPDF(at: try writeCardDeck(threeCards, in: folder))
        #expect(report.added == 2 && report.alreadyKnown == 1 && report.sharpened == 1)
        let arbiter = try #require(library.pawns.first { $0.name == "Aeon, Arbiter" })
        #expect(arbiter.art.isCard && arbiter.size == .medium && arbiter.traits == ["tiny", "aeon", "monitor"])
        #expect(library.sourceTitles(of: arbiter) == ["Pathfinder Test Battle Cards", "Pathfinder Bestiary Pawn Box"])
    }

    @Test func keepsTheSharperCardWhenThePawnBoxComesLater() throws {
        var cards = threeCards
        cards[0].traits = "LN LARGE AEON"
        let library = try library()
        try library.importPDF(at: try writeCardDeck(cards, in: folder))
        let report = try library.importPDF(at: try pawnBox())
        #expect(report.added == 0 && report.alreadyKnown == 1 && report.sharpened == 0)
        let arbiter = try #require(library.pawns.first { $0.name == "Aeon, Arbiter" })
        // The printed pawn's outline sets the size.
        #expect(arbiter.art.isCard && arbiter.size == .medium && arbiter.appearances.count == 2)
    }

    @Test func keepsADifferentPaintingOfTheSameCreatureApart() throws {
        let library = try library()
        try library.importPDF(at: try pawnBox(variant: 2))
        let report = try library.importPDF(at: try writeCardDeck(threeCards, in: folder))
        #expect(report.added == 3 && report.alreadyKnown == 0)
        #expect(library.pawns.filter { $0.name == "Aeon, Arbiter" }.count == 2)
    }

    @Test func addsAReprintedCardToTheSamePawn() throws {
        let library = try library()
        try library.importPDF(at: try writeCardDeck(threeCards, in: folder))
        let other = try writeCardDeck(threeCards, layout: .blocks, named: "Other Battle Cards.pdf", in: folder)
        let report = try library.importPDF(at: other)
        #expect(report.added == 0 && report.alreadyKnown == 3 && report.sharpened == 0)
        #expect(library.pawns.allSatisfy { $0.appearances.count == 2 })
    }

    @Test(arguments: [("Elemental, Air, Invisible Stalker", "Elemental, Invisible Stalker", true),
                      ("Imp", "Devil, Imp", true), ("Aeon, Arbiter", "AEON, ARBITER", true),
                      ("Giant, Wood", "Golem, Wood", false), ("Ghoul", "Ghast", false)])
    func matchesNamesThatPrintMoreOrLessOfTheFamily(first: String, second: String, matches: Bool) {
        #expect(PawnLibrary.namesMatch(first, second) == matches)
        #expect(PawnLibrary.nameKey("Elemental, Air, Invisible Stalker ") == "invisible stalker")
    }

    @Test func findsPawnsByTheStartOfTheirTraits() throws {
        let library = try library()
        try library.importPDF(at: try writeCardDeck(threeCards, in: folder))
        #expect(library.search(PawnQuery(text: "undead")).map(\.name) == ["Ghoul"])
        #expect(library.search(PawnQuery(text: "drag fire")).map(\.name) == ["Dragon, Young Red"])
        #expect(library.search(PawnQuery(text: "ead")).isEmpty)
    }

    @Test func drawsTheCreatureStandingOnItsName() throws {
        let library = try library()
        try library.importPDF(at: try writeCardDeck(threeCards, in: folder))
        let pawn = try #require(library.pawns.first)
        let renderer = PawnRenderer(library: library)
        #expect(renderer.uprightSize(of: pawn) == PawnSize.medium.outlineSize)
        let face = try #require(renderer.thumbnail(of: pawn, height: 276))
        // The creature's red body sits just above the name band; the corners are white.
        let body = pixel(of: face, x: face.width / 2, y: face.height * 3 / 4)
        #expect(body[0] > 150 && body[1] < 80)
        #expect(pixel(of: face, x: 2, y: 2) == [255, 255, 255, 255])
        let art = try #require(renderer.artImage(of: pawn, height: 276))
        #expect(pixel(of: art, x: art.width / 2, y: art.height * 3 / 4)[0] > 150)
        let back = try #require(renderer.thumbnail(of: pawn, side: .back, height: 276))
        #expect(pixel(of: back, x: back.width / 2, y: back.height * 3 / 4) == body)
    }

    @Test func drawsAPlaceholderWhenTheDeckIsMissing() throws {
        let library = try library()
        try library.importPDF(at: try writeCardDeck(threeCards, in: folder))
        let pawn = try #require(library.pawns.first)
        try FileManager.default.removeItem(at: library.fileURL(forSource: try #require(pawn.art.sourceID)))
        let face = try #require(PawnRenderer(library: library).thumbnail(of: pawn, height: 276))
        #expect(pixel(of: face, x: face.width / 2, y: face.height / 2)[0] < 250)
    }

    @Test func readsPawnsSavedBeforeTraits() throws {
        let pawn = Pawn(name: "Ghoul", size: .medium,
                        art: .card(CardArt(sourceID: "deck", face: PawnFace(pageIndex: 2, rect: .zero, rotation: 0),
                                           imageIndex: 4)))
        var stored = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(pawn)) as? [String: Any])
        #expect(stored["traits"] != nil)
        stored["traits"] = nil
        let decoded = try JSONDecoder().decode(Pawn.self, from: JSONSerialization.data(withJSONObject: stored))
        #expect(decoded.traits.isEmpty && decoded.art == pawn.art && decoded.art.sourceID == "deck")
    }
}

@Suite struct FigureTests {
    @Test func comparesPaintingsByTheirColors() throws {
        let deck = try writeCardDeck(threeCards, in: temporaryFolder())
        let document = try #require(CGPDFDocument(deck as CFURL))
        let figures = [1, 3].compactMap { document.page(at: $0) }.compactMap { page in
            PageScanner.images(on: page).last.flatMap(Figure.init)
        }
        try #require(figures.count == 2)
        #expect(figures[0].isSamePainting(as: figures[0]) && !figures[0].isSamePainting(as: figures[1]))
        #expect(Figure.paletteDistance([], figures[0].palette()) == 1)
        #expect(figures[0].pixelArea > 100 * 150)
    }

    @Test func findsNoFigureInATransparentPicture() throws {
        let blank = CGContext(data: nil, width: 4, height: 4, bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!.makeImage()!
        let pdf = makePDF(size: cardPage, pages: [{ $0.draw(blank, in: CGRect(x: 0, y: 0, width: 50, height: 50)) }])
        let page = try #require(document(pdf).page(at: 1))
        #expect(PageScanner.images(on: page).compactMap(Figure.init).isEmpty)
    }

    @Test func readsNoFigureForCustomArtOrTokens() {
        let reader = FigureReader(folders: LibraryFolders(root: temporaryFolder()))
        let custom = Pawn(name: "Mine", size: .medium, art: .custom(CustomArt(imageFile: "mine.png")))
        let token = Pawn(name: "Coin", size: .medium, art: .token(TokenArt(sourceID: "s", frontPicture: "t.png")))
        #expect(reader.figure(of: custom) == nil && reader.figure(of: token) == nil)
        let missing = Pawn(name: "Gone", size: .medium,
                           art: .card(CardArt(sourceID: "gone", face: PawnFace(pageIndex: 0, rect: .zero, rotation: 0),
                                              imageIndex: 9)))
        #expect(reader.figure(of: missing) == nil)
    }
}
