import Foundation

/// The contents of Pawn Shop's library file before the shared library (`library.json`), read once to move it in.
struct StoredLibrary: Codable {
    /// Version 2 keys extracted pawns by their art (`ArtKey`); version 1 gave them random UUIDs.
    static let currentVersion = 2

    var version = StoredLibrary.currentVersion
    var sources: [PawnSource]
    var pawns: [Pawn]
    var itemArt: [ItemArtwork] = []
    /// Other IDs pawns answer to, mapped to their own: the random UUIDs of version 1, and the keys of other prints
    /// merged into them.
    var aliases: [UUID: UUID] = [:]

    init(sources: [PawnSource], pawns: [Pawn], itemArt: [ItemArtwork] = [], aliases: [UUID: UUID] = [:]) {
        self.sources = sources
        self.pawns = pawns
        self.itemArt = itemArt
        self.aliases = aliases
    }

    static func read(from file: URL) throws -> StoredLibrary {
        do {
            return try JSONDecoder().decode(StoredLibrary.self, from: Data(contentsOf: file))
        } catch {
            throw PawnLibraryError.unreadableFile("\(file.lastPathComponent): \(error.localizedDescription)")
        }
    }

    private enum CodingKeys: String, CodingKey { case version, sources, pawns, itemArt, aliases }

    /// Libraries saved before item decks were read have no item art, and before version 2 no aliases.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        sources = try container.decode([PawnSource].self, forKey: .sources)
        pawns = try container.decode([Pawn].self, forKey: .pawns)
        itemArt = try container.decodeIfPresent([ItemArtwork].self, forKey: .itemArt) ?? []
        let stored = try container.decodeIfPresent([String: UUID].self, forKey: .aliases) ?? [:]
        aliases = Dictionary(uniqueKeysWithValues: stored.compactMap { key, value in
            UUID(uuidString: key).map { ($0, value) }
        })
    }

    /// Aliases are saved as an object keyed by UUID string; a dictionary keyed by `UUID` would encode as an array.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(sources, forKey: .sources)
        try container.encode(pawns, forKey: .pawns)
        try container.encode(itemArt, forKey: .itemArt)
        try container.encode(Dictionary(uniqueKeysWithValues: aliases.map { ($0.uuidString, $1) }), forKey: .aliases)
    }
}
