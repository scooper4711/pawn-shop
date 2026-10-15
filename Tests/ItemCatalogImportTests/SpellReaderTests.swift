import CreatureImport
import Foundation
import Testing
@testable import ItemCatalogImport
import PawnShopCore

/// Reading spells into cards (R9).
@Suite struct SpellReaderTests {
    private func spell(_ document: [String: Any], game: Game = .pathfinder) throws -> CatalogItem? {
        let localizer = Localizer(roots: [])
        var reader = SpellReader(localizer: localizer, labels: ConfigLabels(localizer: localizer))
        return reader.spell(from: try JSONValue(data: JSONSerialization.data(withJSONObject: document)), game: game)
    }

    @Test func readsASpellAtItsRankWithoutEffectLinks() throws {
        let grip = try #require(try spell(Documents.acidGrip))
        #expect(grip.id == "pathfinder/AcidGrip" && grip.kind == .spell && grip.level == 2)
        #expect(grip.kind.cardLabel == "SPELL")
        #expect(grip.traits == ["Acid", "Concentrate"] && grip.traditions == ["arcane", "primal"])
        #expect(grip.description == "The target takes 2d8 acid damage plus 1d6 persistent acid damage.\n---\n"
            + "**Heightened (+2)** The damage increases by 2d8.")
        #expect(grip.stats == [ItemStat("Traditions", "arcane, primal"), ItemStat("Cast", "◆◆"),
                               ItemStat("Range", "120 feet"), ItemStat("Targets", "1 creature"),
                               ItemStat("Defense", "basic Reflex")])
        #expect(grip.source == "Pathfinder Player Core")
    }

    @Test func readsARitualsCostCastersAndChecks() throws {
        let ritual = try #require(try spell(Documents.animateDead))
        #expect(ritual.kind == .ritual && ritual.traits.first == "Uncommon")
        #expect(ritual.stats.map(\.label) == ["Cast", "Cost", "Secondary Casters", "Primary Check",
                                              "Secondary Checks", "Range", "Targets", "Duration"])
        #expect(ritual.stats.last?.value == "sustained up to 1 minute")
    }

    @Test func aFocusCantripIsACantripWithItsCastingChoice() throws {
        let shield = try #require(try spell(Documents.shieldCantrip, game: .starfinder))
        #expect(shield.kind == .cantrip && shield.id == "starfinder/Shield")
        #expect(shield.stats.first { $0.label == "Cast" }?.value == "◆ or ◆◆")
        var focus = Documents.shieldCantrip
        var system = focus["system"] as? [String: Any] ?? [:]
        system["traits"] = ["rarity": "common", "traditions": [], "value": ["focus"]]
        focus["system"] = system
        #expect(try spell(focus)?.kind == .focus)
    }

    @Test func skipsWhatIsntASpell() throws {
        #expect(try spell(Documents.potion) == nil)
        var nameless = Documents.acidGrip
        nameless["name"] = ""
        #expect(try spell(nameless) == nil)
    }
}
