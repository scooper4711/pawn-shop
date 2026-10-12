import CreatureImport
import Foundation
import PawnShopCore

/// The rows of an item card's stats table, in the order every card prints them: Level, Price, Bulk, Usage and
/// Uses, then a weapon's Damage, Hands, Range, Reload and Group, armor's AC, Dex Cap, Strength, Check and Speed,
/// or a shield's Hardness, HP and BT. Rows with nothing to say are left out.
struct ItemStatRows {
    let system: JSONValue
    let game: PawnShopCore.Game
    let labels: ConfigLabels

    func rows(for kind: ItemKind) -> [ItemStat] {
        let rows = common() + specific(to: kind)
        return rows.compactMap { label, value in value.isEmpty ? nil : ItemStat(label, value) }
    }

    private func common() -> [(String, String)] {
        let uses = system[path: "uses.max"].int
        let usage = system[path: "usage.value"].string
        return [
            ("Level", String(system[path: "level.value"].int)),
            ("Price", ItemPrice(system["price"], game: game).text),
            ("Bulk", Self.bulk(system[path: "bulk.value"])),
            ("Usage", usage.isEmpty ? "" : labels.usage(usage)),
            ("Uses", uses > 1 ? String(uses) : "")
        ]
    }

    private func specific(to kind: ItemKind) -> [(String, String)] {
        switch kind {
        case .weapon: weapon()
        case .armor: armor()
        case .shield: shield()
        case .consumable, .ammo, .equipment, .treasure, .backpack: []
        }
    }

    private func weapon() -> [(String, String)] {
        let damage = system["damage"]
        let dice = damage["dice"].int
        let die = damage["die"].string
        let type = damage["damageType"].string
        let range = system["range"].int
        return [
            ("Damage", dice > 0 && !die.isEmpty ? "\(dice)\(die) \(type)" : ""),
            ("Hands", Self.hands(system[path: "usage.value"].string)),
            ("Range", range > 0 ? "\(range) ft." : ""),
            ("Reload", system[path: "reload.value"].string),
            ("Group", system["group"].string.isEmpty ? "" : labels.weaponGroup(system["group"].string))
        ]
    }

    private func armor() -> [(String, String)] {
        let strength = system["strength"].int
        let speed = system["speedPenalty"].int
        return [
            ("AC", Self.signed(system["acBonus"].int)),
            ("Dex Cap", system["dexCap"].optionalInt.map(Self.signed) ?? ""),
            ("Strength", strength > 0 ? "+\(strength)" : ""),
            ("Check", system["checkPenalty"].int < 0 ? "\(system["checkPenalty"].int)" : ""),
            ("Speed", speed < 0 ? "\(speed) ft." : "")
        ]
    }

    private func shield() -> [(String, String)] {
        let hitPoints = system[path: "hp.max"].int
        return [
            ("AC", Self.signed(system["acBonus"].int)),
            ("Hardness", String(system["hardness"].int)),
            ("HP", hitPoints > 0 ? String(hitPoints) : ""),
            ("BT", hitPoints > 0 ? String(hitPoints / 2) : "")
        ]
    }

    /// "L" for light, "—" for negligible, else the number.
    static func bulk(_ value: JSONValue) -> String {
        guard case .number(let bulk) = value else { return "" }
        if bulk == 0 { return "—" }
        if bulk < 1 { return "L" }
        return value.string
    }

    /// How many hands a weapon is held in: "1", "2" or "1+".
    static func hands(_ usage: String) -> String {
        switch usage {
        case "held-in-one-hand": "1"
        case "held-in-two-hands": "2"
        case "held-in-one-plus-hands": "1+"
        case "held-in-one-or-two-hands": "1 or 2"
        default: ""
        }
    }

    static func signed(_ number: Int) -> String {
        number < 0 ? "\(number)" : "+\(number)"
    }
}

/// An item's price as the books print it: "1 gp, 5 sp" in Pathfinder, "60 credits" in Starfinder, "for 10" when
/// it buys a batch, or empty when it has none.
struct ItemPrice {
    let price: JSONValue
    let game: PawnShopCore.Game

    init(_ price: JSONValue, game: PawnShopCore.Game) {
        self.price = price
        self.game = game
    }

    var text: String {
        let amount = game == .starfinder ? credits : coins
        guard !amount.isEmpty else { return "" }
        let batch = price["per"].int
        return batch > 1 ? "\(amount) for \(batch)" : amount
    }

    private var coins: String {
        ["pp", "gp", "sp", "cp"].compactMap { coin in
            let count = price[path: "value.\(coin)"].int
            return count > 0 ? "\(Self.grouped(count)) \(coin)" : nil
        }.joined(separator: ", ")
    }

    /// Starfinder keeps credits as silver pieces: 1 sp is 1 credit.
    private var credits: String {
        let value = price["value"]
        let silver = value["pp"].int * 100 + value["gp"].int * 10 + value["sp"].int + value["credits"].int
        let upbs = value["upb"].int
        let parts = [silver > 0 ? "\(Self.grouped(silver)) credits" : nil,
                     upbs > 0 ? "\(Self.grouped(upbs)) UPBs" : nil]
        return parts.compactMap { $0 }.joined(separator: ", ")
    }

    /// "6,500" for 6500, as the books print prices.
    static func grouped(_ number: Int) -> String {
        number.formatted(.number.grouping(.automatic).locale(Locale(identifier: "en_US")))
    }
}
