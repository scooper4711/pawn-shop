import CoreGraphics
import ArtExtraction
import Foundation

/// The game a product belongs to, read from its title.
public enum Game: String, Codable, CaseIterable, Sendable {
    case pathfinder, starfinder

    public var displayName: String { rawValue.capitalized }
}

/// An imported pawn PDF.
public struct PawnSource: Codable, Identifiable, Hashable, Sendable {
    /// SHA-256 of the file, so the same PDF is recognized wherever it was imported from.
    public let id: String
    public var title: String
    public var importedAt: Date
    /// Where the file was imported from, and its size then, to recognize it again without hashing it.
    public var originalPath: String
    public var byteCount: Int
    /// How many pawns importing it found; nil for products imported before this was recorded.
    public var pawnsFound: Int?
    /// The `PawnExtractor.version` that read it; nil (version 0) for products imported before this was recorded.
    public var readerVersion: Int?

    public var game: Game { title.localizedCaseInsensitiveContains("Starfinder") ? .starfinder : .pathfinder }

    /// The title without the words every product shares: "Pathfinder Pawns: Bestiary 2 Box" becomes
    /// "Bestiary 2", "Starfinder Alien Archive Pawn Box" becomes "Alien Archive", "Starfinder Alien Core Token
    /// Box" becomes "Alien Core".
    public var shortTitle: String {
        var short = title
        for pattern in [#"^(Pathfinder|Starfinder)\s+"#, #"^Pawns:\s*"#, #"^(Pathfinder|Starfinder)\s+"#,
                        #"\s+((Pawn|Token)\s+)?(Collection|Box)$"#, #"\s+(Pawn|Tokens)$"#] {
            short = short.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        return short.isEmpty ? title : short
    }

    /// A readable title from a file name: "PZO1234 Pathfinder Pawns- Bestiary Box PDF.pdf" becomes
    /// "Pathfinder Pawns: Bestiary Box".
    public static func title(fromFileName name: String) -> String {
        ProductTitle.fromFileName(name)
    }
}

/// Where a pawn's art comes from.
public enum PawnArt: Codable, Hashable, Sendable {
    /// Faces on the pages of an imported PDF.
    case pdf(sourceID: String, front: PawnFace, back: PawnFace)
    /// An image the user added; the back is the front mirrored.
    case custom(CustomArt)
    /// A round token on the pages of an imported PDF, drawn in a pawn's outline.
    case token(TokenArt)
    /// A creature on a Battle Card in an imported PDF, drawn in a pawn's outline.
    case card(CardArt)

    /// The imported PDF the faces come from; nil for custom art.
    public var sourceID: String? {
        switch self {
        case .pdf(let sourceID, _, _): sourceID
        case .token(let art): art.sourceID
        case .card(let art): art.sourceID
        case .custom: nil
        }
    }
}

/// A creature on a Battle Card, drawn in a pawn's outline as large as it fits above the name, standing on it,
/// on white. Only the creature's picture is drawn, not the card around it, straight from the library's copy of
/// the PDF; the back is the front mirrored.
public struct CardArt: Codable, Hashable, Sendable {
    public var sourceID: String
    /// The art page, and the creature's bounds on it: the part of its picture that isn't transparent.
    public var face: PawnFace
    /// Which picture the page draws the creature with, counting from 0 in drawing order.
    public var imageIndex: Int

    public init(sourceID: String, face: PawnFace, imageIndex: Int) {
        self.sourceID = sourceID
        self.face = face
        self.imageIndex = imageIndex
    }
}

/// A round token printed in an imported PDF, drawn in a pawn's outline: as large as it fits above the name, on
/// white. Its art is kept drawn alone, so nothing printed around it (a dark page, its cut line) shows.
public struct TokenArt: Codable, Hashable, Sendable {
    public var sourceID: String
    /// PNG files in the library's token folder.
    public var frontPicture: String
    /// Nil when the back is the front mirrored.
    public var backPicture: String?

    public init(sourceID: String, frontPicture: String, backPicture: String? = nil) {
        self.sourceID = sourceID
        self.frontPicture = frontPicture
        self.backPicture = backPicture
    }

