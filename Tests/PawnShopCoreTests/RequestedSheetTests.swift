import ArtExtraction
import ArtExtractionTestSupport
import Foundation
import TablesideShared
import Testing
@testable import PawnShopCore

/// The sheet another app asks for with a link (R13).
@Suite struct RequestedSheetTests {
    let goblin = Pawn(name: "Goblin Warrior", size: .small, art: .custom(CustomArt(imageFile: "goblin.png")))
    let ogre = Pawn(name: "Ogre Warrior", size: .large, art: .custom(CustomArt(imageFile: "ogre.png")))

    private func sheet(_ lines: [PawnSheetRequest.Line], alias: [UUID: Pawn] = [:]) -> PawnSheet {
        let pawns = [goblin.id: goblin, ogre.id: ogre].merging(alias) { own, _ in own }
        return PawnSheet(request: PawnSheetRequest(title: "Trouble in Otari", lines: lines)) { pawns[$0] }
    }

    @Test func putsEachPawnOnTheSheetWithItsCount() {
        let sheet = sheet([.init(name: "Goblin Warrior", count: 3, pawnID: goblin.id),
                           .init(name: "Ogre Warrior", count: 1, pawnID: ogre.id)])
        #expect(sheet.entries.map(\.content) == [.pawn(goblin.id), .pawn(ogre.id)])
        #expect(sheet.entries.map(\.count) == [3, 1])
        #expect(sheet.settings == SheetSettings())
    }

    @Test func pointsAtThePawnsOwnIDWhenTheLineUsesAnother() {
        let printKey = UUID()
        let sheet = sheet([.init(name: "Goblin Warrior", count: 2, pawnID: printKey)], alias: [printKey: goblin])
        #expect(sheet.entries.map(\.content) == [.pawn(goblin.id)])
    }

    @Test func addsUpLinesForTheSamePawn() {
        let printKey = UUID()
        let sheet = sheet([.init(name: "Goblin Warrior", count: 2, pawnID: goblin.id),
                           .init(name: "Goblin Commando", count: 1, pawnID: printKey)], alias: [printKey: goblin])
        #expect(sheet.entries.map(\.count) == [3])
    }

    @Test func aPawnTheLibraryLacksKeepsItsIDAndSaysTheCreaturesName() throws {
        let wanted = UUID()
        let sheet = sheet([.init(name: "Sewer Ooze", count: 2, pawnID: wanted)])
        let entry = try #require(sheet.entries.first)
        #expect(entry.content == .pawn(wanted))
        #expect(entry.count == 2)
        #expect(entry.label == ArtReference(id: wanted, name: "Sewer Ooze", product: ""))
        #expect(entry.missingDescription == "Sewer Ooze")
    }

    @Test func aLineNamingNoPawnGetsAPlaceholderOfItsOwn() throws {
        let sheet = sheet([.init(name: "Spike Trap", count: 1), .init(name: "Scythe Trap", count: 1)])
        #expect(sheet.entries.map(\.missingDescription) == ["Spike Trap", "Scythe Trap"])
        let ids = sheet.entries.compactMap(\.pawnID)
        #expect(Set(ids).count == 2)
        #expect(sheet.entries.map { $0.label?.id } == ids)
    }

    @Test func keepsTheOrderOfTheRequest() {
        let sheet = sheet([.init(name: "Spike Trap", count: 1), .init(name: "Ogre Warrior", count: 1, pawnID: ogre.id),
                           .init(name: "Goblin Warrior", count: 1, pawnID: goblin.id)])
        #expect(sheet.entries.map(\.missingDescription) == ["Spike Trap", "Missing pawn", "Missing pawn"])
        #expect(sheet.entries.dropFirst().map(\.content) == [.pawn(ogre.id), .pawn(goblin.id)])
    }

    @Test(arguments: [0, -2])
    func leavesOutALineWithNothingToPrint(count: Int) {
        let sheet = sheet([.init(name: "Goblin Warrior", count: count, pawnID: goblin.id),
                           .init(name: "Spike Trap", count: count)])
        #expect(sheet.entries.isEmpty)
    }

    @Test func anEmptyRequestGivesAnEmptySheet() {
        #expect(sheet([]) == PawnSheet())
    }
}

/// The request read against a real library, as the app reads it.
@Suite struct RequestedSheetLibraryTests {
    let folder = temporaryFolder().appendingPathComponent("Library")
    let box = pawnSource("box", title: "Pathfinder Pawns: Monster Box")

    @Test func findsAPawnByAnOldIDAndLabelingLeavesPlaceholdersAlone() throws {
        let goblin = printedPawn("Goblin Warrior", digest: "aa", source: box.id)
        try saveVersion1Library(sources: [box], pawns: [goblin], in: folder)
        let library = try PawnLibrary(folder: folder)
        let request = PawnSheetRequest(title: "Trouble in Otari",
                                       lines: [.init(name: "Goblin Warrior", count: 3, pawnID: goblin.id),
                                               .init(name: "Sewer Ooze", count: 1)])
        let sheet = PawnSheet(request: request, pawn: library.pawn(id:))
        let keyedID = try #require(library.pawn(id: goblin.id)).id
        #expect(sheet.entries.first?.content == .pawn(keyedID))
        let labeled = library.labeled(sheet)
        #expect(labeled.entries.map(\.missingDescription) == ["Goblin Warrior, from \(box.title)", "Sewer Ooze"])
        #expect(labeled.entries.map(\.count) == [3, 1])
    }
}
