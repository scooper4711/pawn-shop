import CreatureImport
import Foundation
import Testing
@testable import ItemCatalogImport
import PawnShopCore

@Suite struct ItemReaderTests {
    let repository: FixtureRepository
    let reader: ItemReader

    init() throws {
        repository = try FixtureRepository()
        let localizer = try Localizer(languageDirectory: repository.root.appendingPathComponent("static/lang"))
        reader = ItemReader(localizer: localizer,
                            labels: ConfigLabels(repository: repository.root, localizer: localizer))
    }

    @Test func readsAConsumablesStatsTraitsAndDescription() throws {
        let potion = try #require(item(Documents.potion))
        #expect(potion.kind == .consumable && potion.level == 1 && potion.source == "Pathfinder GM Core")
        #expect(potion.traits == ["Uncommon", "Consumable", "Magical"])
        #expect(potion.stats == [ItemStat("Level", "1"), ItemStat("Price", "4 gp"), ItemStat("Bulk", "L"),
                                 ItemStat("Usage", "held in 1 hand")])
        #expect(potion.description == "**Activate** ◆ (manipulate)\n---\nYou regain 1d8 healing Hit Points.")
    }

    @Test func ordersAWeaponsStats() throws {
        let sword = try #require(item(Documents.longsword))
        #expect(sword.stats.map(\.label) == ["Level", "Price", "Bulk", "Usage", "Damage", "Hands", "Group"])
        #expect(sword.stats.map(\.value) == ["0", "1 gp, 5 sp", "1", "held in 1 hand", "1d8 slashing", "1", "Sword"])
        #expect(sword.traits == ["Versatile P"])
    }

    @Test func ordersArmorAndShieldStats() throws {
        let plate = try #require(item(Documents.fullPlate))
        #expect(plate.stats.dropFirst(3) == [ItemStat("AC", "+6"), ItemStat("Dex Cap", "+0"),
                                             ItemStat("Strength", "+4"), ItemStat("Check", "-3"),
                                             ItemStat("Speed", "-10 ft.")])
        let shield = try #require(item(Documents.shield))
        #expect(shield.stats.dropFirst(2) == [ItemStat("Bulk", "—"), ItemStat("AC", "+2"), ItemStat("Hardness", "5"),
                                              ItemStat("HP", "20"), ItemStat("BT", "10")])
        #expect(shield.description == "Durable.")
    }

    @Test func pricesStarfinderItemsInCreditsAndWorksOutTheirFormulas() throws {
        let laser = try #require(item(Documents.laser, game: .starfinder))
        #expect(laser.stats.first { $0.label == "Price" }?.value == "6,500 credits for 10")
        #expect(laser.stats.map(\.label).suffix(4) == ["Damage", "Hands", "Range", "Reload"])
        #expect(laser.stats.suffix(4).map(\.value) == ["2d6 fire", "2", "60 ft.", "1"])
        #expect(laser.description == "Deals 1d4+2 at 1, plus your level.")
    }

    @Test func skipsDocumentsThatArentItemsAndCountsKitsAsGear() throws {
        #expect(item(Documents.item("Effect", type: "effect", system: [:])) == nil)
        #expect(item(Documents.item("", type: "weapon", system: [:])) == nil)
        #expect(item(Documents.item("Healer's Toolkit", type: "kit", system: [:]))?.kind == .equipment)
    }

    @Test func formatsPricesBulkAndHands() throws {
        #expect(ItemPrice(try json(["value": ["pp": 1, "cp": 3]]), game: .pathfinder).text == "1 pp, 3 cp")
        #expect(ItemPrice(try json(["value": ["gp": 2, "upb": 1200]]), game: .starfinder).text
                == "20 credits, 1,200 UPBs")
        #expect(ItemPrice(try json(["value": [:]]), game: .pathfinder).text.isEmpty)
        #expect(ItemStatRows.bulk(.number(2)) == "2" && ItemStatRows.bulk(.null).isEmpty)
        #expect(["held-in-one-plus-hands", "held-in-one-or-two-hands", "worn"].map(ItemStatRows.hands)
                == ["1+", "1 or 2", ""])
    }

    @Test func labelsSlugsFromTheConfigOrElseFromTheirWords() throws {
        let localizer = try Localizer(languageDirectory: repository.root.appendingPathComponent("static/lang"))
        let labels = ConfigLabels(repository: repository.root, localizer: localizer)
        #expect(labels.usage("worncloak") == "worn cloak" && labels.usage("affixed-to-armor") == "affixed to armor")
        #expect(labels.trait("magical") == "Magical" && labels.trait("critical-flame") == "Critical Flame")
        #expect(labels.weaponGroup("sword") == "Sword" && labels.weaponGroup("laser") == "Laser")
    }

    private func item(_ document: [String: Any], game: Game = .pathfinder) -> CatalogItem? {
        var reader = reader
        return (try? json(document)).flatMap { reader.item(from: $0, game: game) }
    }

    private func json(_ object: [String: Any]) throws -> JSONValue {
        try JSONValue(data: JSONSerialization.data(withJSONObject: object))
    }
}
