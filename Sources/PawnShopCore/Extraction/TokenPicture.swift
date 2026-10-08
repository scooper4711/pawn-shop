import CoreGraphics
import Foundation
import ImageIO

/// A token's art alone: the images clipped to its circle, without the page around them (a dark background, the
/// cut line, the name printed along the rim), transparent outside the art.
enum TokenPicture {
    /// Pixels per point at most (600 dpi), so the largest tokens stay a sensible size.
    static let maximumScale: CGFloat = 600 / 72

    /// The art inside the token's clip circle as PNG, at the resolution of its sharpest image; nil when none of
    /// its images can be decoded.
    static func png(of token: FoundToken) -> Data? {
        let pictures = token.images.compactMap { placement in
            placement.stream.flatMap(EmbeddedImage.maskedImage(of:)).map { (placement, $0) }
        }
        guard let sharpest = pictures.map({ CGFloat($1.width) / max($0.rect.width, 1) }).max() else { return nil }
        let scale = min(maximumScale, max(sharpest, 1))
        let side = max(1, Int((token.clip.diameter * scale).rounded()))
        guard let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.interpolationQuality = .high
        context.scaleBy(x: CGFloat(side) / token.clip.diameter, y: CGFloat(side) / token.clip.diameter)
        context.translateBy(x: -token.clip.bounds.minX, y: -token.clip.bounds.minY)
        context.addEllipse(in: token.clip.bounds)
        context.clip()
        for (placement, image) in pictures {
            context.saveGState()
            context.concatenate(placement.transform)
            context.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
            context.restoreGState()
        }
        return context.makeImage().flatMap(pngData(of:))
    }

    static func pngData(of image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }
}

extension EmbeddedImage {
    /// The image an XObject shows, made transparent by its soft mask when it has one.
    static func maskedImage(of stream: CGPDFStreamRef) -> CGImage? {
        guard let image = image(of: stream), let dictionary = CGPDFStreamGetDictionary(stream) else { return nil }
        var mask: CGPDFStreamRef?
        guard CGPDFDictionaryGetStream(dictionary, "SMask", &mask), let mask, let alpha = Self.image(of: mask)
        else { return image }
        return image.masked(by: alpha)
    }

    /// The image an XObject shows, without its mask.
    static func image(of stream: CGPDFStreamRef) -> CGImage? {
        var format = CGPDFDataFormat.raw
        guard let data = CGPDFStreamCopyData(stream, &format) as Data?,
              let dictionary = CGPDFStreamGetDictionary(stream)
        else { return nil }
        return decode(data, format: format, dictionary: dictionary)
    }
}

private extension CGImage {
    /// This image with `alpha`'s gray levels as its opacity, at this image's size.
    func masked(by alpha: CGImage) -> CGImage? {
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        guard let grayAlpha = alpha.grayscale(width: width, height: height),
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.clip(to: rect, mask: grayAlpha)
        context.draw(self, in: rect)
        return context.makeImage()
    }

    /// The image redrawn in device gray, without alpha, at the given size, as a clipping mask needs.
    func grayscale(width: Int, height: Int) -> CGImage? {
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue)
        else { return nil }
        context.interpolationQuality = .high
        context.draw(self, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }
}
