import AppKit
import PawnShopCore

/// What a sheet page shows, ready to draw on another thread.
struct PageDrawing: Sendable {
    let strips: [PlacedStrip]
    /// The pawn for each strip; nil when it is missing from the library.
    let pawns: [Pawn?]
    let settings: SheetSettings
}

/// Renders pawn thumbnails and sheet pages on a background queue, keeping thumbnails in memory.
final class BackgroundRenderer: @unchecked Sendable {
    /// Thumbnail height in pixels: enough for a sharp tile on a Retina display.
    static let thumbnailHeight = 240

    private let queue = DispatchQueue(label: "PawnShop.rendering", qos: .userInitiated)
    private let thumbnails = NSCache<NSString, CGImage>()
    private let folders: LibraryFolders
    /// Created on `queue` and used only there.
    private var renderer: PawnRenderer?

    init(folders: LibraryFolders) {
        self.folders = folders
        thumbnails.countLimit = 2000
    }

    /// The thumbnail if it is ready.
    func cachedThumbnail(of pawn: Pawn, side: PawnSide = .front, height: Int = thumbnailHeight) -> CGImage? {
        thumbnails.object(forKey: key(pawn.id, side, height))
    }

    /// The thumbnail, rendering it first if needed.
    func thumbnail(of pawn: Pawn, side: PawnSide = .front, height: Int = thumbnailHeight) async -> CGImage? {
        if let image = cachedThumbnail(of: pawn, side: side, height: height) { return image }
        return await onQueue { renderer in
            let image = renderer.thumbnail(of: pawn, side: side, height: height)
            if let image { self.thumbnails.setObject(image, forKey: self.key(pawn.id, side, height)) }
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
            for (strip, pawn) in zip(page.strips, page.pawns) {
                renderer.drawStrip(pawn, in: strip, settings: page.settings, context: context)
            }
            return context.makeImage()
        }
    }

    /// Drops a pawn's thumbnails, after it changed or was removed.
    func forget(_ id: UUID) {
        for side in [PawnSide.front, .back] {
            thumbnails.removeObject(forKey: key(id, side, Self.thumbnailHeight))
        }
    }

    private func onQueue(_ work: @escaping @Sendable (PawnRenderer) -> CGImage?) async -> CGImage? {
        await withCheckedContinuation { continuation in
            queue.async {
                let renderer = self.renderer ?? PawnRenderer(folders: self.folders)
                self.renderer = renderer
                continuation.resume(returning: work(renderer))
            }
        }
    }

    private func key(_ id: UUID, _ side: PawnSide, _ height: Int) -> NSString {
        "\(id)-\(side == .front ? "front" : "back")-\(height)" as NSString
    }
}
