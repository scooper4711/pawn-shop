import CoreGraphics
import CoreText
import Foundation
import ImageIO
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
        "<< /Length \(content.utf8.count) >>\nstream\n\(content)\nendstream"
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

/// A test picture: a diagonal gradient, turned by `variant` quarter turns so variants look different.
func artImage(variant: Int = 0, width: Int = 60, height: Int = 90) -> CGImage {
    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    let colors = [CGColor(srgbRed: 0.1, green: 0.2, blue: 0.6, alpha: 1),
                  CGColor(srgbRed: 0.9, green: 0.8, blue: 0.2, alpha: 1)]
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: nil)!
    let corners = [CGPoint(x: 0, y: 0), CGPoint(x: width, y: 0),
                   CGPoint(x: width, y: height), CGPoint(x: 0, y: height)]
    context.drawLinearGradient(gradient, start: corners[variant % 4], end: corners[(variant + 2) % 4], options: [])
    context.setFillColor(CGColor(gray: 0, alpha: 1))
    context.fillEllipse(in: CGRect(x: width / 4 + variant * 3, y: height / 2, width: width / 3, height: height / 4))
    return context.makeImage()!
}

/// `image` re-encoded as JPEG, so a PDF embeds it with DCT compression.
func jpegImage(_ image: CGImage, quality: Double = 0.9) -> CGImage {
    let data = NSMutableData()
    let destination = CGImageDestinationCreateWithData(data, "public.jpeg" as CFString, 1, nil)!
    let options = [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
    CGImageDestinationAddImage(destination, image, options)
    CGImageDestinationFinalize(destination)
    return CGImage(jpegDataProviderSource: CGDataProvider(data: data)!, decode: nil, shouldInterpolate: true,
                   intent: .defaultIntent)!
}
