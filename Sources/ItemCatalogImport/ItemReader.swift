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
        item.traits = traits(system["traits"])
        let html = DescriptionCleaner(system: system).cleaned(system[path: "description.value"].string)
        item.description = StatBlockText.plainText(text.convert(html))
        item.stats = ItemStatRows(system: system, game: game, labels: labels).rows(for: kind)
        item.source = system[path: "publication.title"].string
        return item
    }

    /// The kind of an item type; a kit counts as gear.
    static func kind(of type: String) -> ItemKind? {
        type == "kit" ? .equipment : ItemKind(rawValue: type)
    }

    /// The rarity first when it isn't common, then the traits.
    private func traits(_ traits: JSONValue) -> [String] {
        let rarity = traits["rarity"].string
        let rarityLabel = rarity.isEmpty || rarity == "common" ? [] : [ConfigLabels.titleCase(rarity)]
        return rarityLabel + traits["value"].strings.map(labels.trait)
    }
}

/// Prepares an item's description HTML for conversion: tables are left out, since they repeat the stats or list
/// variants the card has no room for, and formulas referring to the item's own data are worked out, so
/// "1d4+@item.system.damage.dice" prints as "1d4+1".
struct DescriptionCleaner {
    /// References to the wielder, which a card can only describe.
    static let actorReferences = [
        "@actor.level": "your level",
        "@actor.abilities.str.mod": "your Strength modifier"
    ]

    let system: JSONValue

    func cleaned(_ html: String) -> String {
        var text = html.replacingOccurrences(of: #"<table[\s\S]*?</table>"#, with: "",
                                             options: [.regularExpression, .caseInsensitive])
        for (reference, words) in Self.actorReferences {
            text = text.replacingOccurrences(of: reference, with: words)
        }
        return resolvingItemReferences(in: text)
    }

    /// "@item.level" is the item's level; "@item.system.<path>" a value of its data.
    private func resolvingItemReferences(in text: String) -> String {
        text.replacing(/@item\.((?:system\.)?[A-Za-z.]+[A-Za-z])/) { match in
            let path = String(match.output.1)
            let value = path == "level" ? system[path: "level.value"] : system[path: String(path.dropFirst(7))]
            return value.string.isEmpty ? String(match.output.0) : value.string
        }
    }
}
