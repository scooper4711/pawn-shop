import Bestiary
import CreatureImport
import Foundation
import PawnShopCore

/// What the item import found.
public struct ItemImportReport: Sendable {
    public var itemCount = 0
    public var spellCount = 0
    /// Items the remaster renamed, whose old names item decks may print.
    public var renameCount = 0
    /// Items per kind, for the report.
    public var kinds: [ItemKind: Int] = [:]
    /// Enricher names that could not be converted, with how many descriptions used each.
    public var unparsedEnrichers: [String: Int] = [:]

    public var markdown: String {
        var lines = ["# Item import", "",
                     "\(itemCount) items, \(spellCount) spells, \(renameCount) remaster renames.", ""]
        lines += ItemKind.allCases.map { "- \($0.displayName): \(kinds[$0] ?? 0)" }
        if !unparsedEnrichers.isEmpty {
            lines += ["", "## Enrichers left as written", ""]
            lines += unparsedEnrichers.sorted { $0.key < $1.key }.map { "- \($0.key): \($0.value)" }
        }
        return lines.joined(separator: "\n") + "\n"
    }
}

/// Imports every Pathfinder and Starfinder item and spell from the pf2e system repository into
/// `<output>/Items/items.json`, with an import report and the licenses the item text is used under.
public struct ItemImporter {
    /// Folders of the equipment packs whose items no player is handed.
    static let skippedFolders: Set<String> = ["virtual-items", "bestiary-items"]
    /// The licenses of the game text: each file in the repository's `static/licenses`, and the name the About
    /// panel titles it by.
    static let licenses = ["ORCLicense.md": "ORC License.md", "OpenGameLicense.md": "Open Game License.md"]

    public var repository: URL
    public var outputDirectory: URL

    public init(repository: URL, outputDirectory: URL) {
        self.repository = repository
        self.outputDirectory = outputDirectory
    }

    @discardableResult
    public func run() throws -> ItemImportReport {
        let localizer = try Localizer(languageDirectory: repository.appendingPathComponent("static/lang"))
        let labels = ConfigLabels(repository: repository, localizer: localizer)
        var reader = ItemReader(localizer: localizer, labels: labels)
        var spellReader = SpellReader(localizer: localizer, labels: labels)
        let items = try readItems(with: &reader)
        let spells = try readSpells(with: &spellReader)
        var report = ItemImportReport(itemCount: items.count, spellCount: spells.count)
        report.kinds = Dictionary(grouping: items + spells, by: \.kind).mapValues(\.count)
        let unparsed = reader.unparsedEnrichers + spellReader.unparsedEnrichers
        report.unparsedEnrichers = Dictionary(unparsed.map { ($0, 1) }, uniquingKeysWith: +)
        let renames = RenameReader.renames(in: repository)
        report.renameCount = renames.count
        try write(items + spells, renames: renames, report: report)
        return report
    }

    /// The items of both games, sorted by game, name and id, so the same input gives the same output.
    func readItems(with reader: inout ItemReader) throws -> [CatalogItem] {
        try read(pack: "equipment") { reader.item(from: $0, game: $1) }
    }

    /// The spells of both games, in the same order as the items.
    func readSpells(with reader: inout SpellReader) throws -> [CatalogItem] {
        try read(pack: "spells") { reader.spell(from: $0, game: $1) }
    }

    /// The documents of both games' packs in the folder `pack` that `read` turns into cards.
    private func read(pack name: String,
                      _ read: (JSONValue, PawnShopCore.Game) -> CatalogItem?) throws -> [CatalogItem] {
        let scanner = PackScanner(repository: repository)
        var items: [CatalogItem] = []
        for game in Bestiary.Game.allCases {
            for pack in try scanner.packs(of: game, type: "Item") where pack.name == name {
                for file in scanner.documentFiles(in: pack) where !isSkipped(file) {
                    if let item = read(try JSONValue(contentsOf: file), Self.game(game)) { items.append(item) }
                }
            }
        }
        return items.sorted { ($0.game.rawValue, $0.name, $0.id) < ($1.game.rawValue, $1.name, $1.id) }
    }

    private func isSkipped(_ file: URL) -> Bool {
        file.pathComponents.contains { Self.skippedFolders.contains($0) }
    }

    private func write(_ items: [CatalogItem], renames: [String: String], report: ItemImportReport) throws {
        let folder = outputDirectory.appendingPathComponent("Items", isDirectory: true)
        let licenses = folder.appendingPathComponent("Licenses", isDirectory: true)
        try? FileManager.default.removeItem(at: folder)
        try FileManager.default.createDirectory(at: licenses, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(items).write(to: folder.appendingPathComponent("items.json"), options: .atomic)
        try encoder.encode(renames).write(to: folder.appendingPathComponent(ItemCatalog.renamesFile), options: .atomic)
        try report.markdown.write(to: folder.appendingPathComponent("import-report.md"), atomically: true,
                                  encoding: .utf8)
        for (license, title) in Self.licenses.sorted(by: { $0.key < $1.key }) {
            let source = repository.appendingPathComponent("static/licenses/\(license)")
            try FileManager.default.copyItem(at: source, to: licenses.appendingPathComponent(title))
        }
    }

    private static func game(_ game: Bestiary.Game) -> PawnShopCore.Game {
        game == .starfinder ? .starfinder : .pathfinder
    }
}
