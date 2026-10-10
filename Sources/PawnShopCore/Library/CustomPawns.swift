import CoreGraphics
import ArtExtraction
import Foundation
import ImageIO

/// What the user chose for a pawn made from their own art.
public struct NewCustomPawn: @unchecked Sendable {
    public var image: CGImage
    public var name: String
    public var size: PawnSize
    /// Where the image sits when it overflows the outline (see `CustomArt.focus`).
    public var focus: CGPoint
    public var showsName: Bool
    public var scaling: ArtScaling = .fill

    public init(image: CGImage, name: String, size: PawnSize = .medium,
                focus: CGPoint = CGPoint(x: 0.5, y: 0.5), showsName: Bool = true) {
        self.image = image
        self.name = name
        self.size = size
        self.focus = focus
        self.showsName = showsName
    }
}

public extension PawnLibrary {
    /// Saves the art as PNG in the custom folder and adds a pawn for it.
    @discardableResult
    func addCustomPawn(_ new: NewCustomPawn) throws -> Pawn {
        let id = UUID()
        let file = "\(id.uuidString).png"
        try Self.writePNG(new.image, to: customFolder.appendingPathComponent(file))
        let trimmed = new.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let pawn = Pawn(id: id, name: trimmed.isEmpty ? "Custom Pawn" : trimmed, size: new.size,
                        art: .custom(CustomArt(imageFile: file, focus: new.focus, showsName: new.showsName,
                                               scaling: new.scaling)))
        try add(pawn)
        return pawn
    }

    /// Reads an image file (any format ImageIO knows) for a custom pawn.
    static func image(at url: URL) throws -> CGImage {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { throw PawnLibraryError.unreadableFile(url.lastPathComponent) }
        return image
    }

    private static func writePNG(_ image: CGImage, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)
        else { throw PawnLibraryError.saveFailed("creating \(url.lastPathComponent)") }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw PawnLibraryError.saveFailed("writing \(url.lastPathComponent)")
        }
    }
}
