import CoreGraphics
import Foundation

/// A creature's art alone: one image as its page draws it, cut down to the part that isn't transparent.
struct Figure {
    /// Alpha at or below this is a faint glow or shadow, not part of the figure's bounds.
    static let opaqueAlpha: UInt8 = 24
    /// The long side, in pixels, of the bitmap the opaque part is measured in: fine enough to trim to a point.
    static let trimmingResolution = 512
    /// Palettes are counted on this many pixels across, so every resolution is compared alike.
    static let paletteSide = 64
    /// Palettes at most this far apart (see `paletteDistance`) are the same painting. Measured on the Bestiary
    /// Battle Cards against the Bestiary Pawn Box: the same painting, however cropped, reached 0.013; a different
    /// painting of the same creature was 0.027 or more.
    static let samePaintingDistance = 0.02

    let placement: ImagePlacement
    /// The image, made transparent by its soft mask.
    let image: CGImage
    /// The figure's bounds in page space.
    let bounds: CGRect

    /// The figure drawn by `placement`, trimmed to its opaque part; nil when its image can't be decoded or is
    /// transparent throughout.
    init?(_ placement: ImagePlacement) {
        guard let image = placement.stream.flatMap(EmbeddedImage.maskedImage(of:)),
              let bounds = Self.opaqueBounds(of: image, placement: placement)
        else { return nil }
        self.init(placement: placement, image: image, bounds: bounds)
    }

    init(placement: ImagePlacement, image: CGImage, bounds: CGRect) {
        self.placement = placement
        self.image = image
        self.bounds = bounds
    }

    /// The largest image drawn with its center inside `rect`, as on a pawn's face; nil when there is none.
    static func largest(inside rect: CGRect, among images: [ImagePlacement]) -> Figure? {
        let art = images.filter { image in
            image.stream != nil && min(image.rect.width, image.rect.height) >= ArtFingerprint.smallestArt
                && rect.contains(CGPoint(x: image.rect.midX, y: image.rect.midY))
        }
        return art.max { $0.rect.width * $0.rect.height < $1.rect.width * $1.rect.height }.flatMap(Figure.init)
    }

    /// The figure's size in the image's own pixels: how sharp the art is, whatever size it is printed.
    var pixelArea: CGFloat {
        let transform = placement.transform
        let pageArea = abs(transform.a * transform.d - transform.b * transform.c)
        guard pageArea > 0 else { return 0 }
        return bounds.width * bounds.height * CGFloat(image.width * image.height) / pageArea
    }

    /// Draws the figure so that its bounds fill `rect`, flipped left to right when `mirrored`.
    func draw(in rect: CGRect, mirrored: Bool = false, context: CGContext) {
        guard bounds.width > 0, bounds.height > 0 else { return }
        context.saveGState()
        context.clip(to: rect)
        context.translateBy(x: rect.minX, y: rect.minY)
        if mirrored {
            context.translateBy(x: rect.width, y: 0)
            context.scaleBy(x: -1, y: 1)
        }
        context.scaleBy(x: rect.width / bounds.width, y: rect.height / bounds.height)
        context.translateBy(x: -bounds.minX, y: -bounds.minY)
        context.concatenate(placement.transform)
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        context.restoreGState()
    }

    // MARK: Palette

    /// The share of the figure's opaque pixels in each of 64 colors (four levels of red, green and blue). It
    /// changes little when the painting is cropped or scaled, and a lot between different paintings.
    func palette() -> [Double] {
        let side = Self.paletteSide
        guard let pixels = Self.pixels(width: side, height: side, draw: { context in
            draw(in: CGRect(x: 0, y: 0, width: side, height: side), context: context)
        }) else { return [] }
        var counts = [Double](repeating: 0, count: 64)
        for offset in stride(from: 0, to: pixels.count, by: 4) where pixels[offset + 3] > 127 {
            let alpha = Int(pixels[offset + 3])
            let levels = (0..<3).map { min(255, Int(pixels[offset + $0]) * 255 / alpha) / 64 }
            counts[levels[0] * 16 + levels[1] * 4 + levels[2]] += 1
        }
        let total = counts.reduce(0, +)
        return total > 0 ? counts.map { $0 / total } : []
    }

    /// How unlike two palettes are, from 0 (the same colors in the same shares) to 1 (no color in common); 1
    /// when either is empty.
    static func paletteDistance(_ first: [Double], _ second: [Double]) -> Double {
        guard !first.isEmpty, first.count == second.count else { return 1 }
        return 1 - zip(first, second).reduce(0) { $0 + ($1.0 * $1.1).squareRoot() }
    }

    /// True when the two figures are the same painting, however each is cropped or scaled.
    func isSamePainting(as other: Figure) -> Bool {
        Self.paletteDistance(palette(), other.palette()) <= Self.samePaintingDistance
    }

    // MARK: Trimming

    /// The part of the image's page area that isn't transparent, in page space.
    private static func opaqueBounds(of image: CGImage, placement: ImagePlacement) -> CGRect? {
        let area = placement.rect
        guard area.width > 0, area.height > 0 else { return nil }
        let scale = CGFloat(trimmingResolution) / max(area.width, area.height)
        let width = max(1, Int((area.width * scale).rounded())), height = max(1, Int((area.height * scale).rounded()))
        guard let pixels = pixels(width: width, height: height, draw: { context in
            context.scaleBy(x: CGFloat(width) / area.width, y: CGFloat(height) / area.height)
            context.translateBy(x: -area.minX, y: -area.minY)
            context.concatenate(placement.transform)
            context.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        }), let box = opaqueBox(in: pixels, width: width, height: height)
        else { return nil }
        // Rows run from the top of the bitmap, page space from the bottom.
        return CGRect(x: area.minX + box.minX * area.width / CGFloat(width),
                      y: area.minY + (CGFloat(height) - box.maxY) * area.height / CGFloat(height),
                      width: box.width * area.width / CGFloat(width),
                      height: box.height * area.height / CGFloat(height))
    }

    /// The smallest box of pixels holding every pixel more opaque than `opaqueAlpha`, in pixels from the top left.
    private static func opaqueBox(in pixels: [UInt8], width: Int, height: Int) -> CGRect? {
        var minX = width, maxX = -1, minY = height, maxY = -1
        for row in 0..<height {
            for column in 0..<width where pixels[(row * width + column) * 4 + 3] > opaqueAlpha {
                minX = min(minX, column)
                maxX = max(maxX, column)
                minY = min(minY, row)
                maxY = max(maxY, row)
            }
        }
        guard maxX >= minX else { return nil }
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }

    /// RGBA bytes, premultiplied, rows from the top, of a transparent bitmap after `draw`.
    private static func pixels(width: Int, height: Int, draw: (CGContext) -> Void) -> [UInt8]? {
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let data = context.data
        else { return nil }
        context.interpolationQuality = .medium
        draw(context)
        return Array(UnsafeBufferPointer(start: data.bindMemory(to: UInt8.self, capacity: width * height * 4),
                                         count: width * height * 4))
    }
}
