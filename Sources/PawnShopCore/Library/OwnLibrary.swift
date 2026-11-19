import Foundation

/// What stays Pawn Shop's own beside the shared art library (shared libraries R3.5): custom pawns, the pawns read
/// from PDFs that were removed from Pawn Shop only, and the files imported, to recognize them without hashing them.
struct OwnLibrary: Codable, Equatable {
    static let fileName = "pawn-shop.json"
    static let currentVersion = 1

    /// A file imported before, by its path, with its size then and its SHA-256.
    struct ImportedFile: Codable, Equatable {
        var byteCount: Int
        var digest: String
    }

    var version = OwnLibrary.currentVersion
    var customPawns: [Pawn] = []
    /// IDs of pawns read from PDFs that the user removed: hidden in Pawn Shop, kept for the other apps.
    var hidden: Set<UUID> = []
    var importedFiles: [String: ImportedFile] = [:]
    /// Sources moved in that are read again from their original files, by ID, with their paths (R2.16).
    var readAgain: [String: String] = [:]
    /// When the user last changed each custom pawn, by its ID, in seconds since the reference date: of two
    /// devices' changes to one pawn, the later wins (R10.2). A pawn made before changes were timed has none.
    var customPawnsModified: [String: Double] = [:]

    init() {}

    private enum CodingKeys: String, CodingKey {
        case version, customPawns, hidden, importedFiles, readAgain, customPawnsModified
    }

    /// A file saved before a field existed reads as having none of it.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? OwnLibrary.currentVersion
        customPawns = try container.decodeIfPresent([Pawn].self, forKey: .customPawns) ?? []
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
