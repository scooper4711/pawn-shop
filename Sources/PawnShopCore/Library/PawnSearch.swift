import Foundation

/// What to look for in the library.
public struct PawnQuery: Equatable, Sendable {
    /// Words that must all appear in the pawn's name or one of its products' titles.
    public var text = ""
    /// Sizes to show; empty shows every size.
    public var sizes: Set<PawnSize> = []
    /// Games to show; empty shows both.
    public var games: Set<Game> = []
    /// Products to show; empty shows every product.
    public var sourceIDs: Set<String> = []
    /// Show only (or hide) the user's own pawns; nil shows both.
    public var custom: Bool?
    /// Show only pawns still waiting for a name.
    public var needingNamesOnly = false

    public init(text: String = "", sizes: Set<PawnSize> = [], games: Set<Game> = [], sourceIDs: Set<String> = [],
                custom: Bool? = nil, needingNamesOnly: Bool = false) {
        self.text = text
        self.sizes = sizes
        self.games = games
        self.sourceIDs = sourceIDs
        self.custom = custom
        self.needingNamesOnly = needingNamesOnly
    }
}

public extension PawnLibrary {
    /// The pawns matching `query`, by name, so pawns sharing a name sit together, then by product.
    func search(_ query: PawnQuery) -> [Pawn] {
        let words = query.text.split(whereSeparator: \.isWhitespace).map(String.init)
        return pawns.filter { matches($0, query: query, words: words) }
            .sorted { first, second in
                let order = first.name.localizedStandardCompare(second.name)
                return order == .orderedSame ? sourceTitle(of: first) < sourceTitle(of: second)
                                             : order == .orderedAscending
            }
    }

    /// Pawns still waiting for a name, in library order, so a review picks up where it stopped.
    var pawnsNeedingNames: [Pawn] { pawns.filter(\.needsName) }

    /// The title of the product a pawn's faces come from, or "Custom".
    func sourceTitle(of pawn: Pawn) -> String {
        guard case .pdf(let sourceID, _, _) = pawn.art else { return "Custom" }
        return source(id: sourceID)?.title ?? "Unknown product"
    }

    /// The short title of the product a pawn's faces come from, or "Custom".
    func shortSourceTitle(of pawn: Pawn) -> String {
        guard case .pdf(let sourceID, _, _) = pawn.art else { return "Custom" }
        return source(id: sourceID)?.shortTitle ?? "Unknown product"
    }

    /// Every product title a pawn appears in.
    func sourceTitles(of pawn: Pawn) -> [String] {
        pawn.isCustom ? ["Custom"] : pawn.appearances.compactMap { source(id: $0.sourceID)?.title }
    }

    private func matches(_ pawn: Pawn, query: PawnQuery, words: [String]) -> Bool {
        guard query.sizes.isEmpty || query.sizes.contains(pawn.size), !query.needingNamesOnly || pawn.needsName,
              query.custom.map({ $0 == pawn.isCustom }) ?? true
        else { return false }
        let sources = pawn.appearances.compactMap { source(id: $0.sourceID) }
        guard query.sourceIDs.isEmpty || sources.contains(where: { query.sourceIDs.contains($0.id) }),
              query.games.isEmpty || pawn.isCustom || sources.contains(where: { query.games.contains($0.game) })
        else { return false }
        let haystack = ([pawn.name] + sourceTitles(of: pawn)).joined(separator: " ")
        return words.allSatisfy { haystack.range(of: $0, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
    }
}

/// Finds the pawn PDFs Scrollkeeper has downloaded.
public enum ScrollkeeperScanner {
    /// `~/Library/Application Support/Scrollkeeper/Files`.
    public static var defaultFolder: URL {
        URL.applicationSupportDirectory.appendingPathComponent("Scrollkeeper/Files", isDirectory: true)
    }

    /// PDFs under `folder` whose file name mentions pawns, sorted by name.
    public static func pawnPDFs(in folder: URL = defaultFolder) -> [URL] {
        let files = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL } ?? []
        return files.filter { url in
            url.pathExtension.lowercased() == "pdf" && url.lastPathComponent.localizedCaseInsensitiveContains("pawn")
        }.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }
}
