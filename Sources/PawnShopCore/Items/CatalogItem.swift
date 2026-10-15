import Foundation

/// What kind of card a catalog entry prints: an item, from the pf2e system's item types, or a spell.
public enum ItemKind: String, Codable, CaseIterable, Sendable {
    case consumable, weapon, armor, shield, ammo, equipment, treasure, backpack
    case spell, cantrip, focus, ritual

    /// The kinds the Items list shows.
    public static let itemKinds: [ItemKind] = [.consumable, .weapon, .armor, .shield, .ammo, .equipment, .treasure,
                                               .backpack]
    /// The kinds the Spells list shows.
    public static let spellKinds: [ItemKind] = [.spell, .cantrip, .focus, .ritual]

    public var isSpell: Bool { Self.spellKinds.contains(self) }

    /// The word by the name on the card, before the level or rank: "ITEM 3", "CANTRIP 1".
    public var cardLabel: String {
        switch self {
        case .spell: "SPELL"
        case .cantrip: "CANTRIP"
        case .focus: "FOCUS"
        case .ritual: "RITUAL"
        default: "ITEM"
        }
    }

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
        case .spell: "Spells"
        case .cantrip: "Cantrips"
        case .focus: "Focus Spells"
        case .ritual: "Rituals"
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

/// An item from the pf2e system's equipment packs, or a spell from its spell packs, ready to print as a card.
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
    /// A spell's traditions, such as "arcane"; empty for items and for spells outside the traditions.
    public var traditions: [String]

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
        traditions = []
    }

    private enum CodingKeys: String, CodingKey {
        case id, game, name, level, kind, traits, description, stats, source, traditions
    }

    /// Reads an item; one written before spells has no traditions.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        game = try container.decode(Game.self, forKey: .game)
        name = try container.decode(String.self, forKey: .name)
        level = try container.decode(Int.self, forKey: .level)
        kind = try container.decode(ItemKind.self, forKey: .kind)
        traits = try container.decode([String].self, forKey: .traits)
        description = try container.decode(String.self, forKey: .description)
        stats = try container.decode([ItemStat].self, forKey: .stats)
        source = try container.decode(String.self, forKey: .source)
        traditions = try container.decodeIfPresent([String].self, forKey: .traditions) ?? []
    }
}
