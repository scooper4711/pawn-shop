import CoreGraphics
import Foundation
@testable import PawnShopCore

/// A Battle Card, in points.
let cardPage = CGSize(width: 289, height: 425)
/// Where a test card's art side draws its creature.
let creatureRect = CGRect(x: 20, y: 20, width: 240, height: 360)

/// A creature on a transparent background, so a PDF embeds it with a soft mask: a body and a head in colors
/// chosen by `variant`, 60 × 90 pixels times `scale`. Its opaque part spans x 15–45 and y 10–75 of 60 × 90,
/// from the bottom left.
func creatureArt(variant: Int = 0, scale: Int = 1) -> CGImage {
    let context = CGContext(data: nil, width: 60 * scale, height: 90 * scale, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
    let colors = [(0.8, 0.15, 0.1), (0.1, 0.55, 0.3), (0.2, 0.3, 0.9)]
    let (red, green, blue) = colors[variant % colors.count]
    context.setFillColor(CGColor(srgbRed: red, green: green, blue: blue, alpha: 1))
    context.fillEllipse(in: CGRect(x: 15, y: 10, width: 30, height: 50))
    context.setFillColor(CGColor(srgbRed: blue, green: red, blue: green, alpha: 1))
    context.fillEllipse(in: CGRect(x: 20, y: 55, width: 20, height: 20))
    return context.makeImage()!
}

/// The creature's opaque part where a test card draws it.
let creatureBounds = CGRect(x: creatureRect.minX + creatureRect.width * 15 / 60,
                            y: creatureRect.minY + creatureRect.height * 10 / 90,
                            width: creatureRect.width * 30 / 60, height: creatureRect.height * 65 / 90)

/// A card frame: a border on a transparent background, the same on every card.
let cardFrame: CGImage = {
    let context = CGContext(data: nil, width: 40, height: 60, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.setStrokeColor(CGColor(srgbRed: 0.6, green: 0.5, blue: 0.2, alpha: 1))
    context.setLineWidth(4)
    context.stroke(CGRect(x: 2, y: 2, width: 36, height: 56))
    return context.makeImage()!
}()

/// A Battle Card as a test deck prints it.
struct DrawnCard {
    var name: String
    var traits = "N MEDIUM HUMANOID"
    var creature: CGImage? = creatureArt()
    /// A line printed on the art side, as the NPC deck credits its illustrators.
    var credit: String?

    /// The art side: a background and frame every card shares, a large faded copy of the creature, then the
    /// creature itself.
    func drawArt(_ context: CGContext) {
        context.draw(darkBackground(), in: CGRect(origin: .zero, size: cardPage))
        if let creature {
            context.saveGState()
            context.setAlpha(0.3)
            context.draw(creatureArt(variant: 2, scale: 2), in: CGRect(x: -40, y: -40, width: 369, height: 505))
            context.restoreGState()
        }
        context.draw(cardFrame, in: CGRect(origin: .zero, size: cardPage))
        if let creature { context.draw(creature, in: creatureRect) }
        if let credit { drawText(context, credit, at: CGPoint(x: 12, y: 8), size: 5) }
    }

    /// The stat side: the name and level, the traits, then the stat block.
    func drawStats(_ context: CGContext) {
        drawText(context, "\(name) CREATURE 3", at: CGPoint(x: 12, y: 400), size: 9)
        drawText(context, traits, at: CGPoint(x: 12, y: 386), size: 7)
        drawText(context, "Perception +9; darkvision", at: CGPoint(x: 12, y: 372), size: 7)
    }
}

/// How a one-file deck orders its pages.
enum CardLayout {
    /// Each card's art, then its stat side.
    case alternating
    /// Every card's stat side, then every card's art.
    case blocks
}

func cardDeckPDF(_ cards: [DrawnCard], layout: CardLayout) -> Data {
    let pages: [(CGContext) -> Void]
    switch layout {
    case .alternating: pages = cards.flatMap { card in [card.drawArt, card.drawStats] }
    case .blocks: pages = cards.map { $0.drawStats } + cards.map { $0.drawArt }
    }
    return makePDF(size: cardPage, pages: pages)
}

/// Writes a one-file deck named `name` into `folder`.
func writeCardDeck(_ cards: [DrawnCard], layout: CardLayout = .alternating,
                   named name: String = "Pathfinder Test Battle Cards.pdf", in folder: URL) throws -> URL {
    let url = folder.appendingPathComponent(name)
    try cardDeckPDF(cards, layout: layout).write(to: url)
    return url
}

/// Writes a two-file deck, "<base> FRONT.pdf" with the stat sides and "<base> BACKS.pdf" with the art.
func writeSplitDeck(_ cards: [DrawnCard], base: String = "PZO1 Test Battle Cards",
                    in folder: URL) throws -> (fronts: URL, backs: URL) {
    let fronts = folder.appendingPathComponent("\(base) FRONT.pdf")
    let backs = folder.appendingPathComponent("\(base) BACKS.pdf")
    try makePDF(size: cardPage, pages: cards.map { $0.drawStats }).write(to: fronts)
    try makePDF(size: cardPage, pages: cards.map { $0.drawArt }).write(to: backs)
    return (fronts, backs)
}

/// Three cards, as decks need several for their shared pictures to tell from the creatures.
let threeCards = [
    DrawnCard(name: "AEON, ARBITER", traits: "LN TINY AEON MONITOR", creature: creatureArt(variant: 0, scale: 4)),
    DrawnCard(name: "GHOUL", traits: "CE MEDIUM GHOUL UNDEAD", creature: creatureArt(variant: 1, scale: 4)),
    DrawnCard(name: "DRAGON, YOUNG RED", traits: "UNCOMMON CE LARGE DRAGON FIRE",
              creature: creatureArt(variant: 2, scale: 4))
]
