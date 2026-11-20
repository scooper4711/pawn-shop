import CoreGraphics
import Foundation

/// What is Pawn Shop's own about a custom creature's pawn (R3.6, shared libraries R4.8): how its art sits on the
/// pawn, and its tags. A creature without any, such as one made in Turnkeeper, has these defaults.
struct CustomPawnSettings: Codable, Equatable {
    /// Where the image sits (`CustomArt.focus`).
    var focus = CGPoint(x: 0.5, y: 0.5)
    var showsName = true
    var scaling = ArtScaling.fill
    var tags: [String] = []
    var tagModel = ""
    var tagsCorrected = false

    /// The settings with what `pawn` says: its tags, and its art's placement when it is drawn from the user's
    /// image. Art chosen from the library has no placement, so the one here stays.
    func taking(_ pawn: Pawn) -> CustomPawnSettings {
        var settings = self
        if case .custom(let art) = pawn.art {
            settings.focus = art.focus
            settings.showsName = art.showsName
            settings.scaling = art.scaling
        }
        settings.tags = pawn.tags
        settings.tagModel = pawn.tagModel
        settings.tagsCorrected = pawn.tagsCorrected
        return settings
    }

    /// The user's image as these settings place it.
    func art(imageFile: String) -> CustomArt {
        CustomArt(imageFile: imageFile, focus: focus, showsName: showsName, scaling: scaling)
    }
}

/// What stays Pawn Shop's own beside the shared libraries (shared libraries R3.5): custom pawns' settings, the
/// pawns removed from Pawn Shop only, and the files imported, to recognize them without hashing them.
struct OwnLibrary: Codable, Equatable {
    static let fileName = "pawn-shop.json"
    static let currentVersion = 1

    /// A file imported before, by its path, with its size then and its SHA-256.
    struct ImportedFile: Codable, Equatable {
        var byteCount: Int
        var digest: String
    }

    var version = OwnLibrary.currentVersion
    /// The custom pawns from before they became custom creatures, until they move in (R3.7).
    var customPawns: [Pawn] = []
    /// By the custom creature's ID.
    var pawnSettings: [String: CustomPawnSettings] = [:]
    /// IDs of the pawns the user removed that the other apps keep: hidden in Pawn Shop (R2.5).
    var hidden: Set<UUID> = []
    var importedFiles: [String: ImportedFile] = [:]
    /// Sources moved in that are read again from their original files, by ID, with their paths (R2.16).
    var readAgain: [String: String] = [:]
    /// When the user last changed each custom pawn's settings, by its ID, in seconds since the reference date: of
    /// two devices' changes to one pawn, the later wins (R10.2). A pawn made before changes were timed has none.
    var customPawnsModified: [String: Double] = [:]

    init() {}

    private enum CodingKeys: String, CodingKey {
        case version, customPawns, pawnSettings, hidden, importedFiles, readAgain, customPawnsModified
    }

    /// A file saved before a field existed reads as having none of it.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? OwnLibrary.currentVersion
        customPawns = try container.decodeIfPresent([Pawn].self, forKey: .customPawns) ?? []
        pawnSettings = try container.decodeIfPresent([String: CustomPawnSettings].self, forKey: .pawnSettings) ?? [:]
        hidden = try container.decodeIfPresent(Set<UUID>.self, forKey: .hidden) ?? []
        importedFiles = try container.decodeIfPresent([String: ImportedFile].self, forKey: .importedFiles) ?? [:]
        readAgain = try container.decodeIfPresent([String: String].self, forKey: .readAgain) ?? [:]
        customPawnsModified = try container.decodeIfPresent([String: Double].self, forKey: .customPawnsModified)
            ?? [:]
    }

    /// The library saved in `folder`, or an empty one.
    static func read(from folder: URL) throws -> OwnLibrary {
        let file = folder.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: file.path) else { return OwnLibrary() }
        do {
            return try JSONDecoder().decode(OwnLibrary.self, from: Data(contentsOf: file))
        } catch {
            throw PawnLibraryError.unreadableFile("\(fileName): \(error.localizedDescription)")
        }
    }

    func save(to folder: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        do {
            try encoder.encode(self).write(to: folder.appendingPathComponent(Self.fileName), options: .atomic)
        } catch {
            throw PawnLibraryError.saveFailed("\(Self.fileName): \(error.localizedDescription)")
        }
    }
}
