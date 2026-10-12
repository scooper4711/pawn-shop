import Foundation

/// What kind of item a catalog item is, from the pf2e system's item types.
public enum ItemKind: String, Codable, CaseIterable, Sendable {
    case consumable, weapon, armor, shield, ammo, equipment, treasure, backpack

    public var displayName: String {
        switch self {
        case .consumable: "Consumables"
        case .weapon: "Weapons"
        case .armor: "Armor"
        case .shield: "Shields"
        case .ammo: "Ammunition"
        case .equipment: "Gear"
        case .treasure: "Treasure"
        case .backpack: "Containers"
        }
    }
}

/// One row of an item card's stats table, such as "Price" and "4 gp".
public struct ItemStat: Codable, Hashable, Sendable {
    public var label: String
    public var value: String

    public init(_ label: String, _ value: String) {
        self.label = label
        self.value = value
    }
}

/// An item from the pf2e system's equipment packs, ready to print as a card.
public struct CatalogItem: Codable, Identifiable, Hashable, Sendable {
    /// The game and the item's id in its pack, as "pathfinder/2RuepCemJhrpKKao".
    public var id: String
    public var game: Game
    public var name: String
    public var level: Int
    public var kind: ItemKind
    /// The rarity first when it isn't common, then the traits, as the books print them.
    public var traits: [String]
    /// Paragraphs on lines of their own, `**bold**`, `*italic*`, `---` for a rule, and ◆ ◆◆ ◆◆◆ ⤾ ◇ for actions.
    public var description: String
    /// The stats in the order the card prints them; empty ones are left out.
    public var stats: [ItemStat]
    /// The book the item is from, such as "Pathfinder GM Core".
    public var source: String

    public init(id: String, game: Game, name: String, level: Int, kind: ItemKind) {
        self.id = id
        self.game = game
        self.name = name
        self.level = level
        self.kind = kind
        traits = []
        description = ""
        stats = []
        source = ""
    }
}
