import CoreGraphics
import Foundation
import SharedLibraries
import Testing
import ArtExtractionTestSupport
@testable import PawnShopCore

/// Pawn Shop and Turnkeeper on one shared library: custom pawns are the custom creatures both see (R3.4 to R3.6).
struct SharedCreatures {
    let folder = temporaryFolder()
    let library: PawnLibrary
    /// The shared library as Turnkeeper opens it.
    let turnkeeper: SharedLibrary

    init() throws {
        let shared = folder.appendingPathComponent("Shared")
        library = try PawnLibrary(folder: folder.appendingPathComponent("Pawn Shop"),
                                  shared: SharedLibrary(folder: shared, app: .pawnShop))
        turnkeeper = try SharedLibrary(folder: shared, app: .turnkeeper)
    }

    /// Makes a creature in Turnkeeper, with a stat block unless told otherwise, and pasted art when `hasArt`.
    @discardableResult
    func makeCreature(named name: String, size: CreatureSize? = .medium, hasStatBlock: Bool = true,
                      hasArt: Bool = true) throws -> UUID {
        let creature = CustomCreatureRecord(id: UUID(), name: name, campaignID: nil, sharedVersion: nil,
                                            record: hasStatBlock ? Data("stat block".utf8) : Data(),
                                            game: .pathfinder, size: size)
        guard hasArt else {
            try turnkeeper.save(creature)
            return creature.id
        }
        let art = CustomArtRecord(id: UUID(), fileName: "\(creature.id.uuidString).jpg", sharedVersion: nil,
                                  record: Data("art".utf8))
        try turnkeeper.addCustomCreature(creature, art: art, image: Data("jpeg".utf8))
        return creature.id
    }

    func addHero(named name: String = "Hero") throws -> Pawn {
        try library.addCustomPawn(NewCustomPawn(image: headRedImage(), name: name, size: .tiny,
                                                focus: CGPoint(x: 0.2, y: 0.8)))
    }

    func creature(_ id: UUID) throws -> CustomCreatureRecord? {
        try turnkeeper.customCreatures().first { $0.id == id }
    }
}

@Suite struct CreaturePawnTests {
    let apps: SharedCreatures
    var library: PawnLibrary { apps.library }

    init() throws {
        apps = try SharedCreatures()
    }

    @Test func aCustomPawnIsACreatureWithoutAStatBlock() throws {
        let hero = try apps.addHero()
        let creature = try #require(try apps.creature(hero.id))
        #expect(creature.name == "Hero" && creature.size == .tiny && creature.game == nil && !creature.hasStatBlock)
        #expect(hero.size == .small && hero.isCustomCreature, "Tiny prints as Small")
        let art = try #require(try apps.turnkeeper.customArt().first)
        #expect(art.id == hero.id && art.fileName == "\(hero.id.uuidString).png")
        #expect(try apps.turnkeeper.creatureArt() == ["custom.\(hero.id.uuidString)": .custom(hero.id)])
        #expect(try PawnLibrary.image(at: library.customFolder.appendingPathComponent(art.fileName)).height == 80)
    }

