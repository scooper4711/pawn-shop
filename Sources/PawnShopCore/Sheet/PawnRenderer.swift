import CoreGraphics
import CoreText
import Foundation
import ImageIO

public enum PawnSide: Sendable {
    case front, back
}

/// Draws pawns from the library: single faces for thumbnails, and folded strips for printing.
/// It keeps the source PDFs and custom images it has opened.
public final class PawnRenderer {
    static let cutLineWidth: CGFloat = 0.3
    static let cutLineGray: CGFloat = 0.55
    static let foldDash: [CGFloat] = [3, 3]
    /// The share of a custom pawn's height given to its name.
    static let nameBandFraction: CGFloat = 0.13

    private let library: PawnLibrary
    private var documents: [String: CGPDFDocument] = [:]
    private var images: [String: CGImage] = [:]

    public init(library: PawnLibrary) {
        self.library = library
    }

    /// The pawn's outline size, upright.
    public func uprightSize(of pawn: Pawn) -> CGSize {
        switch pawn.art {
        case .pdf(_, let front, _): front.uprightSize
        case .custom: pawn.size.outlineSize
        }
    }

    /// Draws one face of a pawn upright, filling `rect`.
    public func drawFace(of pawn: Pawn, side: PawnSide, in rect: CGRect, context: CGContext) {
        context.saveGState()
        context.clip(to: rect)
        switch pawn.art {
        case .pdf(let sourceID, let front, let back):
            drawPDFFace(side == .front ? front : back, sourceID: sourceID, in: rect, context: context)
        case .custom(let art):
            drawCustomImage(art, in: rect, mirrored: side == .back, context: context)
            // The name reads the right way round on both faces.
            if art.showsName { drawNameBand(pawn.name, in: rect, context: context) }
        }
        context.restoreGState()
    }

    /// Draws a folded strip where `placed` says: the front below the fold, the back above it turned 180°.
    /// A missing pawn is drawn as a gray placeholder.
    public func drawStrip(_ pawn: Pawn?, in placed: PlacedStrip, settings: SheetSettings, context: CGContext) {
        let upright = placed.sideways ? CGSize(width: placed.rect.height, height: placed.rect.width) : placed.rect.size
        let half = CGRect(x: 0, y: 0, width: upright.width, height: upright.height / 2)
        context.saveGState()
        context.concatenate(Self.stripTransform(for: placed))
        if let pawn {
            drawFace(of: pawn, side: .front, in: half, context: context)
            context.saveGState()
            context.translateBy(x: upright.width, y: upright.height)
            context.rotate(by: .pi)
            drawFace(of: pawn, side: .back, in: half, context: context)
            context.restoreGState()
        } else {
            drawPlaceholder(in: CGRect(origin: .zero, size: upright), context: context)
        }
        drawCutMarks(stripSize: upright, settings: settings, context: context)
        context.restoreGState()
    }

    /// A bitmap of one face, `height` pixels tall; nil when the art can't be drawn.
    public func thumbnail(of pawn: Pawn, side: PawnSide = .front, height: Int) -> CGImage? {
        let size = uprightSize(of: pawn)
        let width = max(1, Int((CGFloat(height) * size.width / size.height).rounded()))
        guard height > 0, let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                                  bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.setFillColor(gray: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        drawFace(of: pawn, side: side, in: CGRect(x: 0, y: 0, width: width, height: height), context: context)
        return context.makeImage()
    }

    /// Maps the upright strip (origin at its foot's left corner) onto its place on the page.
    static func stripTransform(for placed: PlacedStrip) -> CGAffineTransform {
        guard placed.sideways else { return CGAffineTransform(translationX: placed.rect.minX, y: placed.rect.minY) }
        // Turned a quarter clockwise: the foot goes to the left, the fold to the right.
        return CGAffineTransform(rotationAngle: -.pi / 2)
            .concatenating(CGAffineTransform(translationX: placed.rect.minX, y: placed.rect.maxY))
    }

    // MARK: Faces

    private func drawPDFFace(_ face: PawnFace, sourceID: String, in rect: CGRect, context: CGContext) {
        guard let page = document(sourceID)?.page(at: face.pageIndex + 1) else {
            drawPlaceholder(in: rect, context: context)
            return
        }
        context.concatenate(face.transform(into: rect))
        context.drawPDFPage(page)
    }

    private func drawCustomImage(_ art: CustomArt, in rect: CGRect, mirrored: Bool, context: CGContext) {
        context.saveGState()
        context.setFillColor(gray: 1, alpha: 1)
        context.fill(rect)
        if mirrored {
            context.translateBy(x: rect.midX * 2, y: 0)
            context.scaleBy(x: -1, y: 1)
        }
        if let image = image(art.imageFile) {
            context.interpolationQuality = .high
            context.draw(image, in: Self.fillRect(for: CGSize(width: image.width, height: image.height),
                                                  in: rect, focus: art.focus))
        }
        context.restoreGState()
    }

    /// The image scaled to cover `rect`, its overflow split according to `focus` (0…1 on each axis).
    static func fillRect(for imageSize: CGSize, in rect: CGRect, focus: CGPoint) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return rect }
        let scale = max(rect.width / imageSize.width, rect.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let clamped = CGPoint(x: min(max(focus.x, 0), 1), y: min(max(focus.y, 0), 1))
        return CGRect(x: rect.minX - (size.width - rect.width) * clamped.x,
                      y: rect.minY - (size.height - rect.height) * clamped.y, width: size.width, height: size.height)
    }

