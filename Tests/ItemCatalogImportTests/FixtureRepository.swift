import Foundation

/// A pf2e system repository cut down to what the item import reads: both games' manifests, a few equipment
/// documents, the language file, the config maps and the licenses.
struct FixtureRepository {
    let root: URL

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("pf2e-\(UUID().uuidString)")
        try write(manifest(game: "pf2e", equipment: "equipment-srd"), to: "system.pf2e.json")
        try write(manifest(game: "sf2e", equipment: "equipment"), to: "system.sf2e.json")
        try write(Self.language, to: "static/lang/en.json")
        try write(#"const traits = { "versatile-p": "PF2E.TraitVersatileP", magical: "PF2E.TraitMagical" };"#,
                  to: "src/scripts/config/traits.ts")
        try write(#"const USAGES = { "held-in-one-hand": "PF2E.TraitHeldOneHand", worncloak:"#
                  + "\n" + #"    "PF2E.TraitWornCloak" };"#, to: "src/scripts/config/usage.ts")
        try write("ORC", to: "static/licenses/ORCLicense.md")
        try write("OGL", to: "static/licenses/OpenGameLicense.md")
    }

    /// Writes an item document into a game's equipment pack, under `folder` when given.
    func addItem(_ document: [String: Any], game: String = "pf2e", folder: String? = nil) throws {
        let name = (document["name"] as? String ?? "item").lowercased().replacingOccurrences(of: " ", with: "-")
        let path = ["packs", game, "equipment", folder, "\(name).json"].compactMap { $0 }.joined(separator: "/")
        let data = try JSONSerialization.data(withJSONObject: document)
        try write(String(bytes: data, encoding: .utf8) ?? "", to: path)
    }

    /// Writes a spell document into a game's spell pack.
    func addSpell(_ document: [String: Any], game: String = "pf2e") throws {
        let name = (document["name"] as? String ?? "spell").lowercased().replacingOccurrences(of: " ", with: "-")
        let data = try JSONSerialization.data(withJSONObject: document)
        try write(String(bytes: data, encoding: .utf8) ?? "", to: "packs/\(game)/spells/\(name).json")
    }

    func write(_ text: String, to path: String) throws {
        let url = root.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    private func manifest(game: String, equipment: String) -> String {
        #"{"packs": [{"name": "\#(equipment)", "path": "packs/equipment", "type": "Item"},"#
            + #" {"name": "spells", "path": "packs/spells", "type": "Item"}]}"#
    }

    private static let language = """
        {"PF2E": {"TraitVersatileP": "Versatile P", "TraitMagical": "Magical", "TraitConsumable": "Consumable",
          "TraitHeldOneHand": "Held in 1 Hand", "TraitWornCloak": "Worn Cloak", "WeaponGroupSword": "Sword"}}
        """
}

/// Item documents as the packs hold them.
enum Documents {
    static func item(_ name: String, type: String, system: [String: Any]) -> [String: Any] {
        var base: [String: Any] = [
            "level": ["value": 1], "price": ["value": ["gp": 4]], "bulk": ["value": 0.1],
            "traits": ["rarity": "common", "value": ["magical"]], "description": ["value": "<p>Text.</p>"],
            "publication": ["title": "Pathfinder GM Core"]
        ]
        base.merge(system) { _, new in new }
        return ["_id": name.filter(\.isLetter), "name": name, "type": type, "system": base]
    }

    static var potion: [String: Any] { item("Healing Potion", type: "consumable", system: [
        "usage": ["value": "held-in-one-hand"], "uses": ["max": 1],
        "traits": ["rarity": "uncommon", "value": ["consumable", "magical"]],
        "description": ["value": #"<p><strong>Activate</strong> <span class="action-glyph">A</span> (manipulate)</p>"#
            + "<hr /><p>You regain @Damage[1d8[healing]] Hit Points.</p>"]
    ]) }

    static var longsword: [String: Any] { item("Longsword", type: "weapon", system: [
        "level": ["value": 0], "price": ["value": ["gp": 1, "sp": 5]], "bulk": ["value": 1],
        "usage": ["value": "held-in-one-hand"], "group": "sword", "range": NSNull(), "reload": ["value": NSNull()],
        "damage": ["dice": 1, "die": "d8", "damageType": "slashing"],
        "traits": ["rarity": "common", "value": ["versatile-p"]]
    ]) }

    static var fullPlate: [String: Any] { item("Full Plate", type: "armor", system: [
        "bulk": ["value": 4], "acBonus": 6, "dexCap": 0, "strength": 4, "checkPenalty": -3, "speedPenalty": -10
    ]) }

    static var shield: [String: Any] { item("Steel Shield", type: "shield", system: [
        "bulk": ["value": 0], "acBonus": 2, "hardness": 5, "hp": ["max": 20],
        "description": ["value": "<p>Durable.</p><table><tr><td>Hardness</td></tr></table>"]
    ]) }

    static var laser: [String: Any] { item("Laser Pistol", type: "weapon", system: [
        "price": ["value": ["sp": 6500], "per": 10], "usage": ["value": "held-in-two-hands"], "range": 60,
        "reload": ["value": "1"], "damage": ["dice": 2, "die": "d6", "damageType": "fire"],
        "description": ["value": "<p>Deals @Damage[(1d4+@item.system.damage.dice)[fire]] and "
            + "@Damage[(@item.level)d6[cold]], plus @Damage[(@actor.level)[fire]]{your level in fire damage}.</p>"]
    ]) }

    static func spell(_ name: String, system: [String: Any]) -> [String: Any] {
        var base: [String: Any] = [
            "level": ["value": 2], "time": ["value": "2"], "range": ["value": "120 feet"], "area": NSNull(),
            "target": ["value": "1 creature"], "duration": ["sustained": false, "value": ""],
            "defense": ["save": ["basic": true, "statistic": "reflex"]], "cost": ["value": ""], "requirements": "",
            "traits": ["rarity": "common", "traditions": ["arcane", "primal"], "value": ["acid", "concentrate"]],
            "description": ["value": "<p>Text.</p>"], "publication": ["title": "Pathfinder Player Core"]
        ]
        base.merge(system) { _, new in new }
        return ["_id": name.filter(\.isLetter), "name": name, "type": "spell", "system": base]
    }

    static var acidGrip: [String: Any] { spell("Acid Grip", system: [
        "description": ["value": "<p>The target takes 2d8 acid damage plus "
            + "@Damage[floor(@item.level/2)d6[persistent,acid]] damage. "
            + "@UUID[Compendium.pf2e.spell-effects.Item.Spell Effect: Acid Grip]</p><hr />"
            + "<p><strong>Heightened (+2)</strong> The damage increases by 2d8.</p>"]
    ]) }

    static var animateDead: [String: Any] { spell("Animate Dead", system: [
        "level": ["value": 1], "time": ["value": "1 day"], "defense": NSNull(), "cost": ["value": "black onyx"],
        "ritual": ["primary": ["check": "Religion (expert)"], "secondary": ["casters": 2, "checks": "Arcana"]],
        "duration": ["sustained": true, "value": "1 minute"],
        "traits": ["rarity": "uncommon", "traditions": [], "value": ["concentrate"]]
    ]) }

    static var shieldCantrip: [String: Any] { spell("Shield", system: [
        "level": ["value": 1], "time": ["value": "1 or 2"], "defense": NSNull(),
        "traits": ["rarity": "common", "traditions": ["arcane", "divine"], "value": ["cantrip", "focus"]]
    ]) }
}
