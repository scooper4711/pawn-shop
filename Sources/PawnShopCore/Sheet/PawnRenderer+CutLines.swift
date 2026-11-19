import CoreGraphics

/// The hairline gray outline strips and cards are cut along, a strip's dashed fold line, and where a strip goes on
/// its page.
extension PawnRenderer {
    func drawCutMarks(stripSize: CGSize, settings: SheetSettings, context: CGContext) {
        drawCutOutline(CGRect(origin: .zero, size: stripSize), context: context)
        guard settings.showsFoldLine else { return }
        context.setLineDash(phase: 0, lengths: Self.foldDash)
        context.move(to: CGPoint(x: 0, y: stripSize.height / 2))
        context.addLine(to: CGPoint(x: stripSize.width, y: stripSize.height / 2))
        context.strokePath()
        context.setLineDash(phase: 0, lengths: [])
    }

    func drawCutOutline(_ rect: CGRect, context: CGContext) {
        context.setStrokeColor(gray: Self.cutLineGray, alpha: 1)
        context.setLineWidth(Self.cutLineWidth)
        context.stroke(rect)
    }

    /// Maps the upright strip (origin at its foot's left corner) onto its place on the page.
    static func stripTransform(for placed: PlacedStrip) -> CGAffineTransform {
        guard placed.sideways else { return CGAffineTransform(translationX: placed.rect.minX, y: placed.rect.minY) }
        // Turned a quarter clockwise: the foot goes to the left, the fold to the right.
        return CGAffineTransform(rotationAngle: -.pi / 2)
            .concatenating(CGAffineTransform(translationX: placed.rect.minX, y: placed.rect.maxY))
    }
}
