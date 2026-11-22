import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// The small pictures of a sheet's pages saved in its `.pawnsheet` file, for Files and Quick Look to show (R12).
/// They live beside the sheet's own keys in the file's JSON, so the Quick Look extensions read them without the
/// library, and older versions of the app ignore them.
public struct SheetPreviews: Codable, Hashable, Sendable {
    /// A page's width in pixels: 72 dpi on Letter, enough to recognize pawns and too coarse to print.
    public static let pageWidth = 612
    /// The most pages a file keeps pictures of, which bounds what they add to its size.
    public static let maximumPages = 24
    private static let jpegQuality = 0.6

    /// One JPEG per page, in order.
    public var pages: [Data]

    public init(pages: [Data] = []) {
        self.pages = Array(pages.prefix(Self.maximumPages))
    }

    /// The pictures in a `.pawnsheet` file's data; none when it has none or they can't be read.
    public init(fileData: Data) {
        self = (try? JSONDecoder().decode(Self.self, from: fileData)) ?? Self()
    }

    private enum CodingKeys: String, CodingKey { case pages = "previewPages" }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(pages: try container.decodeIfPresent([Data].self, forKey: .pages) ?? [])
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if !pages.isEmpty { try container.encode(pages, forKey: .pages) }
    }

    /// A page's picture as a JPEG; empty when it can't be encoded.
    public static func jpegData(of image: CGImage) -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil)
        else { return Data() }
        let options = [kCGImageDestinationLossyCompressionQuality: jpegQuality] as CFDictionary
        CGImageDestinationAddImage(destination, image, options)
        return CGImageDestinationFinalize(destination) ? data as Data : Data()
    }

    /// The first page that can be read, for a thumbnail.
    public var firstPageImage: CGImage? {
        pages.lazy.compactMap(Self.image).first
    }

    /// A PDF with one page per picture, for Quick Look; empty when no picture can be read.
    public func pdfData() -> Data {
        let images = pages.compactMap(Self.image)
        let data = NSMutableData()
        guard !images.isEmpty, let consumer = CGDataConsumer(data: data as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: nil, nil)
        else { return Data() }
        for image in images {
            var box = CGRect(x: 0, y: 0, width: image.width, height: image.height)
            context.beginPage(mediaBox: &box)
            context.draw(image, in: box)
            context.endPage()
        }
        context.closePDF()
        return data as Data
    }

    private static func image(of page: Data) -> CGImage? {
        CGImageSourceCreateWithData(page as CFData, nil).flatMap { CGImageSourceCreateImageAtIndex($0, 0, nil) }
    }
}
