import Foundation

/// Finds the art an imported item deck prints for a catalog item, by name: the same words in any order, so the
/// deck's "Lesser Acid Flask" is the catalog's "Acid Flask (Lesser)", or else the same words without the grade,
/// so "Healing Potion (Minor)" finds a deck's "Healing Potion".
public struct ItemArtMatcher: Sendable {
    /// Words naming an item's grade rather than the item.
    static let gradeWords: Set<String> = ["minor", "lesser", "moderate", "greater", "major", "true", "standard"]

    private let byWords: [[String]: ItemArtwork]
    private let byBaseWords: [[String]: ItemArtwork]

    public init(artwork: [ItemArtwork]) {
        byWords = Dictionary(artwork.map { (Self.words(of: $0.name), $0) }) { first, _ in first }
        byBaseWords = Dictionary(artwork.map { (Self.baseWords(of: $0.name), $0) }) { first, _ in first }
    }

    /// The art printed under the item's name, or else under its name without its grade; nil when no deck
    /// prints it.
    public func artwork(for item: CatalogItem) -> ItemArtwork? {
        byWords[Self.words(of: item.name)] ?? byBaseWords[Self.baseWords(of: item.name)]
    }

    /// The name's words, lowercase and without accents or punctuation, sorted.
    static func words(of name: String) -> [String] {
        name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US"))
            .replacingOccurrences(of: "'", with: "")
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .sorted()
    }

    private static func baseWords(of name: String) -> [String] {
        words(of: name).filter { !gradeWords.contains($0) }
    }
}

public extension PawnLibrary {
    /// Finds the art the library's item decks print for catalog items.
    var itemArtMatcher: ItemArtMatcher { ItemArtMatcher(artwork: itemArt) }
}
