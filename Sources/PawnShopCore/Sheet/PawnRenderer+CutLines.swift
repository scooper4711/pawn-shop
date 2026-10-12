import CoreGraphics

/// The hairline gray outline strips and cards are cut along, and a strip's dashed fold line.
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
}
