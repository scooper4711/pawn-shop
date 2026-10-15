import Bestiary
import CreatureImport
import Foundation
import PawnShopCore

/// Reads one item document of the pf2e system's equipment packs into a `CatalogItem`.
public struct ItemReader {
    private var text: RulesTextConverter
    private let labels: ConfigLabels

    public init(localizer: Localizer, labels: ConfigLabels) {
        text = RulesTextConverter(localizer: localizer)
        self.labels = labels
    }

    /// Enricher names the descriptions used that could not be converted, for the import report.
    public var unparsedEnrichers: [String] { text.unparsedEnrichers }

    /// The item, or nil for a document that isn't a physical item or has no name.
    public mutating func item(from document: JSONValue, game: PawnShopCore.Game) -> CatalogItem? {
        let name = document["name"].string
        guard let kind = Self.kind(of: document["type"].string), !name.isEmpty else { return nil }
        let system = document["system"]
        var item = CatalogItem(id: "\(game.rawValue)/\(document["_id"].string)", game: game, name: name,
                               level: system[path: "level.value"].int, kind: kind)
        item.traits = labels.traits(system["traits"])
        item.description = text.plainDescription(of: system, values: .level(item.level))
        item.stats = ItemStatRows(system: system, game: game, labels: labels).rows(for: kind)
        item.source = system[path: "publication.title"].string
        return item
    }

    /// The kind of an item type; a kit counts as gear, and anything else, such as a spell, is no item.
    static func kind(of type: String) -> ItemKind? {
        type == "kit" ? .equipment : ItemKind(rawValue: type).flatMap { ItemKind.itemKinds.contains($0) ? $0 : nil }
    }
}

/// Prepares a description's HTML for conversion: tables are left out, since they repeat the stats or list
/// variants the card has no room for, and so are links into the effect packs ("Spell Effect: Acid Grip"), which
/// only apply rules in Foundry.
enum DescriptionCleaner {
    static func cleaned(_ html: String) -> String {
        let effectLink = #"@UUID\[Compendium\.[a-z0-9]+\.[a-z0-9-]*effects[a-z0-9-]*\.[^\]]*\](\{[^}]*\})?"#
        return html
            .replacingOccurrences(of: #"<table[\s\S]*?</table>"#, with: "",
                                  options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: effectLink, with: "", options: .regularExpression)
    }
}

extension RulesTextConverter {
    /// A document's description as card text: cleaned, with its formulas worked out from `values` (Tabletop
    /// Kit's R4.4), and back to plain text with `**bold**`, `*italic*`, `---` and the action glyphs.
    mutating func plainDescription(of system: JSONValue, values: FormulaValues) -> String {
        let html = DescriptionCleaner.cleaned(system[path: "description.value"].string)
        return StatBlockText.plainText(convert(html, values: values)).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
