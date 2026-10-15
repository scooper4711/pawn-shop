import Bestiary
import CreatureImport
import Foundation
import PawnShopCore

/// Reads one document of the pf2e system's spell packs into a `CatalogItem` that prints as a spell card (R9).
public struct SpellReader {
    private var text: RulesTextConverter
    private let labels: ConfigLabels

    public init(localizer: Localizer, labels: ConfigLabels) {
        text = RulesTextConverter(localizer: localizer)
        self.labels = labels
    }

    /// Enricher names the descriptions used that could not be converted, for the import report.
    public var unparsedEnrichers: [String] { text.unparsedEnrichers }

    /// The spell, or nil for a document that isn't a spell or has no name.
    public mutating func spell(from document: JSONValue, game: PawnShopCore.Game) -> CatalogItem? {
        let name = document["name"].string
        guard document["type"].string == "spell", !name.isEmpty else { return nil }
        let system = document["system"]
        var spell = CatalogItem(id: "\(game.rawValue)/\(document["_id"].string)", game: game, name: name,
                                level: system[path: "level.value"].int, kind: Self.kind(of: system))
        spell.traits = labels.traits(system["traits"])
        spell.traditions = system[path: "traits.traditions"].strings
        spell.description = text.plainDescription(of: system, values: .level(spell.level))
        spell.stats = SpellStatRows(system: system).rows
        spell.source = system[path: "publication.title"].string
        return spell
    }

    /// A cantrip first, as a focus cantrip is a cantrip; then a focus spell, a ritual or a spell.
    static func kind(of system: JSONValue) -> ItemKind {
        let traits = system[path: "traits.value"].strings
        if traits.contains("cantrip") { return .cantrip }
        if traits.contains("focus") { return .focus }
        return system["ritual"].isNull ? .spell : .ritual
    }
}

/// A spell's stats in the books' order: Traditions, Cast, Cost, Requirements, a ritual's casters and checks,
/// then Range, Area, Targets, Defense and Duration (Tabletop Kit's `SpellDetails`).
struct SpellStatRows {
    let system: JSONValue

    var rows: [ItemStat] {
        let details = SpellDetails.fields(system).map { ItemStat($0.label, Self.plain($0.value)) }
        let ritual = system["ritual"]
        let secondaryCasters = ritual[path: "secondary.casters"].int
        let early = [
            ItemStat("Traditions", system[path: "traits.traditions"].strings.joined(separator: ", "))
        ] + details.prefix { $0.label == "Cast" } + [
            ItemStat("Cost", system[path: "cost.value"].string),
            ItemStat("Requirements", system["requirements"].string),
            ItemStat("Secondary Casters", secondaryCasters > 0 ? String(secondaryCasters) : ""),
            ItemStat("Primary Check", ritual[path: "primary.check"].string),
            ItemStat("Secondary Checks", ritual[path: "secondary.checks"].string)
        ]
        return (early + details.drop { $0.label == "Cast" }).filter { !$0.value.isEmpty }
    }

    /// A detail's markup as card text, its action tokens as the glyphs cards draw as icons.
    private static func plain(_ markup: String) -> String {
        StatBlockText.plainText(RulesText(markup))
    }
}
