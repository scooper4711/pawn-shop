import Foundation

/// The library file's contents.
struct StoredLibrary: Codable {
    var version = 1
    var sources: [PawnSource]
    var pawns: [Pawn]
    var itemArt: [ItemArtwork] = []

    init(sources: [PawnSource], pawns: [Pawn], itemArt: [ItemArtwork] = []) {
        self.sources = sources
        self.pawns = pawns
        self.itemArt = itemArt
    }

    private enum CodingKeys: String, CodingKey { case version, sources, pawns, itemArt }

    /// Libraries saved before item decks were read have no item art.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        sources = try container.decode([PawnSource].self, forKey: .sources)
        pawns = try container.decode([Pawn].self, forKey: .pawns)
        itemArt = try container.decodeIfPresent([ItemArtwork].self, forKey: .itemArt) ?? []
    }
}
