import CoreGraphics
import CoreText
import Foundation

/// The size of an item card: Paizo's item decks', 63 × 88 mm.
public enum ItemCard {
    public static let size = CGSize(width: .millimeters(63), height: .millimeters(88))
    /// How opaque the item's art is behind the text unless the user chooses otherwise: visible, yet faint enough
    /// to read over.
    public static let defaultArtOpacity: CGFloat = 0.3
}

/// Draws an item's card in card coordinates (`ItemCard.size`, origin at the bottom left): the background, the
/// item's art faint over it, then the name and level, the traits, the description, the stats and the source.
struct ItemCardPainter {
    /// Clears the frame and the parchment's torn edge.
    static let inset: CGFloat = 13
    static let titleHeight: CGFloat = 24
    static let chipHeight: CGFloat = 9
    static let statRowHeight: CGFloat = 9.5
    static let sourceHeight: CGFloat = 8

    let item: CatalogItem
    let style: ItemCardStyle
    let context: CGContext
    /// How opaque the item's art is behind the text, from 0 (none) to 1.
    var artOpacity = ItemCard.defaultArtOpacity

    /// Draws the card; `drawArt` draws the item's picture as large as fits a rect, or nothing.
    func paint(drawArt: (CGRect) -> Void) {
        let card = CGRect(origin: .zero, size: ItemCard.size)
        drawBackground(in: card)
        let inner = card.insetBy(dx: Self.inset, dy: Self.inset)
        let title = CGRect(x: inner.minX, y: inner.maxY - Self.titleHeight, width: inner.width,
                           height: Self.titleHeight)
        if artOpacity > 0 {
            context.saveGState()
            context.setAlpha(min(artOpacity, 1))
            drawArt(CGRect(x: inner.minX, y: inner.minY, width: inner.width, height: title.minY - inner.minY)
                .insetBy(dx: 4, dy: 4))
            context.restoreGState()
        }
        drawTitle(in: title)
        let chipsBottom = drawTraits(below: title.minY - 3, in: inner)
        let source = CGRect(x: inner.minX, y: inner.minY, width: inner.width, height: Self.sourceHeight)
        drawSource(in: source)
        let statsTop = drawStats(above: source.maxY + 2, in: inner)
        let text = CGRect(x: inner.minX + 1, y: statsTop + 4, width: inner.width - 2,
                          height: chipsBottom - 4 - (statsTop + 4))
        ItemCardText(markup: item.description, ink: style.ink, actionFont: style.actionFont)
            .draw(in: text, ruleColor: style.ruleColor, context: context)
    }

    // MARK: Background and title

    private func drawBackground(in card: CGRect) {
        context.setFillColor(gray: 1, alpha: 1)
        context.fill(card)
        if let background = style.background {
            // Sliced, so the parchment's torn edge stays a thin border however the card's shape stretches it.
            context.drawNineSlice(background, in: card, cap: 70, capPoints: 9)
        }
        if let frame = style.frame {
            context.drawNineSlice(frame, in: card.insetBy(dx: 2, dy: 2), cap: 40, capPoints: 8)
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
        let level = "ITEM \(item.level)"
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

    /// Draws the traits as chips in rows from `top` down; returns the bottom of the last row.
    private func drawTraits(below top: CGFloat, in inner: CGRect) -> CGFloat {
        var origin = CGPoint(x: inner.minX, y: top - Self.chipHeight)
        let font = ItemCardFonts.body(size: 5.5, emphasis: .bold)
        for trait in item.traits {
            let line = Self.line(trait.uppercased(), font: font, color: style.chipInk)
            let width = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil)) + 6
            if origin.x + width > inner.maxX, origin.x > inner.minX {
                origin = CGPoint(x: inner.minX, y: origin.y - Self.chipHeight - 2)
            }
            context.setFillColor(ItemCardStyle.rarityFill(trait) ?? style.chipFill)
            context.fill(CGRect(x: origin.x, y: origin.y, width: width, height: Self.chipHeight))
            draw(line, at: CGPoint(x: origin.x + 3, y: origin.y + 2.6))
            origin.x += width + 2
        }
        return item.traits.isEmpty ? top : origin.y
    }

    /// Draws the stats two to a row, a long one on a row of its own, from `bottom` up; returns the table's top.
    private func drawStats(above bottom: CGFloat, in inner: CGRect) -> CGFloat {
        let rows = Self.statRows(item.stats, width: inner.width) { stat in
            CGFloat(CTLineGetTypographicBounds(statLine(stat), nil, nil, nil))
        }
        let top = bottom + Self.statRowHeight * CGFloat(rows.count)
        for (index, row) in rows.enumerated() {
            let baseline = top - Self.statRowHeight * CGFloat(index + 1) + 2.5
            for (column, stat) in row.enumerated() {
                draw(statLine(stat), at: CGPoint(x: inner.minX + 1 + inner.width / 2 * CGFloat(column), y: baseline))
            }
        }
        if !rows.isEmpty {
            context.setStrokeColor(style.ruleColor)
            context.setLineWidth(0.5)
            context.stroke(CGRect(x: inner.minX, y: top + 2, width: inner.width, height: 0))
        }
        return top + 2
    }

    /// The stats in rows of two, in order, except that one too wide for half the width takes a whole row.
    static func statRows(_ stats: [ItemStat], width: CGFloat, measure: (ItemStat) -> CGFloat) -> [[ItemStat]] {
        var rows: [[ItemStat]] = []
        for stat in stats {
            let isWide = measure(stat) > width / 2 - 2
            if !isWide, let last = rows.last, last.count == 1, measure(last[0]) <= width / 2 - 2 {
                rows[rows.count - 1].append(stat)
            } else {
                rows.append([stat])
            }
        }
        return rows
    }

    private func drawSource(in rect: CGRect) {
        let line = Self.line(item.source, font: ItemCardFonts.body(size: 5.5, emphasis: .italic), color: style.ink)
        let width = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
        // Centered, clear of Starfinder's corner pieces.
        draw(line, at: CGPoint(x: rect.midX - width / 2, y: rect.minY + 1.5))
    }

    private func statLine(_ stat: ItemStat) -> CTLine {
        let text = NSMutableAttributedString(string: stat.label + " ", attributes: [
            .init(kCTFontAttributeName as String): ItemCardFonts.body(size: 6.5, emphasis: .bold),
            .init(kCTForegroundColorAttributeName as String): style.ink
        ])
        text.append(NSAttributedString(string: stat.value, attributes: [
            .init(kCTFontAttributeName as String): ItemCardFonts.body(size: 6.5, emphasis: .plain),
            .init(kCTForegroundColorAttributeName as String): style.ink
        ]))
        return CTLineCreateWithAttributedString(text)
    }

    // MARK: Lines

    private func draw(_ line: CTLine, at origin: CGPoint) {
        context.textMatrix = .identity
        context.textPosition = origin
        CTLineDraw(line, context)
    }

    private static func line(_ text: String, font: CTFont, color: CGColor) -> CTLine {
        CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [
            .init(kCTFontAttributeName as String): font, .init(kCTForegroundColorAttributeName as String): color
        ]))
    }

    private static func textWidth(_ text: String, font: CTFont) -> CGFloat {
        CGFloat(CTLineGetTypographicBounds(line(text, font: font, color: CGColor(gray: 0, alpha: 1)), nil, nil, nil))
    }
}
