import CoreGraphics
import CoreText
import Foundation

/// Where the parts of an item's cards go, in card points (origin at the bottom left), shared by the painter and
/// by `ItemCardLayout`, which needs the text's area before anything is drawn.
struct ItemCardGeometry {
    /// Clears the frame and the parchment's torn edge.
    static let inset: CGFloat = 13
    static let titleHeight: CGFloat = 24
    static let chipHeight: CGFloat = 9
    static let chipFontSize: CGFloat = 5.5
    static let statRowHeight: CGFloat = 9.5
    static let statFontSize: CGFloat = 6.5
    static let sourceHeight: CGFloat = 8

    let item: CatalogItem
    /// The action icons' font, which stats such as Cast ◆◆ are measured with.
    var actionFont: CTFontDescriptor?
    let card = CGRect(origin: .zero, size: ItemCard.size)

    init(item: CatalogItem, actionFont: CTFontDescriptor? = nil) {
        self.item = item
        self.actionFont = actionFont
    }

    var inner: CGRect { card.insetBy(dx: Self.inset, dy: Self.inset) }

    var title: CGRect {
        CGRect(x: inner.minX, y: inner.maxY - Self.titleHeight, width: inner.width, height: Self.titleHeight)
    }

    var source: CGRect { CGRect(x: inner.minX, y: inner.minY, width: inner.width, height: Self.sourceHeight) }

    /// Each trait's chip on the first card, in rows from under the title.
    var chips: [(trait: String, rect: CGRect)] {
        var origin = CGPoint(x: inner.minX, y: title.minY - 3 - Self.chipHeight)
        return item.traits.map { trait in
            let width = Self.textWidth(trait.uppercased(), font: ItemCardFonts.body(size: Self.chipFontSize,
                                                                                    emphasis: .bold)) + 6
            if origin.x + width > inner.maxX, origin.x > inner.minX {
                origin = CGPoint(x: inner.minX, y: origin.y - Self.chipHeight - 2)
            }
            defer { origin.x += width + 2 }
            return (trait, CGRect(x: origin.x, y: origin.y, width: width, height: Self.chipHeight))
        }
    }

    /// The bottom of the traits, or of the space under the title when there are none.
    var chipsBottom: CGFloat { chips.last?.rect.minY ?? title.minY - 3 }

    /// The stats in rows of two, a wide one alone.
    var statRows: [[ItemStat]] {
        Self.statRows(item.stats, width: inner.width) { stat in
            CGFloat(CTLineGetTypographicBounds(Self.statLine(stat, ink: CGColor(gray: 0, alpha: 1),
                                                             actionFont: actionFont), nil, nil, nil))
        }
    }

    /// The stats' area on the first card: under the traits for a spell, as the books print it, else above the
    /// source. Its rule is drawn 2 points outside it, on the text's side.
    var statsRect: CGRect {
        let height = Self.statRowHeight * CGFloat(statRows.count)
        let bottom = item.kind.isSpell ? chipsBottom - 3 - height : source.maxY + 2
        return CGRect(x: inner.minX, y: bottom, width: inner.width, height: height)
    }

    /// The text's area: on the first card between the traits and stats and the source, on the cards after it
    /// between the title and the source.
    func textRect(isFirstCard: Bool) -> CGRect {
        guard isFirstCard else {
            return CGRect(x: inner.minX + 1, y: source.maxY + 4, width: inner.width - 2,
                          height: title.minY - 4 - (source.maxY + 4))
        }
        let hasStats = !item.stats.isEmpty
        let top = item.kind.isSpell && hasStats ? statsRect.minY - 6 : chipsBottom - 4
        let bottom = !item.kind.isSpell && hasStats ? statsRect.maxY + 6 : source.maxY + 4
        return CGRect(x: inner.minX + 1, y: bottom, width: inner.width - 2, height: top - bottom)
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

    /// A stat's label in bold and its value, with action glyphs as icons, as one line in `ink`.
    static func statLine(_ stat: ItemStat, ink: CGColor, actionFont: CTFontDescriptor?) -> CTLine {
        let markup = "**\(stat.label)** " + stat.value.replacingOccurrences(of: "*", with: "")
        let text = ItemCardText(markup: markup, ink: ink, actionFont: actionFont).attributed(size: statFontSize)
        return CTLineCreateWithAttributedString(text)
    }

    static func line(_ text: String, font: CTFont, color: CGColor) -> CTLine {
        CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [
            .init(kCTFontAttributeName as String): font, .init(kCTForegroundColorAttributeName as String): color
        ]))
    }

    static func textWidth(_ text: String, font: CTFont) -> CGFloat {
        CGFloat(CTLineGetTypographicBounds(line(text, font: font, color: CGColor(gray: 0, alpha: 1)), nil, nil, nil))
    }
}
