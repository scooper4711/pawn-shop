import Foundation

/// Finds the art an imported item deck prints for a catalog item, by name: the same words in any order, so the
/// deck's "Lesser Acid Flask" is the catalog's "Acid Flask (Lesser)", or else the same words without the grade,
/// so "Healing Potion (Minor)" finds a deck's "Healing Potion". Art a deck names as before the remaster is found
/// under its new name too: a deck's "Thunderstone" is the catalog's "Blasting Stone (Lesser)", and through the
/// grade the other blasting stones'.
public struct ItemArtMatcher: Sendable {
    /// Words naming an item's grade rather than the item.
    static let gradeWords: Set<String> = ["minor", "lesser", "moderate", "greater", "major", "true", "standard"]

    private let byWords: [[String]: ItemArtwork]
    private let byBaseWords: [[String]: ItemArtwork]

    /// `renames` maps old names to the remaster's (`ItemCatalog.renames`).
    public init(artwork: [ItemArtwork], renames: [String: String] = [:]) {
        let newNames = Dictionary(renames.map { (Self.words(of: $0.key), $0.value) }) { first, _ in first }
        // Art under its own name comes first, so a renamed one never hides it.
        let named = artwork.map { ($0.name, $0) }
            + artwork.compactMap { art in newNames[Self.words(of: art.name)].map { ($0, art) } }
        byWords = Dictionary(named.map { (Self.words(of: $0.0), $0.1) }) { first, _ in first }
        byBaseWords = Dictionary(named.map { (Self.baseWords(of: $0.0), $0.1) }) { first, _ in first }
    }

    /// The art printed under the item's name, or else under its name without its grade; nil when no deck
    /// prints it.
    public func artwork(for item: CatalogItem) -> ItemArtwork? {
        byWords[Self.words(of: item.name)] ?? byBaseWords[Self.baseWords(of: item.name)]
    }

    /// The name's words, lowercase and without accents or punctuation, sorted. Apostrophes, straight in the pf2e
    /// system and curly on the cards, are dropped rather than splitting the word.
    static func words(of name: String) -> [String] {
        name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US"))
            .replacingOccurrences(of: #"['’]"#, with: "", options: .regularExpression)
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .sorted()
    }

    private static func baseWords(of name: String) -> [String] {
        words(of: name).filter { !gradeWords.contains($0) }
    }
}
