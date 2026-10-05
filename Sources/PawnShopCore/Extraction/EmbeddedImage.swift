import CoreGraphics
import CryptoKit
import Foundation
import ImageIO

/// What an image embedded in a PDF shows, independent of where it is drawn.
struct ImageIdentity: Equatable, Sendable {
    /// SHA-256 of the image's data: the same image object, or an identical copy, has the same digest.
    let digest: String
    /// A tiny grayscale version of the image's pixels, row by row from the top; empty when it can't be decoded.
    /// The same art embedded again with different compression has a nearly identical thumbnail.
    let thumbnail: [UInt8]

    static let empty = ImageIdentity(digest: "", thumbnail: [])
}

/// Reads image XObjects.
enum EmbeddedImage {
    static let thumbnailColumns = 16, thumbnailRows = 24

    static func identity(of stream: CGPDFStreamRef) -> ImageIdentity {
        var format = CGPDFDataFormat.raw
        guard let data = CGPDFStreamCopyData(stream, &format) as Data?,
              let dictionary = CGPDFStreamGetDictionary(stream)
        else { return .empty }
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        let image = decode(data, format: format, dictionary: dictionary)
        return ImageIdentity(digest: digest, thumbnail: image.map(thumbnail(of:)) ?? [])
    }

    static func decode(_ data: Data, format: CGPDFDataFormat, dictionary: CGPDFDictionaryRef) -> CGImage? {
        switch format {
        case .jpegEncoded, .JPEG2000:
            guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
            return CGImageSourceCreateImageAtIndex(source, 0, nil)
        case .raw:
            return decodeRaw(data, dictionary: dictionary)
        @unknown default:
            return nil
        }
    }

    /// Uncompressed samples in a device or ICC-based color space; other color spaces are not decoded.
    private static func decodeRaw(_ data: Data, dictionary: CGPDFDictionaryRef) -> CGImage? {
        var width: CGPDFInteger = 0, height: CGPDFInteger = 0, bits: CGPDFInteger = 8
        guard CGPDFDictionaryGetInteger(dictionary, "Width", &width),
              CGPDFDictionaryGetInteger(dictionary, "Height", &height),
              let space = colorSpace(of: dictionary)
        else { return nil }
        _ = CGPDFDictionaryGetInteger(dictionary, "BitsPerComponent", &bits)
        let components = space.numberOfComponents
        let bytesPerRow = (width * components * bits + 7) / 8
        guard bits == 8, data.count >= bytesPerRow * height, let provider = CGDataProvider(data: data as CFData)
        else { return nil }
        return CGImage(width: width, height: height, bitsPerComponent: bits, bitsPerPixel: bits * components,
                       bytesPerRow: bytesPerRow, space: space, bitmapInfo: CGBitmapInfo(rawValue: 0),
                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }

    private static func colorSpace(of dictionary: CGPDFDictionaryRef) -> CGColorSpace? {
        var name: UnsafePointer<CChar>?
        if CGPDFDictionaryGetName(dictionary, "ColorSpace", &name), let name {
            return deviceSpace(components: ["DeviceGray": 1, "DeviceRGB": 3, "DeviceCMYK": 4][String(cString: name)])
        }
        var array: CGPDFArrayRef?
        var family: UnsafePointer<CChar>?
        var profile: CGPDFStreamRef?
        var components: CGPDFInteger = 0
        guard CGPDFDictionaryGetArray(dictionary, "ColorSpace", &array), let array,
              CGPDFArrayGetName(array, 0, &family), let family, String(cString: family) == "ICCBased",
              CGPDFArrayGetStream(array, 1, &profile), let profile,
              let profileDictionary = CGPDFStreamGetDictionary(profile),
              CGPDFDictionaryGetInteger(profileDictionary, "N", &components)
        else { return nil }
        return deviceSpace(components: components)
    }

    private static func deviceSpace(components: Int?) -> CGColorSpace? {
        switch components {
        case 1: CGColorSpaceCreateDeviceGray()
        case 3: CGColorSpaceCreateDeviceRGB()
        case 4: CGColorSpaceCreateDeviceCMYK()
        default: nil
        }
    }

    /// The image stretched to `thumbnailColumns × thumbnailRows` gray cells.
    static func thumbnail(of image: CGImage) -> [UInt8] {
        let columns = thumbnailColumns, rows = thumbnailRows
        guard let context = CGContext(data: nil, width: columns, height: rows, bitsPerComponent: 8,
                                      bytesPerRow: columns, space: CGColorSpaceCreateDeviceGray(),
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue),
              let data = context.data
        else { return [] }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: columns, height: rows))
        return Array(UnsafeBufferPointer(start: data.bindMemory(to: UInt8.self, capacity: columns * rows),
                                         count: columns * rows))
    }
}