    @Test func showsEachCreatureWithArtAsAPawn() throws {
        let ogre = try apps.makeCreature(named: "Ogre Boss", size: .large)
        let sprite = try apps.makeCreature(named: "Sprite", size: .tiny)
        let blob = try apps.makeCreature(named: "Blob", size: nil)
        try apps.makeCreature(named: "No Art", hasArt: false)
        try apps.turnkeeper.save(CustomArtRecord(id: ogre, fileName: "pasted.png", sharedVersion: nil, record: Data()))
        try apps.turnkeeper.setCreatureArt(.custom(ogre), for: "pathfinder.goblin-warrior")

        #expect(try library.refresh())
        #expect(library.pawns.map(\.name) == ["Blob", "Ogre Boss", "Sprite"])
        #expect(library.pawns.map(\.size) == [.medium, .large, .small])
        let pawn = try #require(library.pawn(id: ogre))
        #expect(pawn.isCustom && pawn.art == .custom(CustomArt(imageFile: "\(ogre.uuidString).jpg")),
                "filled, centered and with its name printed")
        #expect(library.sourceTitle(of: pawn) == "Custom" && library.pawn(id: sprite)?.name == "Sprite")
        #expect(library.pawn(id: blob)?.needsName == false && library.own.pawnSettings.isEmpty)
        #expect(try PawnLibrary(folder: library.folder, shared: library.shared).pawns == library.pawns)
    }

    @Test func followsWhatTurnkeeperChanges() throws {
        let hero = try apps.addHero()
        #expect(try !library.refresh())
        try apps.turnkeeper.renameCustomCreature(id: hero.id, to: "Renamed There")
        try apps.turnkeeper.setCustomCreatureSize(.huge, id: hero.id)
        #expect(try library.refresh())
        let changed = try #require(library.pawn(id: hero.id))
        #expect(changed.name == "Renamed There" && changed.size == .huge && changed.art == hero.art)

        try apps.turnkeeper.setCreatureArt(nil, for: SharedLibrary.subject(ofCustomCreature: hero.id))
        try library.refresh()
        #expect(library.pawns.isEmpty, "a creature without art is left out")
    }

    @Test func drawsArtChosenFromTheLibraryAsItsPawnIs() throws {
        let goblin = DrawnPawn(rect: CGRect(x: 20, y: 600, width: 81, height: 138), art: artImage(variant: 0),
                               name: "GOBLIN WARRIOR")
        try library.importPDF(at: writePawnPDF([goblin], named: "Box.pdf", in: apps.folder))
        let printed = try #require(library.pawns.first)
        let grik = try apps.makeCreature(named: "Grik", size: .small, hasArt: false)
        try apps.turnkeeper.setCreatureArt(.library(printed.id), for: SharedLibrary.subject(ofCustomCreature: grik))
        let stray = try apps.makeCreature(named: "Stray", hasArt: false)
        try apps.turnkeeper.setCreatureArt(.library(UUID()), for: SharedLibrary.subject(ofCustomCreature: stray))

        try library.refresh()
        #expect(library.pawns.map(\.name) == ["Goblin Warrior", "Grik"])
        let pawn = try #require(library.pawn(id: grik))
        #expect(pawn.art == printed.art && pawn.size == .small && pawn.isCustom && !pawn.needsName)
        #expect(library.search(PawnQuery(custom: true)).map(\.name) == ["Grik"])

        try library.correctTags(["dogslicer"], of: grik)
        #expect(library.pawn(id: grik)?.tags == ["dogslicer"] && library.pawn(id: printed.id)?.tags == [])
        #expect(library.own.pawnSettings[grik.uuidString]?.focus == CGPoint(x: 0.5, y: 0.5))
    }

    @Test func renamingRenamesTheCreatureAndLeavesItsStatBlock() throws {
        let ogre = try apps.makeCreature(named: "Ogre Boss")
        try library.refresh()
        try library.rename(ogre, to: " Ogre King ")
        let creature = try #require(try apps.creature(ogre))
        #expect(creature.name == "Ogre King" && creature.record == Data("stat block".utf8))
        #expect(library.pawn(id: ogre)?.name == "Ogre King" && library.own.pawnSettings.isEmpty)
    }

    @Test func keepsTagsForACreatureTurnkeeperMade() throws {
        let ogre = try apps.makeCreature(named: "Ogre Boss")
        try library.refresh()
        library.setTags(["club"], by: "model 1", of: ogre)
        try library.save()
        let reopened = try PawnLibrary(folder: library.folder, shared: library.shared)
        #expect(reopened.pawn(id: ogre)?.tags == ["club"] && reopened.customPawnCandidates().saves == [ogre])
        #expect(reopened.pawnsNeedingTags(by: "model 1").isEmpty)
    }

    @Test func removingDeletesACreatureWithoutAStatBlock() throws {
        let hero = try apps.addHero()
        let image = library.customFolder.appendingPathComponent("\(hero.id.uuidString).png")
        #expect(FileManager.default.fileExists(atPath: image.path))
        try library.remove([hero.id, UUID()])
        #expect(library.pawns.isEmpty && library.own.pawnSettings.isEmpty && library.own.hidden.isEmpty)
        #expect(try apps.turnkeeper.customCreatures().isEmpty && apps.turnkeeper.customArt().isEmpty)
        #expect(try apps.turnkeeper.creatureArt().isEmpty && !FileManager.default.fileExists(atPath: image.path))
    }

    @Test func removingHidesACreatureWithAStatBlock() throws {
        let ogre = try apps.makeCreature(named: "Ogre Boss")
        try library.refresh()
        try library.correctTags(["club"], of: ogre)
        try library.remove([ogre])
        #expect(library.pawns.isEmpty && library.pawn(id: ogre) == nil && library.own.hidden == [ogre])
        #expect(try apps.creature(ogre) != nil && apps.turnkeeper.customArt().count == 1)
        #expect(try PawnLibrary(folder: library.folder, shared: library.shared).pawns.isEmpty)

        try apps.turnkeeper.removeCustomCreature(id: ogre)
        let changes = library.customPawnChanges
        try library.refresh()
        #expect(library.own.hidden.isEmpty && library.own.pawnSettings.isEmpty)
        #expect(library.customPawnChanges > changes, "its settings' record is to delete")
        #expect(try OwnLibrary.read(from: library.folder) == library.own, "saved")
    }

    @Test func aCreatureDeletedInTurnkeeperTakesItsPawn() throws {
        let hero = try apps.addHero(), villain = try apps.addHero(named: "Villain")
        try apps.turnkeeper.removeCustomCreature(id: hero.id)
        #expect(try library.refresh())
        #expect(library.pawns.map(\.id) == [villain.id])
        #expect(library.own.pawnSettings.keys.sorted() == [villain.id.uuidString])
        #expect(library.own.customPawnsModified.keys.sorted() == [villain.id.uuidString])
    }

    @Test func asksBeforeDeletingCustomPawns() throws {
        let goblin = DrawnPawn(rect: CGRect(x: 20, y: 600, width: 81, height: 138), art: artImage(variant: 0),
                               name: "GOBLIN WARRIOR")
        try library.importPDF(at: writePawnPDF([goblin], named: "Box.pdf", in: apps.folder))
        let printed = try #require(library.pawns.first)
        let ogre = try apps.makeCreature(named: "Ogre Boss")
        let hero = try apps.addHero(), villain = try apps.addHero(named: "Villain")
        try library.refresh()

        #expect(library.removalWarning(for: [printed.id, ogre, UUID()]) == nil, "these are only hidden")
        let one = try #require(library.removalWarning(for: [hero.id, printed.id]))
        #expect(one.title == "Delete “Hero”?")
        #expect(one.message == "This deletes the custom pawn and its art. This can't be undone.")
        #expect(library.removalWarning(for: [hero.id, villain.id])?.title == "Delete 2 custom pawns?")

        _ = try apps.turnkeeper.moveIn(LibraryMove(app: .turnkeeper, artFolder: nil))
        #expect(library.removalWarning(for: [hero.id])?.message == "This deletes the custom pawn and its art. "
                + "Its creature also goes from Turnkeeper and its encounters. This can't be undone.")
        #expect(library.removalWarning(for: [hero.id, villain.id])?.message
                == "This deletes the custom pawns and their art. Their creatures also go from Turnkeeper and its "
                + "encounters. This can't be undone.")
    }
}

