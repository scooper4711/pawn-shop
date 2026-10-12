import Bestiary
import CreatureImport
import Foundation
import PawnShopCore

/// What the item import found.
public struct ItemImportReport: Sendable {
    public var itemCount = 0
    /// Items per kind, for the report.
    public var kinds: [ItemKind: Int] = [:]
    /// Enricher names that could not be converted, with how many descriptions used each.
    public var unparsedEnrichers: [String: Int] = [:]

    public var markdown: String {
        var lines = ["# Item import", "", "\(itemCount) items.", ""]
        lines += ItemKind.allCases.map { "- \($0.displayName): \(kinds[$0] ?? 0)" }
        if !unparsedEnrichers.isEmpty {
            lines += ["", "## Enrichers left as written", ""]
            lines += unparsedEnrichers.sorted { $0.key < $1.key }.map { "- \($0.key): \($0.value)" }
        }
        return lines.joined(separator: "\n") + "\n"
    }
}

/// Imports every Pathfinder and Starfinder item from the pf2e system repository into
/// `<output>/Items/items.json`, with an import report and the licenses the item text is used under.
public struct ItemImporter {
    /// Folders of the equipment packs whose items no player is handed.
    static let skippedFolders: Set<String> = ["virtual-items", "bestiary-items"]
    /// The licenses of the game text, in the repository's `static/licenses`.
    static let licenses = ["ORCLicense.md", "OpenGameLicense.md"]

    public var repository: URL
    public var outputDirectory: URL

    public init(repository: URL, outputDirectory: URL) {
        self.repository = repository
        self.outputDirectory = outputDirectory
    }

    @discardableResult
    public func run() throws -> ItemImportReport {
        let localizer = try Localizer(languageDirectory: repository.appendingPathComponent("static/lang"))
        var reader = ItemReader(localizer: localizer,
                                labels: ConfigLabels(repository: repository, localizer: localizer))
        let items = try readItems(with: &reader)
        var report = ItemImportReport(itemCount: items.count)
        report.kinds = Dictionary(grouping: items, by: \.kind).mapValues(\.count)
        report.unparsedEnrichers = Dictionary(reader.unparsedEnrichers.map { ($0, 1) }, uniquingKeysWith: +)
        try write(items, report: report)
        return report
    }

    /// The items of both games, sorted by game, name and id, so the same input gives the same output.
    func readItems(with reader: inout ItemReader) throws -> [CatalogItem] {
        let scanner = PackScanner(repository: repository)
        var items: [CatalogItem] = []
        for game in Bestiary.Game.allCases {
            for pack in try scanner.packs(of: game, type: "Item") where pack.name == "equipment" {
                for file in scanner.documentFiles(in: pack) where !isSkipped(file) {
                    if let item = reader.item(from: try JSONValue(contentsOf: file), game: Self.game(game)) {
                        items.append(item)
                    }
                }
            }
        }
        return items.sorted { ($0.game.rawValue, $0.name, $0.id) < ($1.game.rawValue, $1.name, $1.id) }
    }

    private func isSkipped(_ file: URL) -> Bool {
        file.pathComponents.contains { Self.skippedFolders.contains($0) }
    }

    private func write(_ items: [CatalogItem], report: ItemImportReport) throws {
        let folder = outputDirectory.appendingPathComponent("Items", isDirectory: true)
        let licenses = folder.appendingPathComponent("Licenses", isDirectory: true)
        try? FileManager.default.removeItem(at: folder)
        try FileManager.default.createDirectory(at: licenses, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(items).write(to: folder.appendingPathComponent("items.json"), options: .atomic)
        try report.markdown.write(to: folder.appendingPathComponent("import-report.md"), atomically: true,
                                  encoding: .utf8)
        for license in Self.licenses {
            let source = repository.appendingPathComponent("static/licenses/\(license)")
            try FileManager.default.copyItem(at: source, to: licenses.appendingPathComponent(license))
        }
    }

    private static func game(_ game: Bestiary.Game) -> PawnShopCore.Game {
        game == .starfinder ? .starfinder : .pathfinder
    }
}
