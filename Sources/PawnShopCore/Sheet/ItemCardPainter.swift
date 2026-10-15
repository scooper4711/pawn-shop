import CoreGraphics
import CoreText
import Foundation

/// The size of an item card: Paizo's item decks', 63 × 88 mm.
public enum ItemCard {
    public static let size = CGSize(width: .millimeters(63), height: .millimeters(88))
    /// How opaque the item's art is behind the text unless the user chooses otherwise: visible, yet faint enough
    /// to read over.
    public static let defaultArtOpacity: CGFloat = 0.4
}

/// Draws one card of an item's set in card coordinates (`ItemCard.size`, origin at the bottom left): the
/// background and the name and level on every card; on the first, the item's art faint over it, the traits and
/// the stats; then the card's part of the description, and the source with "Card 1 of 2" when there are more.
struct ItemCardPainter {
    let item: CatalogItem
    let style: ItemCardStyle
    let context: CGContext
    /// The card's part of the description.
    var page: ItemCardPage
    /// Which card of the set this is, from 0, and how many there are.
    var index = 0
    var count = 1
    /// How opaque the item's art is behind the text, from 0 (none) to 1.
    var artOpacity = ItemCard.defaultArtOpacity

    init(item: CatalogItem, style: ItemCardStyle, context: CGContext, page: ItemCardPage) {
        self.item = item
        self.style = style
        self.context = context
        self.page = page
    }

    private var geometry: ItemCardGeometry { ItemCardGeometry(item: item, actionFont: style.actionFont) }
    private var isFirstCard: Bool { index == 0 }

    /// Draws the card; `drawArt` draws the item's picture as large as fits a rect, or nothing.
    func paint(drawArt: (CGRect) -> Void) {
        let geometry = geometry
        drawBackground(in: geometry.card)
        if isFirstCard, artOpacity > 0 {
            context.saveGState()
            context.setAlpha(min(artOpacity, 1))
            drawArt(CGRect(x: geometry.inner.minX, y: geometry.inner.minY, width: geometry.inner.width,
                           height: geometry.title.minY - geometry.inner.minY).insetBy(dx: 4, dy: 4))
            context.restoreGState()
        }
        drawTitle(in: geometry.title)
        if isFirstCard {
            drawTraits(geometry.chips)
            drawStats(geometry)
        }
        drawSource(in: geometry.source)
        ItemCardText(markup: page.markup, ink: style.ink, actionFont: style.actionFont)
            .draw(in: geometry.textRect(isFirstCard: isFirstCard), size: page.size, ruleColor: style.ruleColor,
                  context: context)
    }

    // MARK: Background and title

    private func drawBackground(in card: CGRect) {
        context.setFillColor(style.fill)
        context.fill(card)
        if let background = style.background {
            // Sliced, so the parchment's torn edge stays a thin border however the card's shape stretches it.
            context.drawNineSlice(background, in: card, cap: 70, capPoints: 9)
        }
        if let frame = style.frame {
            context.drawNineSlice(frame, in: card.insetBy(dx: 2, dy: 2), cap: 40, capPoints: 8)
        } else if let stroke = style.frameStroke {
            context.setStrokeColor(stroke)
            context.setLineWidth(1.5)
            context.stroke(card.insetBy(dx: 8, dy: 8))
        } else if style.background == nil {
            context.setStrokeColor(gray: 0.55, alpha: 1)
            context.setLineWidth(1.5)
            context.stroke(card.insetBy(dx: 4, dy: 4))
        }
        drawCorners(in: card)
    }

    /// Starfinder's corner pieces, in order top left, top right, bottom left, bottom right.
    private func drawCorners(in card: CGRect) {
        let side: CGFloat = 18
        let origins = [CGPoint(x: card.minX + 3, y: card.maxY - 3 - side), CGPoint(x: card.maxX - 3 - side,
                       y: card.maxY - 3 - side), CGPoint(x: card.minX + 3, y: card.minY + 3),
                       CGPoint(x: card.maxX - 3 - side, y: card.minY + 3)]
        for (corner, origin) in zip(style.corners, origins) {
            let height = side * CGFloat(corner.height) / CGFloat(corner.width)
            let lowered = origin.y + (origin.y > card.midY ? side - height : 0)
            context.draw(corner, in: CGRect(x: origin.x, y: lowered, width: side, height: height))
        }
    }

