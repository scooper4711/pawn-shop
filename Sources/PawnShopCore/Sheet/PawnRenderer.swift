import CoreGraphics
import CoreText
import Foundation
import ImageIO
import PDFKit

public enum PawnSide: Sendable {
    case front, back
}

/// Draws pawns from the library: single faces for thumbnails, and folded strips for printing. It keeps the
/// source PDFs, custom images and token pictures it has opened. It needs only the library's folders, so a
/// renderer can be made for a background thread; each renderer must stay on one thread.
public final class PawnRenderer {
    static let cutLineWidth: CGFloat = 0.3
    static let cutLineGray: CGFloat = 0.55
    static let foldDash: [CGFloat] = [3, 3]
    /// The share of a custom pawn's height given to its name.
    static let nameBandFraction: CGFloat = 0.13
    /// The share of the pawn's width a name may use.
    static let nameWidthFraction: CGFloat = 0.92

    let folders: LibraryFolders
    private var documents: [String: CGPDFDocument] = [:]
    private var images: [String: CGImage] = [:]
    /// The same PDFs opened with PDFKit, which knows where their text is.
    private var textDocuments: [String: PDFDocument] = [:]

    public init(folders: LibraryFolders) {
        self.folders = folders
    }

    public convenience init(library: PawnLibrary) {
        self.init(folders: library.folders)
    }