/// Custom pawns from before they were custom creatures move into the creature library, once (R3.7).
@Suite struct CustomPawnMoveTests {
    let folder = temporaryFolder()
    var hero = Pawn(name: "Hero", size: .large,
                    art: .custom(CustomArt(imageFile: "hero.png", focus: CGPoint(x: 0.1, y: 0.9), scaling: .fit)))
    let plain = Pawn(name: "Plain", size: .small, art: .custom(CustomArt(imageFile: "plain.png")))

    init() throws {
        hero.tags = ["sword"]
        hero.tagModel = "model 1"
        var own = OwnLibrary()
        own.customPawns = [hero, plain]
        own.customPawnsModified = [hero.id.uuidString: 42]
        try FileManager.default.createDirectory(at: oldCustom, withIntermediateDirectories: true)
        try own.save(to: folder)
        try Data("hero".utf8).write(to: oldCustom.appendingPathComponent("hero.png"))
        try Data("plain".utf8).write(to: oldCustom.appendingPathComponent("plain.png"))
    }

    var oldCustom: URL { folder.appendingPathComponent("Custom") }

    func open() throws -> PawnLibrary { try PawnLibrary(folder: folder) }

    @Test func movesEachPawnWithItsIDNameSizeAndImage() throws {
        let library = try open()
        let creatures = try library.shared.customCreatures().sorted { $0.name < $1.name }
        #expect(creatures.map(\.id) == [hero.id, plain.id] && creatures.map(\.size) == [.large, .small])
        #expect(creatures.allSatisfy { !$0.hasStatBlock && $0.game == nil })
        #expect(try Data(contentsOf: library.shared.customFile("hero.png")) == Data("hero".utf8))
        #expect(!FileManager.default.fileExists(atPath: oldCustom.path), "moved, not copied")

        var moved = hero
        moved.isCustomCreature = true
        #expect(library.pawn(id: hero.id) == moved && library.pawn(id: plain.id)?.art == plain.art)
        #expect(library.own.customPawns.isEmpty && library.own.pawnSettings.keys.sorted() == [hero.id.uuidString])
        #expect(library.own.customPawnsModified == [hero.id.uuidString: 42], "the move is no change to send over")
    }