    /// Every picture file the token uses.
    public var pictures: [String] { [frontPicture] + (backPicture.map { [$0] } ?? []) }
}

/// How a custom image is sized to the pawn.
public enum ArtScaling: String, Codable, CaseIterable, Sendable {
    /// Covers the whole pawn; what overflows is cut off.
    case fill
    /// Shows the whole picture above the name, with white around it.
    case fit

    public var displayName: String {
        switch self {
        case .fill: "Fill Pawn"
        case .fit: "Fit Whole Picture"
        }
    }
}

/// A user's image and how it sits in the pawn's outline.
public struct CustomArt: Codable, Hashable, Sendable {
    /// File name in the library's custom art folder.
    public var imageFile: String
    /// Where the image sits, as a fraction of the room it has to move on each axis (its overflow when filling,
    /// the free space when fitting): (0.5, 0.5) centers it.
    public var focus: CGPoint
    /// Whether the pawn's name is printed at its foot.
    public var showsName: Bool
    public var scaling: ArtScaling

    public init(imageFile: String, focus: CGPoint = CGPoint(x: 0.5, y: 0.5), showsName: Bool = true,
                scaling: ArtScaling = .fill) {
        self.imageFile = imageFile
        self.focus = focus
        self.showsName = showsName
        self.scaling = scaling
    }

    private enum CodingKeys: String, CodingKey { case imageFile, focus, showsName, scaling }

    /// Art saved before `scaling` existed fills the pawn.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        imageFile = try container.decode(String.self, forKey: .imageFile)
        focus = try container.decode(CGPoint.self, forKey: .focus)
        showsName = try container.decode(Bool.self, forKey: .showsName)
        scaling = try container.decodeIfPresent(ArtScaling.self, forKey: .scaling) ?? .fill
    }
}

/// A product a pawn is printed in, and how many copies it prints.
public struct Appearance: Codable, Hashable, Sendable {
    public var sourceID: String
    public var copies: Int
}

/// One piece of pawn art with one name, in one size.
public struct Pawn: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var size: PawnSize
    public var art: PawnArt
    public var fingerprint: ArtFingerprint
    /// Every product printing this art, the first being the one its faces come from. Empty for custom pawns.
    public var appearances: [Appearance]
    /// True while the pawn has a stand-in name because none was printed; renaming clears it.
    public var needsName: Bool
    /// Search keywords for what the art shows, such as "woman", "warrior" and "scimitar".
    public var tags: [String] = []
    /// The model that chose `tags`; empty until the pawn is tagged.
    public var tagModel = ""
    /// A name the model suggests while the pawn needs one (`needsName`); empty until it has looked.
    public var suggestedName = ""
    /// True once the user has corrected `tags`; tagging then leaves them alone.
    public var tagsCorrected = false
    /// The creature's traits from its Battle Card, lowercase, such as "undead" and "zombie"; searched like tags.
    public var traits: [String] = []

    public init(id: UUID = UUID(), name: String, size: PawnSize, art: PawnArt,
                fingerprint: ArtFingerprint = ArtFingerprint(imageDigests: []), appearances: [Appearance] = [],
                needsName: Bool = false) {
        self.id = id
        self.name = name
        self.size = size
        self.art = art
        self.fingerprint = fingerprint
        self.appearances = appearances
        self.needsName = needsName
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, size, art, fingerprint, appearances, needsName, tags, tagModel, suggestedName,
             tagsCorrected, traits
    }

    /// Libraries saved before `needsName` existed read as having every name, before tags as untagged and
    /// without suggested names or corrections, and before Battle Cards without traits.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        size = try container.decode(PawnSize.self, forKey: .size)
        art = try container.decode(PawnArt.self, forKey: .art)
        fingerprint = try container.decode(ArtFingerprint.self, forKey: .fingerprint)
        appearances = try container.decode([Appearance].self, forKey: .appearances)
        needsName = try container.decodeIfPresent(Bool.self, forKey: .needsName) ?? false
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        tagModel = try container.decodeIfPresent(String.self, forKey: .tagModel) ?? ""
        suggestedName = try container.decodeIfPresent(String.self, forKey: .suggestedName) ?? ""
        tagsCorrected = try container.decodeIfPresent(Bool.self, forKey: .tagsCorrected) ?? false
        traits = try container.decodeIfPresent([String].self, forKey: .traits) ?? []
    }

    public var isCustom: Bool {
        if case .custom = art { return true }
        return false
    }
}
