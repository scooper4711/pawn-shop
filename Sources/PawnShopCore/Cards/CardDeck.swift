import Foundation

/// A deck of Paizo Battle Cards: one PDF holding both sides of every card, or a pair of PDFs, one with the
/// fronts (stat blocks) and one with the backs (art).
public struct CardDeck: Equatable, Sendable {
    /// The PDF with the art, which the library keeps.
    public let artFile: URL
    /// The PDF with the stat blocks when the deck comes as two; nil when `artFile` holds both sides.
    public let statsFile: URL?

    /// Matches the word naming a side in a two-file deck: "… FRONT.pdf", "… FRONTS.pdf", "… BACKS.pdf".
    private static let sideWord = #"(?i)\b(FRONT|BACK)S?\b"#

    /// The deck `url` belongs to, or nil when it isn't Battle Cards: its name, or the folders it is in, must say
    /// "Battle Cards". Either PDF of a two-file deck gives the whole deck.
    public static func containing(_ url: URL) -> CardDeck? {
        let folders = url.deletingLastPathComponent().pathComponents.suffix(2)
        guard ([url.lastPathComponent] + folders).contains(where: isDeckName) else { return nil }
        guard let side = side(of: url), let partner = partner(of: url) else {
            return CardDeck(artFile: url, statsFile: nil)
        }
        return side == "BACK" ? CardDeck(artFile: url, statsFile: partner)
                              : CardDeck(artFile: partner, statsFile: url)
    }

    /// The deck's product name: from the folder Scrollkeeper keeps it in, when there is one ("Starfinder Alien
    /// Archive 1 & 2 Battle Cards"), or else from the file name without its side and reference code.
    public var title: String {
        let folders = artFile.deletingLastPathComponent().pathComponents.suffix(2).reversed()
        let named = folders.map(Self.withoutDownloadWords).filter(Self.isDeckName)
        if let product = named.first(where: { $0.hasPrefix("Pathfinder") || $0.hasPrefix("Starfinder") }) {
            return product
        }
        var title = (artFile.lastPathComponent as NSString).deletingPathExtension
        title = title.replacingOccurrences(of: Self.sideWord, with: "", options: .regularExpression)
        return Self.withoutDownloadWords(PawnSource.title(fromFileName: title + ".pdf"))
    }

    private static func isDeckName(_ name: String) -> Bool {
        name.range(of: #"battle ?cards?"#, options: [.regularExpression, .caseInsensitive]) != nil
    }

    /// The name without the words Paizo's downloads add: "… Battle Cards (Download) - PDFs" becomes
    /// "… Battle Cards".
    private static func withoutDownloadWords(_ name: String) -> String {
        name.replacingOccurrences(of: #"(\s*\(Download\))?(\s*[-:]\s*PDFs?)?\s*[-:]?$"#, with: "",
                                  options: [.regularExpression, .caseInsensitive])
            .trimmingCharacters(in: .whitespaces)
    }

    /// "FRONT" or "BACK" when the file name names a side, else nil.
    private static func side(of url: URL) -> String? {
        let name = url.lastPathComponent
        return name.range(of: sideWord, options: .regularExpression).map { name[$0].uppercased() }
            .map { $0.hasPrefix("FRONT") ? "FRONT" : "BACK" }
    }

    /// The PDF beside `url` whose name differs only in naming the other side.
    private static func partner(of url: URL) -> URL? {
        let key = sideless(url.lastPathComponent)
        let folder = url.deletingLastPathComponent()
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        return names.first { name in
            name != url.lastPathComponent && name.lowercased().hasSuffix(".pdf") && sideless(name) == key
                && side(of: URL(fileURLWithPath: name)) != side(of: url)
        }.map { folder.appendingPathComponent($0) }
    }

    private static func sideless(_ name: String) -> String {
        name.replacingOccurrences(of: sideWord, with: "", options: .regularExpression).lowercased()
    }
}
