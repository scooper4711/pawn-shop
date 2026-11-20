import CoreGraphics
import Foundation
import Testing
import ArtExtractionTestSupport
@testable import PawnShopCore

/// Tags, suggested names and corrections kept between launches, and which pawns still need tagging (R2.7).
@Suite struct PawnTagStorageTests {
    let folder = temporaryFolder()

    func library() throws -> PawnLibrary { try PawnLibrary(folder: folder.appendingPathComponent("Library")) }

    @Test func keepsTagsBetweenLaunchesAndFindsPawnsByThem() throws {
        let library = try library()
        let hero = Pawn(name: "Hero", size: .medium, art: .custom(CustomArt(imageFile: "hero.png")))
        let ogre = Pawn(name: "Ogre", size: .large, art: .custom(CustomArt(imageFile: "ogre.png")))
        try library.add(hero)
        try library.add(ogre)
        #expect(library.pawnsNeedingTags(by: "gemma3:4b").count == 2)
        library.setTags(["turban", "scimitar"], by: "gemma3:4b", of: hero.id)
        library.setTags(["club"], by: "gemma3:4b", of: UUID())
        try library.save()
        let reopened = try self.library()
        #expect(reopened.pawn(id: hero.id)?.tags == ["turban", "scimitar"])
        #expect(reopened.pawnsNeedingTags(by: "gemma3:4b").map(\.name) == ["Ogre"])
        #expect(reopened.pawnsNeedingTags(by: "another-model").count == 2)
        #expect(reopened.search(PawnQuery(text: "Scimitar turban")).map(\.name) == ["Hero"])
    }

    @Test func matchesTagsAnywhereInThem() throws {
        let library = try library()
        let names = ["Hero", "Heroine", "Ogre"]
        let tags = [["longsword"], ["plate armor", "shortsword"], ["club"]]
        for (name, tags) in zip(names, tags) {
            try library.add(Pawn(name: name, size: .medium, art: .custom(CustomArt(imageFile: "x.png"))))
            library.setTags(tags, by: "model", of: library.pawns.last!.id)
        }
        #expect(library.search(PawnQuery(text: "sword")).map(\.name) == ["Hero", "Heroine"])
        #expect(library.search(PawnQuery(text: "armor")).map(\.name) == ["Heroine"])
        #expect(library.search(PawnQuery(text: "LONG")).map(\.name) == ["Hero"])
        #expect(library.search(PawnQuery(text: "plate sword")).map(\.name) == ["Heroine"])
        #expect(library.search(PawnQuery(text: "ogr")).map(\.name) == ["Ogre"])
        #expect(library.search(PawnQuery(text: "axe")).isEmpty)
    }

    @Test func asksAboutPawnsNeedingANameFirstUntilOneIsSuggested() throws {
        let library = try library()
        let named = Pawn(name: "Hero", size: .medium, art: .custom(CustomArt(imageFile: "hero.png")))
        let nameless = Pawn(name: "Unknown Heroes", size: .medium, art: .custom(CustomArt(imageFile: "x.png")),
                            needsName: true)
        try library.add(named)
        try library.add(nameless)
        #expect(library.pawnsNeedingTags(by: "model").map(\.id) == [nameless.id, named.id])
        library.setTags(["bow"], by: "model", of: named.id)
        library.setTags(["bow"], by: "model", of: nameless.id)
        #expect(library.pawnsNeedingTags(by: "model").map(\.id) == [nameless.id])
        library.setSuggestedName("Elf Archer", of: nameless.id)
        library.setSuggestedName("Ignored", of: UUID())
        try library.save()
        let reopened = try self.library()
        #expect(reopened.pawn(id: nameless.id)?.suggestedName == "Elf Archer")
        #expect(reopened.pawnsNeedingTags(by: "model").isEmpty)
        try reopened.rename(nameless.id, to: "Elf Archer")
        #expect(reopened.pawn(id: nameless.id)?.suggestedName == "")
        #expect(reopened.pawn(id: nameless.id)?.needsName == false)
    }

    @Test func asksAboutPawnsOnScreenFirst() throws {
        let library = try library()
        let names = ["First", "Second", "Third", "Fourth"]
        for name in names {
            try library.add(Pawn(name: name, size: .medium, art: .custom(CustomArt(imageFile: "x.png")),
                                 needsName: name == "Fourth"))
        }
        let ids = Dictionary(uniqueKeysWithValues: library.pawns.map { ($0.name, $0.id) })
        let order = { (visible: Set<String>) in
            library.pawnsNeedingTags(by: "model", visible: Set(visible.compactMap { ids[$0] })).map(\.name)
        }
        #expect(order([]) == ["Fourth", "First", "Second", "Third"])
        #expect(order(["Third", "Second"]) == ["Second", "Third", "Fourth", "First"])
        library.setTags(["axe"], by: "model", of: ids["Second"]!)
        #expect(order(["Third", "Second"]) == ["Third", "Fourth", "First"])
    }

    @Test func keepsTagsTheUserCorrected() throws {
        let library = try library()
        let forgeSpurned = Pawn(name: "Accursed Forge-Spurned", size: .medium,
                                art: .custom(CustomArt(imageFile: "x.png")))
        let nameless = Pawn(name: "Unknown Heroes", size: .medium, art: .custom(CustomArt(imageFile: "y.png")),
                            needsName: true)
        try library.add(forgeSpurned)
        try library.add(nameless)
        library.setTags(["orc"], by: "model", of: forgeSpurned.id)
        try library.correctTags(["Undead", "dwarf", "undead"], of: forgeSpurned.id)
        try library.correctTags(["elf"], of: nameless.id)
        try library.correctTags(["x"], of: UUID())
        library.setTags(["orc"], by: "model", of: forgeSpurned.id)
        let reopened = try self.library()
        #expect(reopened.pawn(id: forgeSpurned.id)?.tags == ["undead", "dwarf"])
        #expect(reopened.pawn(id: forgeSpurned.id)?.tagsCorrected == true)
        // A new model leaves corrected tags alone, but a pawn needing a name is still asked for one.
        #expect(reopened.pawnsNeedingTags(by: "another-model").map(\.id) == [nameless.id])
        reopened.setTags(["goblin"], by: "another-model", of: nameless.id)
        #expect(reopened.pawn(id: nameless.id)?.tags == ["elf"])
        #expect(reopened.search(PawnQuery(text: "dwarf")).map(\.id) == [forgeSpurned.id])
    }

    @Test func readsPawnsSavedBeforeTags() throws {
        var pawn = Pawn(name: "Old", size: .small, art: .custom(CustomArt(imageFile: "old.png")))
        pawn.tags = ["axe"]
        var json = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(pawn)) as? [String: Any])
        #expect(json["tags"] as? [String] == ["axe"])
        json["tags"] = nil
        json["tagModel"] = nil
        json["suggestedName"] = nil
        json["tagsCorrected"] = nil
        let old = try JSONDecoder().decode(Pawn.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(old.tags.isEmpty && old.tagModel.isEmpty && old.suggestedName.isEmpty && !old.tagsCorrected)
    }
}