    /// The pawn's outline size, upright.
    public func uprightSize(of pawn: Pawn) -> CGSize {
        switch pawn.art {
        case .pdf(_, let front, _): front.uprightSize
        case .custom, .token: pawn.size.outlineSize
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
            context.setFillColor(gray: 1, alpha: 1)
            context.fill(rect)
            drawCustomImage(art, in: Self.artArea(for: art, named: pawn.name, in: rect), mirrored: side == .back,
                            context: context)
            // The name reads the right way round on both faces.
            if art.showsName { drawNameBand(pawn.name, in: rect, context: context) }
        case .token:
            drawToken(of: pawn, side: side, in: rect, context: context)
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
        bitmap(of: pawn, height: height) { context, rect in
            self.drawFace(of: pawn, side: side, in: rect, context: context)
        }
    }

    /// The front face with its printed words painted out, so a model describing it sees only the art, `height`
    /// pixels tall upright. Art printed on its side, as the words along it show, is turned to read level.
    public func artImage(of pawn: Pawn, height: Int) -> CGImage? {
        if case .token(let art) = pawn.art {
            return bitmap(of: pawn, height: height) { context, rect in
                self.drawTokenPicture(art, side: .front, in: Self.tokenCircle(in: rect), context: context)
            }
        }
        var artOnly = pawn
        if case .custom(var art) = pawn.art {
            art.showsName = false
            artOnly.art = .custom(art)
        }
        let image = bitmap(of: artOnly, height: height) { context, rect in
            self.drawFace(of: artOnly, side: .front, in: rect, context: context)
            self.paintOutText(of: artOnly, in: rect, context: context)
        }
        return image?.rotated(clockwiseQuarterTurns: levelingTurns(of: pawn))
    }

    /// The quarter turns clockwise that make the words printed on an upright PDF pawn's front read level.
    func levelingTurns(of pawn: Pawn) -> Int {
        guard case .pdf(let sourceID, let front, _) = pawn.art,
              let page = textDocument(sourceID)?.page(at: front.pageIndex)
        else { return 0 }
        let direction = NameDirection.readingDirection(on: page, inside: front.rect)
        let upright = front.transform(into: CGRect(origin: .zero, size: front.uprightSize))
        return NameDirection.clockwiseQuarterTurns(toLevel: direction.applying(upright))
    }

    private func bitmap(of pawn: Pawn, height: Int, draw: (CGContext, CGRect) -> Void) -> CGImage? {
        let size = uprightSize(of: pawn)
        let width = max(1, Int((CGFloat(height) * size.width / size.height).rounded()))
        guard height > 0, let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                                  bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.setFillColor(gray: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        draw(context, CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    /// Covers each line of text printed on a PDF pawn's front (its name, copyright and product badge) in white.
    private func paintOutText(of pawn: Pawn, in rect: CGRect, context: CGContext) {
        guard case .pdf(let sourceID, let front, _) = pawn.art,
              let page = textDocument(sourceID)?.page(at: front.pageIndex),
              let lines = page.selection(for: front.rect)?.selectionsByLine()
        else { return }
        context.saveGState()
        context.clip(to: rect)
        context.concatenate(front.transform(into: rect))
        context.setFillColor(gray: 1, alpha: 1)
        for line in lines {
            context.fill(line.bounds(for: page).insetBy(dx: -1, dy: -1))
        }
        context.restoreGState()
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
        if mirrored {
            context.translateBy(x: rect.midX * 2, y: 0)
            context.scaleBy(x: -1, y: 1)
        }
        if let image = image(folders.custom.appendingPathComponent(art.imageFile)) {
            context.interpolationQuality = .high
            context.draw(image, in: Self.artRect(for: CGSize(width: image.width, height: image.height),
                                                 in: rect, focus: art.focus, scaling: art.scaling))
        }
        context.restoreGState()
    }

    /// Where custom art may go: the whole face, or above the name when fitting the whole picture.
    public static func artArea(for art: CustomArt, named name: String, in rect: CGRect) -> CGRect {
        guard art.scaling == .fit, art.showsName else { return rect }
        return areaAboveName(name, in: rect)
    }

    /// The face above the band holding the name.
    public static func areaAboveName(_ name: String, in rect: CGRect) -> CGRect {
        let band = nameBandHeight(for: name, in: rect)
        return CGRect(x: rect.minX, y: rect.minY + band, width: rect.width, height: rect.height - band)
    }

    /// The image scaled to cover `rect` (fill) or to fit inside it (fit), placed by `focus` (0…1 on each axis)
    /// within the room it has to move: its overflow, or the free space.
    public static func artRect(for imageSize: CGSize, in rect: CGRect, focus: CGPoint,
                               scaling: ArtScaling) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return rect }
        let widthScale = rect.width / imageSize.width, heightScale = rect.height / imageSize.height
        let scale = scaling == .fill ? max(widthScale, heightScale) : min(widthScale, heightScale)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let clamped = CGPoint(x: min(max(focus.x, 0), 1), y: min(max(focus.y, 0), 1))
        return CGRect(x: rect.minX - (size.width - rect.width) * clamped.x,
                      y: rect.minY - (size.height - rect.height) * clamped.y, width: size.width, height: size.height)
    }

    /// The name across the foot on a white band: one line if it fits, else two at the same size (the band
    /// grows to hold them), and only then smaller type.
    func drawNameBand(_ name: String, in rect: CGRect, context: CGContext) {
        let layout = Self.nameLayout(for: name, in: rect)
        let leading = layout.fontSize * 1.15
        let block = leading * CGFloat(layout.lines.count)
        let height = Self.nameBandHeight(for: name, in: rect)
        context.setFillColor(gray: 1, alpha: 0.85)
        context.fill(CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: height))
        // Lines are centered in the band as a block; each baseline sits 80% of the leading below its top.
        let blockTop = rect.minY + (height + block) / 2
        for (index, text) in layout.lines.enumerated() {
            let baseline = blockTop - leading * (CGFloat(index) + 0.8)
            drawLine(text, size: layout.fontSize, at: CGPoint(x: rect.midX, y: baseline), context: context)
        }
    }

    /// The height of the band holding the name: one line's worth, or more when the name wraps.
    public static func nameBandHeight(for name: String, in rect: CGRect) -> CGFloat {
        let lineHeight = rect.height * nameBandFraction
        let layout = nameLayout(for: name, in: rect)
        return max(lineHeight, layout.fontSize * 1.15 * CGFloat(layout.lines.count) + lineHeight * 0.3)
    }

    public static func nameLayout(for name: String, in rect: CGRect) -> NameLayout {
        NameLayout.fit(name.uppercased(), width: rect.width * nameWidthFraction,
                       fontSize: rect.height * nameBandFraction * 0.6)
    }

    func drawPlaceholder(in rect: CGRect, context: CGContext) {
        context.setFillColor(gray: 0.9, alpha: 1)
        context.fill(rect)
        let size = NameLayout.fit("Missing pawn", width: rect.width * Self.nameWidthFraction,
                                  fontSize: min(10, rect.width / 8)).fontSize
        drawLine("Missing pawn", size: size, at: CGPoint(x: rect.midX, y: rect.midY - size * 0.35), context: context)
    }

    /// One line of text centered on `anchor.x`, with its baseline at `anchor.y`.
    private func drawLine(_ text: String, size: CGFloat, at anchor: CGPoint, context: CGContext) {
        let width = NameLayout.textWidth(text, size: size)
        context.textMatrix = .identity
        context.textPosition = CGPoint(x: anchor.x - width / 2, y: anchor.y)
        CTLineDraw(NameLayout.line(text, size: size), context)
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
        let document = CGPDFDocument(folders.sourceFile(id: sourceID) as CFURL)
        documents[sourceID] = document
        return document
    }

    private func textDocument(_ sourceID: String) -> PDFDocument? {
        if let document = textDocuments[sourceID] { return document }
        let document = PDFDocument(url: folders.sourceFile(id: sourceID))
        textDocuments[sourceID] = document
        return document
    }

    func image(_ url: URL) -> CGImage? {
        if let image = images[url.path] { return image }
        let image = CGImageSourceCreateWithURL(url as CFURL, nil)
            .flatMap { CGImageSourceCreateImageAtIndex($0, 0, nil) }
        images[url.path] = image
        return image
    }
}