    private func drawTitle(in rect: CGRect) {
        if let band = style.titleBand, let face = style.titleFace {
            context.draw(band, in: Self.bandRect(placingFace: face, over: rect))
        } else if let band = style.titleBand {
            context.drawNineSlice(band, in: rect.insetBy(dx: -4, dy: 0), cap: band.height / 3, capPoints: 8)
        } else {
            context.setFillColor(style.titleFill)
            context.fill(rect)
        }
        let level = "\(item.kind.cardLabel) \(item.level)"
        let levelLine = Self.line(level, font: ItemCardFonts.body(size: 7.5, emphasis: .bold), color: style.titleInk)
        let levelWidth = CGFloat(CTLineGetTypographicBounds(levelLine, nil, nil, nil))
        draw(levelLine, at: CGPoint(x: rect.maxX - 6 - levelWidth, y: rect.midY - 2.5))
        let nameWidth = rect.width - levelWidth - 18
        let (lines, size) = Self.fittedName(item.name.uppercased(), width: nameWidth)
        let leading = size * 1.05
        let top = rect.midY + leading * CGFloat(lines.count) / 2
        for (index, text) in lines.enumerated() {
            let line = Self.line(text, font: ItemCardFonts.body(size: size, emphasis: .bold), color: style.titleInk)
            draw(line, at: CGPoint(x: rect.minX + 6, y: top - leading * (CGFloat(index) + 0.8)))
        }
    }

    /// Where to draw a band image so that its `face` (fractions of the image from its top left) covers `rect`.
    static func bandRect(placingFace face: CGRect, over rect: CGRect) -> CGRect {
        let size = CGSize(width: rect.width / face.width, height: rect.height / face.height)
        return CGRect(x: rect.minX - face.minX * size.width, y: rect.maxY - (1 - face.minY) * size.height,
                      width: size.width, height: size.height)
    }

    /// The name on one line, or two, from 10 points down to 6.
    static func fittedName(_ name: String, width: CGFloat) -> (lines: [String], size: CGFloat) {
        let words = name.split(separator: " ").map(String.init)
        let candidates = [[name]] + NameLayout.twoLineSplits(words)
        var size: CGFloat = 10
        while size > 6 {
            let font = ItemCardFonts.body(size: size, emphasis: .bold)
            if let lines = candidates.first(where: { $0.allSatisfy { textWidth($0, font: font) <= width } }) {
                return (lines, size)
            }
            size -= 0.25
        }
        return (candidates.last ?? [name], 6)
    }

    // MARK: Traits, stats and source

    private func drawTraits(_ chips: [(trait: String, rect: CGRect)]) {
        let font = ItemCardFonts.body(size: ItemCardGeometry.chipFontSize, emphasis: .bold)
        for (trait, rect) in chips {
            context.setFillColor(ItemCardStyle.rarityFill(trait) ?? style.chipFill)
            context.fill(rect)
            draw(Self.line(trait.uppercased(), font: font, color: style.chipInk),
                 at: CGPoint(x: rect.minX + 3, y: rect.minY + 2.6))
        }
    }

    /// Draws the stats two to a row, a long one on a row of its own, with a rule between them and the text.
    private func drawStats(_ geometry: ItemCardGeometry) {
        let rows = geometry.statRows
        guard !rows.isEmpty else { return }
        let area = geometry.statsRect
        for (index, row) in rows.enumerated() {
            let baseline = area.maxY - ItemCardGeometry.statRowHeight * CGFloat(index + 1) + 2.5
            for (column, stat) in row.enumerated() {
                draw(ItemCardGeometry.statLine(stat, ink: style.ink, actionFont: style.actionFont),
                     at: CGPoint(x: area.minX + 1 + area.width / 2 * CGFloat(column), y: baseline))
            }
        }
        let ruleY = item.kind.isSpell ? area.minY - 2 : area.maxY + 2
        context.setStrokeColor(style.ruleColor)
        context.setLineWidth(0.5)
        context.stroke(CGRect(x: area.minX, y: ruleY, width: area.width, height: 0))
    }

    /// The source, and which card of the set this is when there are more: "Pathfinder Player Core · Card 1 of 2".
    private func drawSource(in rect: CGRect) {
        let text = [item.source, count > 1 ? "Card \(index + 1) of \(count)" : ""].filter { !$0.isEmpty }
            .joined(separator: " · ")
        let line = Self.line(text, font: ItemCardFonts.body(size: 5.5, emphasis: .italic), color: style.ink)
        let width = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
        // Centered, clear of Starfinder's corner pieces.
        draw(line, at: CGPoint(x: rect.midX - width / 2, y: rect.minY + 1.5))
    }

    // MARK: Lines

    private func draw(_ line: CTLine, at origin: CGPoint) {
        context.textMatrix = .identity
        context.textPosition = origin
        CTLineDraw(line, context)
    }

    private static func line(_ text: String, font: CTFont, color: CGColor) -> CTLine {
        ItemCardGeometry.line(text, font: font, color: color)
    }

    private static func textWidth(_ text: String, font: CTFont) -> CGFloat {
        ItemCardGeometry.textWidth(text, font: font)
    }
}
