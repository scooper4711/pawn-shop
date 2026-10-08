import CoreGraphics
import Foundation

/// Identifies a pawn's art by the images drawn inside its outline. Copies of a pawn, and reprints that reuse
/// the same image, match; different art of the same creature does not.
public struct ArtFingerprint: Codable, Hashable, Sendable {
    /// Images smaller than this on the page are badges or decorations, not art.
    static let smallestArt: CGFloat = 20
    /// Thumbnails at most this far apart (see `thumbnailDistance`) show the same art. Measured on Paizo's
    /// PDFs, copies of one image embedded separately reach about 10; different figures start above 40.
    static let matchingDistance = 20.0

    /// SHA-256 digests of the art images, sorted. Empty when the art is not a raster image.
    public let imageDigests: [String]
    /// The largest art image's thumbnail (see `ImageIdentity`); empty when there is none. It matches copies
    /// whose image was embedded again with different compression.
    public let thumbnail: [UInt8]

    public init(imageDigests: [String], thumbnail: [UInt8] = []) {
        self.imageDigests = Array(Set(imageDigests)).sorted()
        self.thumbnail = thumbnail
    }

    private enum CodingKeys: String, CodingKey { case imageDigests, thumbnail }

    /// The thumbnail is stored as data (base64 in JSON) rather than an array of numbers.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        imageDigests = try container.decode([String].self, forKey: .imageDigests)
        thumbnail = [UInt8](try container.decode(Data.self, forKey: .thumbnail))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(imageDigests, forKey: .imageDigests)
        try container.encode(Data(thumbnail), forKey: .thumbnail)
    }

    /// The art drawn inside `rect`: images at least `smallestArt` across whose centers lie in it.
    init(images: [ImagePlacement], inside rect: CGRect) {
        let art = images.filter { image in
            min(image.rect.width, image.rect.height) >= Self.smallestArt
                && rect.contains(CGPoint(x: image.rect.midX, y: image.rect.midY)) && !image.identity.digest.isEmpty
        }
        let largest = art.max { $0.rect.width * $0.rect.height < $1.rect.width * $1.rect.height }
        self.init(imageDigests: art.map(\.identity.digest), thumbnail: largest?.identity.thumbnail ?? [])
    }

    /// True when both show the same images, or look the same. Art without images never matches.
    public func matches(_ other: ArtFingerprint) -> Bool {
        guard !imageDigests.isEmpty, !other.imageDigests.isEmpty else { return false }
        return imageDigests == other.imageDigests || thumbnailDistance(from: other) <= Self.matchingDistance
    }

    /// True when `back` shows this art as a duplex back page prints it: the same images, or the same picture
    /// as is or mirrored, since a back page draws the art flipped or embeds a flipped copy.
    func matchesBack(_ back: ArtFingerprint) -> Bool {
        matches(back) || matches(back.horizontallyFlipped)
    }

    /// The same art mirrored left to right: its thumbnail flipped.
    var horizontallyFlipped: ArtFingerprint {
        let columns = EmbeddedImage.thumbnailColumns
        guard !thumbnail.isEmpty, thumbnail.count.isMultiple(of: columns) else { return self }
        let rows = stride(from: 0, to: thumbnail.count, by: columns).map { thumbnail[$0..<$0 + columns].reversed() }
        return ArtFingerprint(imageDigests: imageDigests, thumbnail: rows.flatMap { $0 })
    }

    /// How unlike the thumbnails are, from 0 (identical patterns) to 200 (inverted): 100 × (1 − correlation).
    /// Correlation ignores overall brightness and contrast, so a shared plain background doesn't make
    /// different figures look alike. Infinite when the thumbnails can't be compared.
    public func thumbnailDistance(from other: ArtFingerprint) -> Double {
        guard !thumbnail.isEmpty, thumbnail.count == other.thumbnail.count else { return .infinity }
        let first = thumbnail.map(Double.init), second = other.thumbnail.map(Double.init)
        let firstMean = first.reduce(0, +) / Double(first.count)
        let secondMean = second.reduce(0, +) / Double(second.count)
        var product = 0.0, firstSquares = 0.0, secondSquares = 0.0
        for (firstValue, secondValue) in zip(first, second) {
            product += (firstValue - firstMean) * (secondValue - secondMean)
            firstSquares += (firstValue - firstMean) * (firstValue - firstMean)
            secondSquares += (secondValue - secondMean) * (secondValue - secondMean)
        }
        guard firstSquares > 0, secondSquares > 0 else { return first == second ? 0 : .infinity }
        return 100 * (1 - product / (firstSquares * secondSquares).squareRoot())
    }
}