    private func drawNameBand(_ name: String, in rect: CGRect, context: CGContext) {
        let band = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height * Self.nameBandFraction)
        context.setFillColor(gray: 1, alpha: 0.85)
        context.fill(band)
        drawCenteredText(name.uppercased(), in: band, maximumSize: band.height * 0.6, context: context)
    }

    private func drawPlaceholder(in rect: CGRect, context: CGContext) {
        context.setFillColor(gray: 0.9, alpha: 1)
        context.fill(rect)
        drawCenteredText("Missing pawn", in: rect, maximumSize: min(10, rect.width / 8), context: context)
    }

    private func drawCenteredText(_ text: String, in rect: CGRect, maximumSize: CGFloat, context: CGContext) {
        var size = maximumSize
        var line = Self.line(text, size: size)
        while CTLineGetTypographicBounds(line, nil, nil, nil) > Double(rect.width * 0.92), size > 3 {
            size -= 0.5
            line = Self.line(text, size: size)
        }
        let width = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
        context.textMatrix = .identity
        context.textPosition = CGPoint(x: rect.midX - width / 2, y: rect.midY - size * 0.35)
        CTLineDraw(line, context)
    }

    private static func line(_ text: String, size: CGFloat) -> CTLine {
        let font = CTFontCreateUIFontForLanguage(.emphasizedSystem, size, nil)
            ?? CTFontCreateWithName("Helvetica-Bold" as CFString, size, nil)
        let attributes: [NSAttributedString.Key: Any] = [.init(kCTFontAttributeName as String): font,
                                                         .init(kCTForegroundColorAttributeName as String):
                                                            CGColor(gray: 0, alpha: 1)]
        return CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
    }

    // MARK: Cut marks

    private func drawCutMarks(stripSize: CGSize, settings: SheetSettings, context: CGContext) {
        context.setStrokeColor(gray: Self.cutLineGray, alpha: 1)
        context.setLineWidth(Self.cutLineWidth)
        context.stroke(CGRect(origin: .zero, size: stripSize))
        guard settings.showsFoldLine else { return }
        context.setLineDash(phase: 0, lengths: Self.foldDash)
        context.move(to: CGPoint(x: 0, y: stripSize.height / 2))
        context.addLine(to: CGPoint(x: stripSize.width, y: stripSize.height / 2))
        context.strokePath()
        context.setLineDash(phase: 0, lengths: [])
    }

    // MARK: Sources

    private func document(_ sourceID: String) -> CGPDFDocument? {
        if let document = documents[sourceID] { return document }
        let document = CGPDFDocument(library.fileURL(forSource: sourceID) as CFURL)
        documents[sourceID] = document
        return document
    }

    private func image(_ file: String) -> CGImage? {
        if let image = images[file] { return image }
        let url = library.customFolder.appendingPathComponent(file)
        let image = CGImageSourceCreateWithURL(url as CFURL, nil)
            .flatMap { CGImageSourceCreateImageAtIndex($0, 0, nil) }
        images[file] = image
        return image
    }
}
