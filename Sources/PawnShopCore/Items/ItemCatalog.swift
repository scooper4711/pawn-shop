import Foundation

/// What to look for in the item catalog.
public struct ItemQuery: Equatable, Sendable {
    /// Words that must all appear in the item's name or source, or begin one of its traits' words.
    public var text = ""
    /// Games to show; empty shows both.
    public var games: Set<Game> = []
    /// Kinds to show; empty shows every kind.
    public var kinds: Set<ItemKind> = []
    /// The levels to show.
    public var levels: ClosedRange<Int> = ItemCatalog.levels

    public init(text: String = "", games: Set<Game> = [], kinds: Set<ItemKind> = [],
                levels: ClosedRange<Int> = ItemCatalog.levels) {
        self.text = text
        self.games = games
        self.kinds = kinds
        self.levels = levels
    }
}

/// Every Pathfinder and Starfinder item, from `Generated/Items/items.json` (written by `ItemImport`).
public struct ItemCatalog: Sendable {
    /// The levels items have.
    public static let levels = 0...30

    /// The file beside `items.json` with the remaster's renames (see `renames`).
    public static let renamesFile = "renames.json"

    public let items: [CatalogItem]
    /// Old names of items the remaster renamed, with their new names: item decks printed before it use the old.
    public let renames: [String: String]
    private let indexes: [String: Int]

    public init(items: [CatalogItem], renames: [String: String] = [:]) {
        self.items = items
        self.renames = renames
        indexes = Dictionary(items.enumerated().map { ($1.id, $0) }) { first, _ in first }
    }

    /// The catalog in `file`, with the renames beside it; empty when there is none or it can't be read, as in a
    /// build without `Generated`.
    public init(contentsOf file: URL) {
        let renamesFile = file.deletingLastPathComponent().appendingPathComponent(Self.renamesFile)
        self.init(items: Self.decoded([CatalogItem].self, from: file) ?? [],
                  renames: Self.decoded([String: String].self, from: renamesFile) ?? [:])
    }

    /// The catalog bundled with the app, or else an empty one.
    public static func bundled() -> ItemCatalog {
        guard let folder = GeneratedResources.folder else { return ItemCatalog(items: []) }
        return ItemCatalog(contentsOf: folder.appendingPathComponent("Items/items.json"))
    }

    public func item(id: String) -> CatalogItem? { indexes[id].map { items[$0] } }

    /// Finds the art the library's item decks print for these items, by their names or their names before the
    /// remaster.
    public func artMatcher(for library: PawnLibrary) -> ItemArtMatcher {
        ItemArtMatcher(artwork: library.itemArt, renames: renames)
    }

    /// The items matching `query`, by name, then level.
    public func search(_ query: ItemQuery) -> [CatalogItem] {
        let words = query.text.split(whereSeparator: \.isWhitespace).map(String.init)
        return items.filter { matches($0, query: query, words: words) }
            .sorted { first, second in
                let order = first.name.localizedStandardCompare(second.name)
                return order == .orderedSame ? first.level < second.level : order == .orderedAscending
            }
    }

    private static func decoded<Value: Decodable>(_ type: Value.Type, from file: URL) -> Value? {
        (try? Data(contentsOf: file)).flatMap { try? JSONDecoder().decode(type, from: $0) }
    }

    private func matches(_ item: CatalogItem, query: ItemQuery, words: [String]) -> Bool {
        guard query.games.isEmpty || query.games.contains(item.game),
              query.kinds.isEmpty || query.kinds.contains(item.kind), query.levels.contains(item.level)
        else { return false }
        let haystack = item.name + " " + item.source
        let traitWords = item.traits.flatMap { $0.split(whereSeparator: \.isWhitespace) }
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        return words.allSatisfy { word in
            haystack.range(of: word, options: options) != nil
                || traitWords.contains { $0.range(of: word, options: options.union(.anchored)) != nil }
        }
    }
}

/// The files `make items` builds into `Generated/` and the app bundles: the item catalog and the Rexard art of
/// the cards.
public enum GeneratedResources {
    /// `PAWN_SHOP_GENERATED` when set, as when running from the command line, or else the bundle's `Generated`
    /// folder; nil when there is neither.
    public static var folder: URL? {
        let environment = ProcessInfo.processInfo.environment["PAWN_SHOP_GENERATED"].map(URL.init(fileURLWithPath:))
        let bundled = Bundle.main.resourceURL?.appendingPathComponent("Generated", isDirectory: true)
        return [environment, bundled].compactMap { $0 }.first { PawnLibrary.isFolder($0) }
    }
}
