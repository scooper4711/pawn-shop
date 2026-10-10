import CoreGraphics
import Foundation

/// Drawing pawns made from Battle Cards, and pawns printed without cut outlines, drawn alone the same way.
extension PawnRenderer {
    /// The creature as large as fits above the name, standing on it, on white.
    func drawCard(of pawn: Pawn, side: PawnSide, in rect: CGRect, context: CGContext) {
        guard case .card(let art) = pawn.art else { return }
        context.setFillColor(gray: 1, alpha: 1)
        context.fill(rect)
        drawCardFigure(art, in: Self.areaAboveName(pawn.name, in: rect), mirrored: side == .back, context: context)
        drawNameBand(pawn.name, in: rect, context: context)
    }

    /// A token's or card's picture alone, without the name, `height` pixels tall; nil for other pawns.
    func pictureAlone(of pawn: Pawn, height: Int) -> CGImage? {
        switch pawn.art {
        case .token(let art):
            bitmap(of: pawn, height: height) { context, rect in
                self.drawTokenPicture(art, side: .front, in: Self.tokenCircle(in: rect), context: context)
            }
        case .card(let art):
            bitmap(of: pawn, height: height) { context, rect in
                self.drawCardFigure(art, in: rect, mirrored: false, context: context)
            }
        case .pdf, .custom:
            nil
        }
    }

    /// The creature as large as fits in `area`, centered across it and standing on its foot, turned upright when
    /// its page prints it sideways.
    func drawCardFigure(_ art: CardArt, in area: CGRect, mirrored: Bool, context: CGContext) {
        guard let figure = figures.figure(of: art) else {
            drawPlaceholder(in: area, context: context)
            return
        }
        let placed = Self.artRect(for: art.face.uprightSize, in: area, focus: CGPoint(x: 0.5, y: 0), scaling: .fit)
        figure.draw(in: placed, mirrored: mirrored, rotation: art.face.rotation, context: context)
    }
}
