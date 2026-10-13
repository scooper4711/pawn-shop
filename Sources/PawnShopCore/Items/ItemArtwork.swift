import ArtExtraction
import Foundation

/// An item's picture from an item deck the user imported, shown faintly behind the item's card. It isn't a pawn:
/// item art is looked up by the item's name (`ItemArtMatcher`).
public struct ItemArtwork: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    /// The name the deck prints, in title case.
    public var name: String
    public var sourceID: String
    public var picture: ItemPicture
    public var fingerprint: ArtFingerprint

    public init(id: UUID = UUID(), name: String, sourceID: String, picture: ItemPicture,
                fingerprint: ArtFingerprint) {
        self.id = id
        self.name = name
        self.sourceID = sourceID
        self.picture = picture
        self.fingerprint = fingerprint
    }
}

/// Where an item's picture is.
public enum ItemPicture: Codable, Hashable, Sendable {
    /// A picture on a page of the library's copy of a PDF deck, drawn `imageIndex`th, cut to the face's rect.
    case figure(face: PawnFace, imageIndex: Int)
    /// A PNG in the library's `Items` folder, cut out of a deck sold as pictures.
    case drawn(file: String)
}
