import AppKit
import PawnShopCore

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

    /// A page `width` pixels wide.
    func image(of page: PageDrawing, width: Int) async -> CGImage? {
        await onQueue { renderer in
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
            queue.async {
                let renderer = self.renderer ?? PawnRenderer(folders: self.folders)
                ItemCardPreferences.apply(to: renderer)
                self.renderer = renderer
                continuation.resume(returning: work(renderer))
            }
        }
    }

    /// Changes with what the face shows (its name, size and art, which sharper art from Battle Cards replaces),
    /// not with tags.
    private func key(_ pawn: Pawn, _ side: PawnSide, _ height: Int) -> NSString {
        var looks = Hasher()
        looks.combine(pawn.name)
        looks.combine(pawn.size)
        looks.combine(pawn.art)
        return "\(pawn.id)-\(looks.finalize())-\(side == .front ? "front" : "back")-\(height)" as NSString
    }
}
