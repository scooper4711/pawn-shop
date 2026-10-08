import CoreGraphics
import Foundation

/// Drawing pawns made from round tokens.
extension PawnRenderer {
    /// The token's art, as large as fits above the name, on white.
    func drawToken(of pawn: Pawn, side: PawnSide, in rect: CGRect, context: CGContext) {
        guard case .token(let art) = pawn.art else { return }
        context.setFillColor(gray: 1, alpha: 1)
        context.fill(rect)
        drawTokenPicture(art, side: side, in: Self.tokenCircle(in: Self.areaAboveName(pawn.name, in: rect)),
                         context: context)
        drawNameBand(pawn.name, in: rect, context: context)
    }

    /// The token's picture cut round in `square`; the back is the front mirrored when the token has no back
    /// picture.
    func drawTokenPicture(_ art: TokenArt, side: PawnSide, in square: CGRect, context: CGContext) {
        let file = side == .back ? art.backPicture ?? art.frontPicture : art.frontPicture
        guard let image = image(folders.tokens.appendingPathComponent(file)) else {
            drawPlaceholder(in: square, context: context)
            return
        }
        context.saveGState()
        context.addEllipse(in: square)
        context.clip()
        if side == .back, art.backPicture == nil {
            context.translateBy(x: square.midX * 2, y: 0)
            context.scaleBy(x: -1, y: 1)
        }
        context.interpolationQuality = .high
        context.draw(image, in: square)
        context.restoreGState()
    }

    /// The square holding the largest circle that fits in `area`, centered in it.
    public static func tokenCircle(in area: CGRect) -> CGRect {
        let diameter = min(area.width, area.height)
        return CGRect(x: area.midX - diameter / 2, y: area.midY - diameter / 2, width: diameter, height: diameter)
    }
}
