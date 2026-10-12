import CoreGraphics
import Foundation

/// An item's card as a sheet prints it: the item, and the art an item deck prints for it, if any.
public struct ItemCardContent: Sendable {
    public let item: CatalogItem
    public let artwork: ItemArtwork?

    public init(item: CatalogItem, artwork: ItemArtwork?) {
        self.item = item
        self.artwork = artwork
    }
}

/// What a placed strip shows: a pawn's strip or an item's card, nil when it is missing.
public enum PlacedContent: Sendable {
    case pawn(Pawn?)
    case card(ItemCardContent?)
}

/// Drawing item cards, single-sided, with the same cut outline as strips and no fold.
extension PawnRenderer {
    /// Draws a pawn's strip or an item's card where `placed` says.
    public func draw(_ content: PlacedContent, in placed: PlacedStrip, settings: SheetSettings, context: CGContext) {
        switch content {
        case .pawn(let pawn): drawStrip(pawn, in: placed, settings: settings, context: context)
        case .card(let card): drawCard(card, in: placed, context: context)
        }
    }

    /// Draws a card where `placed` says; a missing item is drawn as a gray placeholder.
    public func drawCard(_ card: ItemCardContent?, in placed: PlacedStrip, context: CGContext) {
        let upright = placed.sideways ? CGSize(width: placed.rect.height, height: placed.rect.width) : placed.rect.size
        let rect = CGRect(origin: .zero, size: upright)
        context.saveGState()
        context.concatenate(Self.stripTransform(for: placed))
        if let card {
            drawCardFace(card, in: rect, context: context)
        } else {
            drawPlaceholder(in: rect, label: "Missing item", context: context)
        }
        drawCutOutline(rect, context: context)
        context.restoreGState()
    }

    /// Draws a card scaled to fill `rect`, which should have the card's proportions.
    public func drawCardFace(_ card: ItemCardContent, in rect: CGRect, context: CGContext) {
        context.saveGState()
        context.clip(to: rect)
        context.translateBy(x: rect.minX, y: rect.minY)
        context.scaleBy(x: rect.width / ItemCard.size.width, y: rect.height / ItemCard.size.height)
        var painter = ItemCardPainter(item: card.item, style: cardStyle(for: card.item.game), context: context)
        painter.artOpacity = itemArtOpacity
        painter.paint { area in
            drawItemArt(card.artwork, in: area, context: context)
        }
        context.restoreGState()
    }

    /// A bitmap of a card, `height` pixels tall; nil when it can't be made.
    public func cardImage(_ card: ItemCardContent, height: Int) -> CGImage? {
        let width = max(1, Int((CGFloat(height) * ItemCard.size.width / ItemCard.size.height).rounded()))
        guard height > 0, let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                                  bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        drawCardFace(card, in: CGRect(x: 0, y: 0, width: width, height: height), context: context)
        return context.makeImage()
    }

    /// The item's picture as large as fits `area`, centered; nothing when it has none or its deck is gone.
    func drawItemArt(_ artwork: ItemArtwork?, in area: CGRect, context: CGContext) {
        switch artwork?.picture {
        case .figure(let face, _):
            guard let artwork, let figure = figures.figure(of: artwork) else { return }
            let placed = Self.artRect(for: face.uprightSize, in: area, focus: CGPoint(x: 0.5, y: 0.5), scaling: .fit)
            figure.draw(in: placed, rotation: face.rotation, context: context)
        case .drawn(let file):
            guard let image = image(folders.items.appendingPathComponent(file)) else { return }
            context.interpolationQuality = .high
            context.draw(image, in: Self.artRect(for: CGSize(width: image.width, height: image.height), in: area,
                                                 focus: CGPoint(x: 0.5, y: 0.5), scaling: .fit))
        case nil:
            break
        }
    }

    private func cardStyle(for game: Game) -> ItemCardStyle {
        if let style = cardStyles[game] { return style }
        let style = ItemCardStyle.style(for: game, generated: generatedFolder)
        cardStyles[game] = style
        return style
    }
}
