import CoreGraphics
import CoreText
import Foundation
import ImageIO

/// How an item card looks in its game: the Rexard pieces it is drawn with (`Generated/CardArt`), its colors and
/// the action icon font (`Generated/Fonts`).
/// Pathfinder cards are parchment in a wooden frame under a ribbon; Starfinder cards a dark panel with cyan
/// corners under a cyan bar. Without the pieces, a card is white with a gray frame.
struct ItemCardStyle {
    var background: CGImage?
    var frame: CGImage?
    var corners: [CGImage] = []
    var titleBand: CGImage?
    /// The part of `titleBand` the title sits on, as fractions of the image from its top left: the flat face of a
    /// ribbon whose folded ends hang outside it. Nil when the whole image is the band, stretched to fit.
    var titleFace: CGRect?
    /// The body text's color.
    var ink: CGColor
    /// The title's and the stats labels' color.
    var titleInk: CGColor
    var titleFill: CGColor
    var chipFill: CGColor
    var chipInk: CGColor
    var ruleColor: CGColor
    var actionFont: CTFontDescriptor?

    /// The style of `game`'s cards, from the files `make items` writes to `generated`; plain when it is nil or
    /// lacks the pieces.
    static func style(for game: Game, generated: URL?) -> ItemCardStyle {
        var style = pieces(for: game, in: generated?.appendingPathComponent("CardArt"))
        style.actionFont = ItemCardFonts.actions(in: generated)
        return style
    }

    private static func pieces(for game: Game, in folder: URL?) -> ItemCardStyle {
        let piece = { (name: String) in folder.flatMap { image(at: $0.appendingPathComponent(name + ".png")) } }
        switch game {
        case .pathfinder:
            guard let parchment = piece("parchment") else { return .plain }
            var style = ItemCardStyle.pathfinder
            style.background = parchment
            style.frame = piece("front-frame")
            style.titleBand = piece("name-ribbon")
            // Measured on Fantasy GUI's text_bg_03: the folds take the ends and the lower half.
            style.titleFace = CGRect(x: 0.147, y: 0, width: 0.698, height: 0.547)
            return style
        case .starfinder:
            guard let panel = piece("panel") else { return .plain }
            var style = ItemCardStyle.starfinder
            style.background = panel
            style.corners = ["corner-top-left", "corner-top-right", "corner-bottom-left", "corner-bottom-right"]
                .compactMap(piece)
            style.titleBand = piece("name-bar")
            return style
        }
    }

    static var plain: ItemCardStyle { ItemCardStyle(ink: gray(0.1), titleInk: gray(0), titleFill: gray(0.88),
                                     chipFill: color(0.37, 0, 0), chipInk: gray(1), ruleColor: gray(0.5)) }
    static var pathfinder: ItemCardStyle { ItemCardStyle(ink: color(0.17, 0.11, 0.05),
                                                         titleInk: color(0.17, 0.11, 0.05),
                                          titleFill: color(0.87, 0.78, 0.6), chipFill: color(0.37, 0, 0),
                                          chipInk: gray(1), ruleColor: color(0.45, 0.3, 0.15)) }
    static var starfinder: ItemCardStyle { ItemCardStyle(ink: color(0.9, 0.95, 0.97), titleInk: color(0.02, 0.1, 0.14),
                                          titleFill: color(0.3, 0.8, 0.9), chipFill: color(0.3, 0.8, 0.9),
                                          chipInk: color(0.02, 0.1, 0.14), ruleColor: color(0.3, 0.8, 0.9)) }

    /// A rarity's own chip color, as the books print it; nil for traits.
    static func rarityFill(_ trait: String) -> CGColor? {
        switch trait {
        case "Uncommon": color(0.6, 0.32, 0.24)
        case "Rare": color(0, 0.15, 0.39)
        case "Unique": color(0.33, 0.09, 0.43)
        default: nil
        }
    }

    private static func image(at url: URL) -> CGImage? {
        CGImageSourceCreateWithURL(url as CFURL, nil).flatMap { CGImageSourceCreateImageAtIndex($0, 0, nil) }
    }

    private static func gray(_ white: CGFloat) -> CGColor { CGColor(gray: white, alpha: 1) }

    private static func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> CGColor {
        CGColor(srgbRed: red, green: green, blue: blue, alpha: 1)
    }
}

extension CGContext {
    /// Draws `image` stretched over `rect` but with its corners kept square: `cap` pixels of each edge of the
    /// image become `capPoints` of the rect.
    func drawNineSlice(_ image: CGImage, in rect: CGRect, cap: Int, capPoints: CGFloat) {
        let width = image.width, height = image.height
        let sourceColumns = [0, cap, width - cap, width], sourceRows = [0, cap, height - cap, height]
        let columns = [rect.minX, rect.minX + capPoints, rect.maxX - capPoints, rect.maxX]
        // Image rows run top down; the rect's run bottom up.
        let rows = [rect.maxY, rect.maxY - capPoints, rect.minY + capPoints, rect.minY]
        for row in 0..<3 {
            for column in 0..<3 {
                let source = CGRect(x: sourceColumns[column], y: sourceRows[row],
                                    width: sourceColumns[column + 1] - sourceColumns[column],
                                    height: sourceRows[row + 1] - sourceRows[row])
                let target = CGRect(x: columns[column], y: rows[row + 1], width: columns[column + 1] - columns[column],
                                    height: rows[row] - rows[row + 1])
                if let piece = image.cropping(to: source) { draw(piece, in: target) }
            }
        }
    }
}