    @Test func movesOnce() throws {
        let first = try open()
        let counter = try first.shared.changeCounter()
        let again = try open()
        #expect(again.pawns == first.pawns && again.pawns.count == 2)
        #expect(try again.shared.changeCounter() == counter)
        #expect(try OwnLibrary.read(from: folder).customPawns.isEmpty)
    }

    @Test func finishesAMoveCutShort() throws {
        // As after the hero's image and creature moved and the app was ended, or another device moved the hero
        // and synced it: its creature and image are in the shared library, and its own image may be gone.
        let shared = try SharedLibrary(folder: PawnLibrary.sharedFallback(in: folder), app: .pawnShop)
        let synced = CustomCreatureRecord(id: hero.id, name: "Renamed Since", campaignID: nil, sharedVersion: nil,
                                          record: Data(), size: .huge)
        let art = CustomArtRecord(id: hero.id, fileName: "hero.png", sharedVersion: nil, record: Data())
        try shared.addCustomCreature(synced, art: art, image: Data("synced".utf8))
        try FileManager.default.removeItem(at: oldCustom.appendingPathComponent("plain.png"))

        let library = try PawnLibrary(folder: folder, shared: shared)
        #expect(library.pawn(id: hero.id)?.name == "Renamed Since" && library.pawn(id: hero.id)?.size == .huge)
        #expect(library.pawn(id: hero.id)?.tags == ["sword"])
        #expect(try Data(contentsOf: shared.customFile("hero.png")) == Data("synced".utf8))
        #expect(library.pawn(id: plain.id)?.name == "Plain", "listed even without its image")
        #expect(!FileManager.default.fileExists(atPath: oldCustom.path))
    }

    @Test func leavesAloneACustomFolderWithOtherFiles() throws {
        let stray = oldCustom.appendingPathComponent("stray.png")
        try Data("stray".utf8).write(to: stray)
        #expect(try open().pawns.count == 2 && FileManager.default.fileExists(atPath: stray.path))
    }
}
