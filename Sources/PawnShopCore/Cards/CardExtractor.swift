import CoreGraphics
import Foundation
import PDFKit

/// Finds the creatures in a deck of Battle Cards. Each card's art side draws the same background, frame and
/// badges as every other card, then the creature's own pictures, the creature itself last, alone on a
/// transparent background. Its stat side names it and gives its size and traits.
enum CardExtractor {
    static func extract(from deck: CardDeck) throws -> ExtractionResult {
        guard let artText = PDFDocument(url: deck.artFile), let art = CGPDFDocument(deck.artFile as CFURL)
        else { throw PawnExtractionError.unreadable(deck.artFile.lastPathComponent) }
        let pairs: [CardPairing.Pair]
        let stats: PDFDocument
        if let statsFile = deck.statsFile {
            guard let statsText = PDFDocument(url: statsFile)
            else { throw PawnExtractionError.unreadable(statsFile.lastPathComponent) }
            stats = statsText
            pairs = CardPairing.pairs(artPages: artText.pageCount, statPages: statsText.pageCount)
        } else {
            stats = artText
            pairs = CardPairing.pairs(textless: (0..<artText.pageCount).map { pageIsTextless(artText, $0) })
        }
        return cards(in: pairs, art: art, stats: stats)
    }

    private static func cards(in pairs: [CardPairing.Pair], art: CGPDFDocument, stats: PDFDocument)
        -> ExtractionResult {
        let pages = Dictionary(uniqueKeysWithValues: pairs.map { pair in
            (pair.art, ArtPage(art.page(at: pair.art + 1).map(PageScanner.images(on:)) ?? []))
        })
        let shared = ArtPage.sharedDigests(Array(pages.values))
        var result = ExtractionResult()
        for pair in pairs {
            guard let text = stats.page(at: pair.stats)?.string, let card = CardStats.read(text),
                  let page = pages[pair.art], let pawn = pawn(card, on: pair.art, page: page, shared: shared)
            else { continue }
            PawnExtractor.add(pawn, to: &result)
        }
        return result
    }

    /// The creature on an art page as a pawn; nil when the page draws no picture of its own.
    private static func pawn(_ card: CardStats, on pageIndex: Int, page: ArtPage,
                             shared: Set<String>) -> ExtractedPawn? {
        guard let index = page.creatureIndex(shared: shared), let figure = Figure(page.images[index]),
              let stream = page.images[index].stream
        else { return nil }
        let identity = EmbeddedImage.identity(of: stream)
        let face = PawnFace(pageIndex: pageIndex, rect: figure.bounds, rotation: 0)
        return ExtractedPawn(name: card.name, size: card.size, front: face, back: face.mirroredCopy(),
                             fingerprint: ArtFingerprint(imageDigests: [identity.digest],
                                                         thumbnail: identity.thumbnail),
                             copies: 1, shape: .card(imageIndex: index), traits: card.traits)
    }

    private static func pageIsTextless(_ document: PDFDocument, _ index: Int) -> Bool {
        document.page(at: index)?.string?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
    }
}

/// The pictures a card's art side draws, with their digests.
struct ArtPage {
    let images: [ImagePlacement]
    /// Each image's digest; empty when its data can't be read.
    let digests: [String]

    init(_ images: [ImagePlacement]) {
        self.images = images
        digests = images.map { $0.stream.map(EmbeddedImage.digest(of:)) ?? "" }
    }

    /// The last picture drawn that is the card's own and transparent around its art: the creature.
    func creatureIndex(shared: Set<String>) -> Int? {
        images.indices.last { index in
            guard let stream = images[index].stream, !digests[index].isEmpty else { return false }
            return min(images[index].rect.width, images[index].rect.height) >= ArtFingerprint.smallestArt
                && EmbeddedImage.hasSoftMask(stream) && !shared.contains(digests[index])
        }
    }

    /// The pictures drawn on at least half the pages, and on three or more: the background, frame and badges
    /// every card shares, not a creature printed on a few cards.
    static func sharedDigests(_ pages: [ArtPage]) -> Set<String> {
        var counts: [String: Int] = [:]
        for page in pages {
            for digest in Set(page.digests) where !digest.isEmpty { counts[digest, default: 0] += 1 }
        }
        return Set(counts.filter { $0.value >= 3 && $0.value * 2 >= pages.count }.keys)
    }
}

/// Matches each card's art page with its stat page.
enum CardPairing {
    struct Pair: Equatable {
        /// Zero-based page indexes: of the art in the art PDF, and of the stat block in the stats PDF.
        let art: Int
        let stats: Int
    }

    /// Two-file decks print card n's back on page n of one PDF and its front on page n of the other.
    static func pairs(artPages: Int, statPages: Int) -> [Pair] {
        (0..<min(artPages, statPages)).map { Pair(art: $0, stats: $0) }
    }

    /// One-file decks print each card's art just before its stat block, or runs of stat blocks each followed by
    /// a run of the same cards' art. `textless` says which pages print no words: the art.
    static func pairs(textless: [Bool]) -> [Pair] {
        let artThenStats = textless.indices.dropLast().filter { textless[$0] && !textless[$0 + 1] }
        if artThenStats.count * 3 > textless.count {
            return artThenStats.map { Pair(art: $0, stats: $0 + 1) }
        }
        return runPairs(textless)
    }

    /// The k-th stat page of each run of stat pages with the k-th art page of the run of art pages after it.
    private static func runPairs(_ textless: [Bool]) -> [Pair] {
        var pairs: [Pair] = []
        var start = 0
        while start < textless.count {
            let statsEnd = textless[start...].firstIndex(of: true) ?? textless.count
            let artEnd = textless[statsEnd...].firstIndex(of: false) ?? textless.count
            let count = min(statsEnd - start, artEnd - statsEnd)
            pairs += (0..<count).map { Pair(art: statsEnd + $0, stats: start + $0) }
            start = max(artEnd, start + 1)
        }
        return pairs
    }
}
