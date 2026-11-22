import CoreGraphics
import Foundation
import PawnShopCore
import SheetPreviewFile

/// What a sheet page shows, ready to draw on another thread.
struct PageDrawing: Sendable {
    let strips: [PlacedStrip]
    /// What each strip shows (`SheetExporter.contents(of:)`).
    let contents: [PlacedContent]
    let settings: SheetSettings
}

/// Renders pawn thumbnails and sheet pages on a background queue, keeping thumbnails in memory.
final class BackgroundRenderer: @unchecked Sendable {
    /// Thumbnail height in pixels: enough for a sharp tile on a Retina display.
    static let thumbnailHeight = 240
    /// How much the thumbnail cache keeps, in bytes.
    static let keptThumbnailBytes = 150 << 20

    private let queue = DispatchQueue(label: "PawnShop.rendering", qos: .userInitiated)
    private let thumbnails = NSCache<NSString, CGImage>()
    private let folders: LibraryFolders
    /// Created on `queue` and used only there.
    private var renderer: PawnRenderer?

    init(folders: LibraryFolders) {
        self.folders = folders
        // About 1,000 pawn tiles or 500 card tiles; the system empties it sooner when memory runs short.
        thumbnails.totalCostLimit = Self.keptThumbnailBytes
    }

    /// The thumbnail if it is ready.
    func cachedThumbnail(of pawn: Pawn, side: PawnSide = .front, height: Int = thumbnailHeight) -> CGImage? {
        thumbnails.object(forKey: key(pawn, side, height))
    }

    /// The thumbnail, rendering it first if needed.
    func thumbnail(of pawn: Pawn, side: PawnSide = .front, height: Int = thumbnailHeight) async -> CGImage? {
        if let image = cachedThumbnail(of: pawn, side: side, height: height) { return image }
        return await onQueue { renderer in
            let image = renderer.thumbnail(of: pawn, side: side, height: height)
            if let image { self.keep(image, as: self.key(pawn, side, height)) }
            return image
        }
    }

    /// An item's card, rendering it first if needed.
    func cardImage(of card: ItemCardContent, height: Int = thumbnailHeight) async -> CGImage? {
        let looks = ItemCardPreferences.cacheKey
        let key = "item-\(card.item.id)-\(card.card)-\(card.artwork?.id.uuidString ?? "plain")-\(looks)-\(height)"
        if let image = thumbnails.object(forKey: key as NSString) { return image }
        return await onQueue { renderer in
            let image = renderer.cardImage(card, height: height)
            if let image { self.keep(image, as: key as NSString) }
            return image
        }
    }

    /// The front's art without its printed words, not kept, for work that looks at every pawn once.
    func artImage(of pawn: Pawn, height: Int) async -> CGImage? {
        await onQueue { $0.artImage(of: pawn, height: height) }
    }

    /// A page `width` pixels wide; nil when the task asking was cancelled before its turn came. Pages are the
    /// slow drawings, and one that is no longer wanted, as when its sheet changed again or more pictures arrived,
    /// would otherwise keep the page that is wanted waiting behind it.
    func image(of page: PageDrawing, width: Int) async -> CGImage? {
        let request = RenderRequest()
        return await withTaskCancellationHandler {
            await drawPage(page, width: width, unless: request)
        } onCancel: {
            request.cancel()
        }
    }

    private func drawPage(_ page: PageDrawing, width: Int, unless request: RenderRequest) async -> CGImage? {
        await onQueue { renderer in
            request.isCancelled ? nil : Self.image(of: page, width: width, drawnBy: renderer)
        }
    }

    /// A page's picture for its sheet's file (R12), drawn before returning: for the thread saving a sheet, which
    /// can't wait any other way. It needs nothing from the main thread.
    func previewJPEG(of page: PageDrawing) -> Data {
        dispatchPrecondition(condition: .notOnQueue(queue))
        let image = queue.sync { Self.image(of: page, width: SheetPreviews.pageWidth, drawnBy: readyRenderer()) }
        return image.map(SheetPreviews.jpegData) ?? Data()
    }

    /// Changes whenever a page would look different: with its strips, its pawns' looks, its cards and their
    /// settings, and when the pictures its pawns are drawn from arrive on the device.
    func key(of page: PageDrawing) -> String {
        let strips = zip(page.strips, page.contents).map { strip, content in
            "\(contentKey(content))@\(strip.rect)\(strip.sideways)"
        }
        return strips.joined(separator: ";") + "|\(page.settings.hashValue)|\(ItemCardPreferences.cacheKey)"
    }

    private func contentKey(_ content: PlacedContent) -> String {
        switch content {
        case .pawn(.found(let pawn)): key(pawn, .front, 0) as String
        case .pawn(.missing(let description)): "missing-\(description)"
        case .card(let card?): "item-\(card.item.hashValue)-\(card.card)-\(card.artwork?.id.uuidString ?? "plain")"
        case .card(nil): "item-missing"
        }
    }

    private static func image(of page: PageDrawing, width: Int, drawnBy renderer: PawnRenderer) -> CGImage? {
        let paper = page.settings.paper.paperSize
        let height = Int((CGFloat(width) * paper.height / paper.width).rounded())
        guard width > 0, height > 0,
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.setFillColor(gray: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.scaleBy(x: CGFloat(width) / paper.width, y: CGFloat(height) / paper.height)
        for (strip, content) in zip(page.strips, page.contents) {
            renderer.draw(content, in: strip, settings: page.settings, context: context)
        }
        return context.makeImage()
    }

    private func keep(_ image: CGImage, as key: NSString) {
        thumbnails.setObject(image, forKey: key, cost: image.bytesPerRow * image.height)
    }

    /// Drops a pawn's thumbnails, after it was removed.
    func forget(_ pawn: Pawn) {
        for side in [PawnSide.front, .back] {
            thumbnails.removeObject(forKey: key(pawn, side, Self.thumbnailHeight))
        }
    }

    private func onQueue(_ work: @escaping @Sendable (PawnRenderer) -> CGImage?) async -> CGImage? {
        await withCheckedContinuation { continuation in
            queue.async { continuation.resume(returning: work(self.readyRenderer())) }
        }
    }

    /// The renderer with the user's card settings, made on first use; called on `queue` only.
    private func readyRenderer() -> PawnRenderer {
        let renderer = self.renderer ?? PawnRenderer(folders: folders)
        ItemCardPreferences.apply(to: renderer)
        self.renderer = renderer
        return renderer
    }

    /// Changes with what the face shows (its name, size and art, which sharper art from Battle Cards replaces,
    /// and whether the pictures it is drawn from are on the device yet, R10.4), not with tags.
    private func key(_ pawn: Pawn, _ side: PawnSide, _ height: Int) -> NSString {
        var looks = Hasher()
        looks.combine(pawn.name)
        looks.combine(pawn.size)
        looks.combine(pawn.art)
        looks.combine(pawn.pictureFiles.allSatisfy { name in
            FileManager.default.fileExists(atPath: folders.pictures.appendingPathComponent(name).path)
        })
        return "\(pawn.id)-\(looks.finalize())-\(side == .front ? "front" : "back")-\(height)" as NSString
    }
}

/// Whether the task waiting for a drawing still wants it, asked from the rendering queue.
private final class RenderRequest: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    var isCancelled: Bool { lock.withLock { cancelled } }

    func cancel() { lock.withLock { cancelled = true } }
}
