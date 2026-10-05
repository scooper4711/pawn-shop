import CoreGraphics
import CoreText
import Foundation
@testable import PawnShopCore

/// Letter paper, in points.
let letterPage = CGSize(width: 612, height: 792)

/// A PDF with one page per drawing closure.
func makePDF(size: CGSize = letterPage, pages: [(CGContext) -> Void]) -> Data {
    let data = NSMutableData()
    var mediaBox = CGRect(origin: .zero, size: size)
    let consumer = CGDataConsumer(data: data as CFMutableData)!
    let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)!
    for draw in pages {
        context.beginPDFPage(nil)
        draw(context)
        context.endPDFPage()
    }
    context.closePDF()
    return data as Data
}

func document(_ data: Data) -> CGPDFDocument {
    CGPDFDocument(CGDataProvider(data: data as CFData)!)!
}

/// A pawn outline: a rectangle whose two corners at `head` are rounded, as Paizo draws them.
func outlinePath(_ rect: CGRect, head: Edge = .top, radius: CGFloat = 26) -> CGPath {
    let upright = head == .top || head == .bottom ? rect.size : CGSize(width: rect.height, height: rect.width)
    let path = CGMutablePath()
    path.move(to: CGPoint(x: 0, y: 0))
    path.addLine(to: CGPoint(x: 0, y: upright.height - radius))
    path.addQuadCurve(to: CGPoint(x: radius, y: upright.height), control: CGPoint(x: 0, y: upright.height))
    path.addLine(to: CGPoint(x: upright.width - radius, y: upright.height))
    path.addQuadCurve(to: CGPoint(x: upright.width, y: upright.height - radius),
                      control: CGPoint(x: upright.width, y: upright.height))
    path.addLine(to: CGPoint(x: upright.width, y: 0))
    path.closeSubpath()
    let turn = CGAffineTransform(rotationAngle: -CGFloat(Outline(rect: rect, headEdge: head).uprightRotation)
                                    * .pi / 180)
    let turned = path.copy(using: [turn])!
    let bounds = turned.boundingBoxOfPath
    var move = CGAffineTransform(translationX: rect.minX - bounds.minX, y: rect.minY - bounds.minY)
    return turned.copy(using: &move)!
}

func strokeOutline(_ context: CGContext, _ rect: CGRect, head: Edge = .top) {
    context.setStrokeColor(CGColor(srgbRed: 0.93, green: 0.11, blue: 0.14, alpha: 1))
    context.setLineWidth(0.3)
    context.addPath(outlinePath(rect, head: head))
    context.strokePath()
}

/// Draws `text` with its baseline starting at `origin`, so PDFKit can read it back.
func drawText(_ context: CGContext, _ text: String, at origin: CGPoint, size: CGFloat = 7) {
    let font = CTFontCreateWithName("Helvetica-Bold" as CFString, size, nil)
    let line = CTLineCreateWithAttributedString(
        NSAttributedString(string: text, attributes: [.init(kCTFontAttributeName as String): font]))
    context.textPosition = origin
    CTLineDraw(line, context)
}

/// A PDF written by hand around `content`, for operators CGContext never emits (such as `v` and `y`).
func rawPDF(content: String, size: CGSize = letterPage) -> CGPDFDocument {
    let objects = [
        "<< /Type /Catalog /Pages 2 0 R >>",
        "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
        "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 \(Int(size.width)) \(Int(size.height))] /Contents 4 0 R >>",
        "<< /Length \(content.utf8.count) >>\nstream\n\(content)\nendstream",
    ]
    var pdf = "%PDF-1.4\n"
    var offsets: [Int] = []
    for (index, object) in objects.enumerated() {
        offsets.append(pdf.utf8.count)
        pdf += "\(index + 1) 0 obj\n\(object)\nendobj\n"
    }
    let xref = pdf.utf8.count
    pdf += "xref\n0 \(objects.count + 1)\n0000000000 65535 f \n"
    pdf += offsets.map { String(format: "%010d 00000 n \n", $0) }.joined()
    pdf += "trailer\n<< /Size \(objects.count + 1) /Root 1 0 R >>\nstartxref\n\(xref)\n%%EOF\n"
    return document(Data(pdf.utf8))
}

/// Copies `pages` of `source` into a new PDF, which wraps each one in a form XObject.
func wrappedInForms(_ source: CGPDFDocument) -> Data {
    let pages = (1...source.numberOfPages).compactMap { source.page(at: $0) }
    return makePDF(pages: pages.map { page in { context in context.drawPDFPage(page) } })
}
