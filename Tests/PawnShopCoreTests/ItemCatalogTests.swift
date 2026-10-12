import Foundation
import Testing
import ArtExtractionTestSupport
@testable import PawnShopCore

@Suite struct ItemCatalogTests {
    let catalog = ItemCatalog(items: [
        catalogItem("Healing Potion (Minor)", level: 1, traits: ["Consumable", "Healing"]),
        catalogItem("Healing Potion (Lesser)", level: 3, traits: ["Consumable", "Healing"]),
        catalogItem("Longsword", level: 0, kind: .weapon, traits: ["Versatile P"]),
        catalogItem("Serum of Sex Shift", level: 7, game: .starfinder, traits: ["Consumable"])
    ])

    @Test func findsItemsByNameSourceOrTheStartOfATrait() {
        #expect(catalog.search(ItemQuery(text: "healing potion")).map(\.level) == [3, 1])
        #expect(catalog.search(ItemQuery(text: "versa")).map(\.name) == ["Longsword"])
        #expect(catalog.search(ItemQuery(text: "ersatile")).isEmpty)
        #expect(catalog.search(ItemQuery(text: "gm core")).count == 4)
    }

    @Test func filtersByGameKindAndLevel() {
        #expect(catalog.search(ItemQuery(games: [.starfinder])).map(\.name) == ["Serum of Sex Shift"])
        #expect(catalog.search(ItemQuery(kinds: [.weapon])).map(\.name) == ["Longsword"])
        #expect(catalog.search(ItemQuery(kinds: [.consumable], levels: 0...2)).map(\.name)
                == ["Healing Potion (Minor)"])
    }

    @Test func sortsByNameThenLevel() {
        let twins = ItemCatalog(items: [catalogItem("Bomb", level: 3), catalogItem("Bomb", level: 1)])
        #expect(twins.search(ItemQuery()).map(\.level) == [1, 3])
    }

    @Test func findsAnItemByIDAndReadsNothingFromAMissingFile() throws {
        #expect(catalog.item(id: "pathfinder/Longsword")?.name == "Longsword")
        #expect(catalog.item(id: "missing") == nil)
        #expect(ItemCatalog(contentsOf: URL(fileURLWithPath: "/nonexistent/items.json")).items.isEmpty)
    }

    @Test func readsTheCatalogItWroteWithTheRenamesBesideIt() throws {
        let folder = temporaryFolder()
        let file = folder.appendingPathComponent("items.json")
        try JSONEncoder().encode(catalog.items).write(to: file)
        #expect(ItemCatalog(contentsOf: file).items == catalog.items && ItemCatalog(contentsOf: file).renames.isEmpty)
        try JSONEncoder().encode(["Sunrod": "Glow Rod"]).write(to: folder.appendingPathComponent("renames.json"))
        #expect(ItemCatalog(contentsOf: file).renames == ["Sunrod": "Glow Rod"])
    }
}

func catalogItem(_ name: String, level: Int, kind: ItemKind = .consumable, game: Game = .pathfinder,
                 traits: [String] = []) -> CatalogItem {
    var item = CatalogItem(id: "\(game.rawValue)/\(name.filter(\.isLetter))", game: game, name: name, level: level,
                           kind: kind)
    item.traits = traits
    item.source = game == .pathfinder ? "Pathfinder GM Core" : "Starfinder GM Core"
    item.description = "**Activate** ◆ (manipulate)\n---\nYou regain 1d8 Hit Points."
    item.stats = [ItemStat("Level", String(level)), ItemStat("Price", "4 gp")]
    return item
}
