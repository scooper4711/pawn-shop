import Foundation
import SharedLibraries
import TablesideShared
import Testing
@testable import PawnShopCore

/// Art pasted onto a bestiary creature in Turnkeeper or Field Guide is a pawn here when it names the creature
/// (R3.5a).
@Suite struct PastedArtPawnTests {
    let apps: SharedCreatures
    var library: PawnLibrary { apps.library }
    let rimesnap = "pf2e.pfs-season-6-bestiary.GMKVSvtmRxBacSKH"
    var rimesnapPawn: UUID { SharedLibrary.pawnID(forSubject: rimesnap) }

    init() throws {
        apps = try SharedCreatures()
    }

    /// Pastes art onto a creature as Turnkeeper does, with the creature's name in its record unless `name` is nil.
    @discardableResult
    private func paste(onto subject: String, named name: String?, size: CreatureSize? = .tiny) throws -> UUID {
        let record = try name.map { try JSONEncoder().encode(ArtSubjectLabel(name: $0, size: size)) }
        let art = CustomArtRecord(id: UUID(), fileName: "\(UUID().uuidString).png", sharedVersion: nil,
                                  record: record ?? Data(#"{"subject":"\#(subject)"}"#.utf8))
        try apps.turnkeeper.save(art, image: Data("png".utf8))
        try apps.turnkeeper.setCreatureArt(.custom(art.id), for: subject)
        try library.refresh()
        return art.id
    }

    @Test func artThatNamesItsCreatureIsAPawn() throws {
        let art = try paste(onto: rimesnap, named: "Rimesnap")
        let pawn = try #require(library.pawn(id: rimesnapPawn))
        #expect(pawn.name == "Rimesnap" && pawn.size == .small, "Tiny prints as Small")
        #expect(pawn.isCreatureArt && !pawn.isCustomCreature && pawn.isCustom && !pawn.needsName)
        let file = try #require(try apps.turnkeeper.customArt().first { $0.id == art }).fileName
        #expect(pawn.art == .custom(CustomArt(imageFile: file)))
        #expect(library.pawns.map(\.id) == [rimesnapPawn])
    }

    @Test func aSizeThatIsNotOneOfTheSixPrintsAsMedium() throws {
        try paste(onto: rimesnap, named: "Rimesnap", size: nil)
        #expect(library.pawn(id: rimesnapPawn)?.size == .medium)
    }

    @Test func artThatNamesNoCreatureIsNotAPawnUntilItDoes() throws {
        let art = try paste(onto: rimesnap, named: nil)
        #expect(library.pawns.isEmpty)
        var row = try #require(try apps.turnkeeper.customArt().first { $0.id == art })
        row.record = try JSONEncoder().encode(ArtSubjectLabel(name: "Rimesnap", size: .tiny))
        try apps.turnkeeper.save(row)
        try library.refresh()
        #expect(library.pawns.map(\.name) == ["Rimesnap"])
    }

    @Test func aCharactersPortraitWithoutANameIsNotAPawn() throws {
        try paste(onto: "pc.\(UUID().uuidString)", named: nil)
        #expect(library.pawns.isEmpty)
    }

    @Test func replacingTheArtKeepsThePawnAndItsSettings() throws {
        try paste(onto: rimesnap, named: "Rimesnap")
        try library.correctTags(["ice", "lizard"], of: rimesnapPawn)
        let newer = try paste(onto: rimesnap, named: "Rimesnap")
        let pawn = try #require(library.pawn(id: rimesnapPawn))
        let file = try #require(try apps.turnkeeper.customArt().first { $0.id == newer }).fileName
        #expect(pawn.art == .custom(CustomArt(imageFile: file)))
        #expect(pawn.tags == ["ice", "lizard"] && pawn.tagsCorrected)
        #expect(library.pawns.count == 1)
    }

    @Test func keepsItsTagsAndPlacementAsPawnShopsOwn() throws {
        try paste(onto: rimesnap, named: "Rimesnap")
        library.setTags(["snow"], by: "model-1", of: rimesnapPawn)
        try library.save()
        var pawn = try #require(library.pawn(id: rimesnapPawn))
        #expect(pawn.tags == ["snow"] && pawn.tagModel == "model-1")
        guard case .custom(var art) = pawn.art else {
            Issue.record("The pawn isn't drawn from the pasted image")
            return
        }
        art.showsName = false
        art.scaling = .fit
        pawn.art = .custom(art)
        try library.update(pawn)
        let reopened = try PawnLibrary(folder: library.folder, shared: library.shared)
        #expect(reopened.pawn(id: rimesnapPawn)?.art == .custom(art))
        #expect(reopened.pawn(id: rimesnapPawn)?.tags == ["snow"])
    }

    @Test func itsNameIsTheCreaturesAndCannotBeChangedHere() throws {
        try paste(onto: rimesnap, named: "Rimesnap")
        try library.rename(rimesnapPawn, to: "Frosty")
        #expect(library.pawn(id: rimesnapPawn)?.name == "Rimesnap")
        var pawn = try #require(library.pawn(id: rimesnapPawn))
        pawn.name = "Frosty"
        try library.update(pawn)
        #expect(library.pawn(id: rimesnapPawn)?.name == "Rimesnap")
    }

    @Test func removingHidesItHereAndLeavesTheArtToTheOtherApps() throws {
        let art = try paste(onto: rimesnap, named: "Rimesnap")
        #expect(library.removalWarning(for: [rimesnapPawn]) == nil)
        try library.remove([rimesnapPawn])
        #expect(library.pawns.isEmpty)
        #expect(try apps.turnkeeper.creatureArt() == [rimesnap: .custom(art)])
        #expect(try apps.turnkeeper.customArt().map(\.id) == [art])
    }

    @Test func artTakenOffTheCreatureTakesItsPawn() throws {
        let art = try paste(onto: rimesnap, named: "Rimesnap")
        try apps.turnkeeper.setCreatureArt(nil, for: rimesnap)
        try apps.turnkeeper.removeCustomArt(id: art)
        try library.refresh()
        #expect(library.pawns.isEmpty && library.pawn(id: rimesnapPawn) == nil)
    }

    @Test func aCustomCreaturesPawnStaysItsOwn() throws {
        let ogre = try apps.makeCreature(named: "Ogre Boss", size: .large)
        try paste(onto: rimesnap, named: "Rimesnap")
        try library.refresh()
        #expect(library.pawns.map(\.name) == ["Ogre Boss", "Rimesnap"])
        #expect(library.pawn(id: ogre)?.isCustomCreature == true && library.pawn(id: ogre)?.isCreatureArt == false)
    }

    @Test func aSheetTurnkeeperAsksForFindsIt() throws {
        try paste(onto: rimesnap, named: "Rimesnap")
        let request = PawnSheetRequest(title: "Upon Wheels and Rime",
                                       lines: [.init(name: "Rimesnap", count: 4, pawnID: rimesnapPawn)])
        let sheet = PawnSheet(request: request, pawn: library.pawn(id:))
        #expect(sheet.entries.map(\.content) == [.pawn(rimesnapPawn)] && sheet.entries.map(\.count) == [4])
        #expect(library.labeled(sheet).entries.first?.label?.name == "Rimesnap")
    }
}
