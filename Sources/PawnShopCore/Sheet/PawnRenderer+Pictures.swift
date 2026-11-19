import CoreGraphics
import Foundation

/// Drawing pawns from the picture saved with their art, for art whose PDF this device can't reach (R2.1.2, R10.3).
extension PawnRenderer {
    /// What a face says while its picture isn't on the device: it downloads when the pawn is shown (R10.4).
    public static let missingPicture = "Picture not here yet"

    /// The art's figure as large as fits above the name, standing on it, on white, as a Battle Card's creature is.
    func drawPicture(of pawn: Pawn, side: PawnSide, in rect: CGRect, context: CGContext) {
        guard case .picture(let art) = pawn.art else { return }
        context.setFillColor(gray: 1, alpha: 1)
        context.fill(rect)
        drawSavedPicture(art, in: Self.areaAboveName(pawn.name, in: rect), mirrored: side == .back, context: context)
        drawNameBand(pawn.name, in: rect, context: context)
    }

    /// The saved picture as large as fits in `area`, centered across it and standing on its foot; a placeholder
    /// while the device doesn't have its file.
    func drawSavedPicture(_ art: PictureArt, in area: CGRect, mirrored: Bool, context: CGContext) {
        guard !art.picture.isEmpty, let image = image(folders.pictures.appendingPathComponent(art.picture)) else {
            drawPlaceholder(in: area, label: Self.missingPicture, context: context)
            return
        }
        let size = CGSize(width: image.width, height: image.height)
        let placed = Self.artRect(for: size, in: area, focus: CGPoint(x: 0.5, y: 0), scaling: .fit)
        context.saveGState()
        if mirrored {
            context.translateBy(x: area.midX * 2, y: 0)
            context.scaleBy(x: -1, y: 1)
        }
        context.interpolationQuality = .high
        context.draw(image, in: placed)
        context.restoreGState()
    }
}
