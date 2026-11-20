import CoreGraphics
import ArtExtraction
import Foundation
import ImageIO
import SharedLibraries

/// What the user chose for a pawn made from their own art.
public struct NewCustomPawn: @unchecked Sendable {
    public var image: CGImage
    public var name: String
    /// The creature's size, one of Paizo's six (R3.1); Tiny prints the same pawn as Small.
    public var size: CreatureSize
    /// Where the image sits when it overflows the outline (see `CustomArt.focus`).
    public var focus: CGPoint
    public var showsName: Bool
    public var scaling: ArtScaling = .fill

    public init(image: CGImage, name: String, size: CreatureSize = .medium,
                focus: CGPoint = CGPoint(x: 0.5, y: 0.5), showsName: Bool = true) {
        self.image = image
        self.name = name
        self.size = size
        self.focus = focus
        self.showsName = showsName
    }
}

/// A custom pawn's creature to add to the creature library: the pawn says its ID, its name and how its image
/// sits on it.
struct NewCreature {
    var pawn: Pawn
    var size: CreatureSize
    /// The image to save as the pawn's art; nil when its file is in the shared library's custom folder already.
    var image: Data?
}

public extension PawnLibrary {
    /// Adds a custom creature with the art as its PNG image, without a stat block (R3.4), and its pawn.
    @discardableResult
    func addCustomPawn(_ new: NewCustomPawn) throws -> Pawn {
        let id = UUID()
        let trimmed = new.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let art = CustomArt(imageFile: "\(id.uuidString).png", focus: new.focus, showsName: new.showsName,
                            scaling: new.scaling)
        let pawn = Pawn(id: id, name: trimmed.isEmpty ? "Custom Pawn" : trimmed, size: new.size.pawnSize,
                        art: .custom(art))
        try add(NewCreature(pawn: pawn, size: new.size, image: try Self.pngData(of: new.image)))
        return self.pawn(id: id) ?? pawn
    }

    /// Reads an image file (any format ImageIO knows) for a custom pawn.
    static func image(at url: URL) throws -> CGImage {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { throw PawnLibraryError.unreadableFile(url.lastPathComponent) }
        return image
    }

    private static func pngData(of image: CGImage) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil) else {
            throw PawnLibraryError.saveFailed("encoding a custom pawn's image")
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw PawnLibraryError.saveFailed("encoding a custom pawn's image")
        }
        return data as Data
    }
}

extension PawnLibrary {
    /// Adds a custom pawn drawn from an image that is in the shared library's custom folder already, with the
    /// creature size of its pawn's name.
    func add(_ pawn: Pawn) throws {
        try add(NewCreature(pawn: pawn, size: CreatureSize(pawn.size)))
    }

    /// Adds the creature, its art and the choice between them to the creature library (shared libraries R4.6),
    /// keeps what is Pawn Shop's own about the pawn, and saves. A pawn drawn from anything but the user's image
    /// isn't one to add.
    func add(_ new: NewCreature) throws {
        guard case .custom(let art) = new.pawn.art else { return }
        try addCreature(new, imageFile: art.imageFile)
        keepSettings(of: new.pawn)
        try saveOwnAndRefresh()
    }

    /// Writes a custom pawn's creature to the creature library under the pawn's ID, without a stat block or a
    /// game; its art has the same ID.
    func addCreature(_ new: NewCreature, imageFile: String) throws {
        let creature = CustomCreatureRecord(id: new.pawn.id, name: new.pawn.name, campaignID: nil, sharedVersion: nil,
                                            record: Data(), size: new.size)
        let art = CustomArtRecord(id: new.pawn.id, fileName: imageFile, sharedVersion: nil, record: Data())
        try shared.addCustomCreature(creature, art: art, image: new.image)
    }
}
