import CoreGraphics
import Foundation
import Testing
@testable import PawnShopCore

@Suite struct NamelessPawnTests {
    static let heroesAndVillains = "Pathfinder Pawns- Heroes & Villains Pawn Collection PDF.pdf"
    static let standIn = "Unknown Pathfinder Pawns: Heroes & Villains Pawn Collection"

    let folder = temporaryFolder()
    let library: PawnLibrary
    let fighter = DrawnPawn(rect: CGRect(x: 20, y: 600, width: 81, height: 138), art: artImage(variant: 0),
                            name: "WARRIOR")
    let stranger = DrawnPawn(rect: CGRect(x: 120, y: 600, width: 81, height: 138), art: artImage(variant: 2))

    init() throws {
        library = try PawnLibrary(folder: folder.appendingPathComponent("Library"))
    }

    var namelessFighter: DrawnPawn {
        var pawn = fighter
        pawn.name = nil
        pawn.rect.origin.x = 300
        return pawn
    }

    @Test func borrowsTheNameOfArtAlreadyInTheLibrary() throws {
        try library.importPDF(at: writePawnPDF([fighter], named: "Inner Sea Pawn Box.pdf", in: folder))
        let report = try library.importPDF(at: writePawnPDF([namelessFighter, stranger],
                                                            named: Self.heroesAndVillains, in: folder))
        #expect(report.namedFromOtherProducts == 1 && report.needingNames == 1 && report.unnamed.count == 2)
        #expect(library.pawns.map(\.name).sorted() == [Self.standIn, "Warrior"])
        #expect(library.pawns.first { $0.name == "Warrior" }?.appearances.count == 2)
    }

    @Test func takesTheNameFromAProductImportedLater() throws {
        try library.importPDF(at: writePawnPDF([namelessFighter, stranger], named: Self.heroesAndVillains, in: folder))
        #expect(library.pawnsNeedingNames.count == 2)
        let report = try library.importPDF(at: writePawnPDF([fighter], named: "Inner Sea Pawn Box.pdf", in: folder))
        #expect(report.added == 0 && report.alreadyKnown == 1)
        let named = try #require(library.pawns.first { $0.name == "Warrior" })
        #expect(!named.needsName && named.appearances.count == 2)
        #expect(library.pawnsNeedingNames.map(\.name) == [Self.standIn])
    }

    @Test func givesOtherProductsStandInsWithoutBorrowing() throws {
        try library.importPDF(at: writePawnPDF([fighter], named: "Inner Sea Pawn Box.pdf", in: folder))
        try library.importPDF(at: writePawnPDF([namelessFighter], named: "Mystery Box PDF.pdf", in: folder))
        let nameless = try #require(library.pawns.first { $0.needsName })
        #expect(nameless.name == "Unknown Mystery Box")
    }

    @Test func mergesCopiesOfNamelessArt() throws {
        var copy = namelessFighter
        copy.rect.origin.x = 420
        try library.importPDF(at: writePawnPDF([namelessFighter, copy], named: Self.heroesAndVillains, in: folder))
        try library.importPDF(at: writePawnPDF([namelessFighter], named: "Mystery Box PDF.pdf", in: folder))
        #expect(library.pawnsNeedingNames.count == 1)
        #expect(library.pawnsNeedingNames.first?.appearances.map(\.copies) == [2, 1])
    }

    @Test func renamingFinishesThePawn() throws {
        try library.importPDF(at: writePawnPDF([stranger], named: Self.heroesAndVillains, in: folder))
        let pawn = try #require(library.pawnsNeedingNames.first)
        #expect(library.search(PawnQuery(needingNamesOnly: true)).map(\.id) == [pawn.id])
        try library.rename(pawn.id, to: "Masked Duelist")
        #expect(library.pawnsNeedingNames.isEmpty)
        #expect(library.search(PawnQuery(needingNamesOnly: true)).isEmpty)
    }

    @Test func readsLibrariesSavedBeforeNamesWereTracked() throws {
        let pawn = Pawn(name: "Old", size: .medium, art: .custom(CustomArt(imageFile: "old.png")), needsName: true)
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(pawn)) as? [String: Any] ?? [:]
        json.removeValue(forKey: "needsName")
        let decoded = try JSONDecoder().decode(Pawn.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(!decoded.needsName && decoded.name == "Old")
    }
}
