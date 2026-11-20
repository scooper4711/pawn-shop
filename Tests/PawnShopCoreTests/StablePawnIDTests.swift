import ArtExtraction
import ArtExtractionTestSupport
import CoreGraphics
import Foundation
import Testing
@testable import PawnShopCore

/// Writes a library as version 1 saved it: random pawn IDs, no aliases.
func saveVersion1Library(sources: [PawnSource], pawns: [Pawn], in folder: URL) throws {
    var stored = StoredLibrary(sources: sources, pawns: pawns)
    stored.version = 1
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    try JSONEncoder().encode(stored).write(to: folder.appendingPathComponent(PawnLibrary.indexFile))
}

func pawnSource(_ id: String, title: String) -> PawnSource {
    PawnSource(id: id, title: title, importedAt: Date(), originalPath: "/\(title).pdf", byteCount: 1)
}

func printedPawn(_ name: String, digest: String, source: String, size: PawnSize = .medium) -> Pawn {
    let face = PawnFace(pageIndex: 0, rect: CGRect(x: 20, y: 600, width: 81, height: 69), rotation: 0)
    return Pawn(name: name, size: size, art: .pdf(sourceID: source, front: face, back: face),
                fingerprint: ArtFingerprint(imageDigests: [digest]),
                appearances: [Appearance(sourceID: source, copies: 1)])
}

@Suite struct StablePawnIDTests {
    static let heroesAndVillains = "Pathfinder Pawns- Heroes & Villains Pawn Collection PDF.pdf"

    let folder = temporaryFolder()
    let goblin = DrawnPawn(rect: CGRect(x: 20, y: 600, width: 81, height: 138), art: artImage(variant: 0),
                           name: "GOBLIN WARRIOR")
    let ogre = DrawnPawn(rect: CGRect(x: 20, y: 300, width: 180, height: 138), head: .right,
                         art: artImage(variant: 1), name: "OGRE")

    func library(_ name: String) throws -> PawnLibrary {
        try PawnLibrary(folder: folder.appendingPathComponent(name))
    }

    func ids(_ library: PawnLibrary) -> [String: UUID] {
        Dictionary(uniqueKeysWithValues: library.pawns.map { ($0.name, $0.id) })
    }

    @Test func givesThePawnsOfAPDFTheirArtKeysOnEveryDevice() throws {
        let pdf = try writePawnPDF([goblin, ogre], named: "Box.pdf", in: folder)
        let mac = try library("Mac"), iPad = try library("iPad")
        try mac.importPDF(at: pdf)
        try iPad.importPDF(at: pdf)
        #expect(ids(mac) == ids(iPad))
        let source = try #require(mac.sources.first)
        let found = try PawnExtractor.extract(from: pdf).pawns
        let expected = ArtKey.keys(for: found.map { pawn in
            ArtKeyInput(sourceID: source.id, name: pawn.name, size: pawn.size, fingerprint: pawn.fingerprint,
                        face: pawn.front)
        })
        #expect(Set(mac.pawns.map(\.id)) == Set(expected))
    }

    @Test func givesAReprintTheSameIDInEitherOrder() throws {
        var reprint = goblin
        reprint.name = "GOBLIN, WARRIOR"
        reprint.rect.origin.x = 300
        let first = try writePawnPDF([goblin], named: "First.pdf", in: folder)
        let second = try writePawnPDF([reprint, ogre], named: "Second.pdf", in: folder)
        let mac = try library("Mac"), iPad = try library("iPad")
        try mac.importPDF(at: first)
        let report = try mac.importPDF(at: second)
        try iPad.importPDF(at: second)
        try iPad.importPDF(at: first)
        #expect(report.added == 1 && report.alreadyKnown == 1)
        #expect(mac.pawns.count == 2 && iPad.pawns.count == 2)
        #expect(Set(mac.pawns.map(\.id)) == Set(iPad.pawns.map(\.id)))
    }

    @Test func answersToTheKeyOfEveryPrintMergedIntoAPawn() throws {
        var nameless = goblin
        nameless.name = nil
        let named = try writePawnPDF([goblin], named: "Monster Box.pdf", in: folder)
        let unnamed = try writePawnPDF([nameless], named: Self.heroesAndVillains, in: folder)
        let mac = try library("Mac"), iPad = try library("iPad")
        try mac.importPDF(at: named)
        try mac.importPDF(at: unnamed)
        try iPad.importPDF(at: unnamed)
        try iPad.importPDF(at: named)
        #expect(mac.pawns.count == 1 && iPad.pawns.count == 1)
        for id in mac.pawns.map(\.id) + iPad.pawns.map(\.id) {
            #expect(mac.pawn(id: id)?.name == "Goblin Warrior" && iPad.pawn(id: id)?.name == "Goblin Warrior")
        }
    }

    @Test func keepsTheIDsBetweenLaunches() throws {
        let mac = try library("Mac")
        try mac.importPDF(at: writePawnPDF([goblin], named: "Box.pdf", in: folder))
        let reopened = try library("Mac")
        #expect(reopened.pawns.map(\.id) == mac.pawns.map(\.id))
    }

    @Test func removesExtractedPawnsFromPawnShopOnly() throws {
        let mac = try library("Mac")
        try mac.importPDF(at: writePawnPDF([goblin, ogre], named: "Box.pdf", in: folder))
        let goblinID = try #require(ids(mac)["Goblin Warrior"])
        try mac.remove([goblinID])
        #expect(mac.pawns.map(\.name) == ["Ogre"] && mac.pawn(id: goblinID) == nil)
        #expect(try mac.shared.artEntry(id: goblinID) != nil)
        #expect(try library("Mac").pawns.map(\.name) == ["Ogre"])
    }
}

@Suite struct LibraryUpgradeTests {
    let folder = temporaryFolder().appendingPathComponent("Library")
    let box = pawnSource("box", title: "Pathfinder Pawns: Monster Box")
    let cards = pawnSource("cards", title: "Pathfinder Battle Cards: Monsters")
    let heroes = pawnSource("heroes", title: "Pathfinder Pawns: Heroes & Villains Pawn Collection")

    @Test func keysEveryExtractedPawnAndKeepsItsOldIDAsAnAlias() throws {
        let goblin = printedPawn("Goblin Warrior", digest: "aa", source: box.id)
        let custom = Pawn(name: "Hero", size: .medium, art: .custom(CustomArt(imageFile: "hero.png")))
        try saveVersion1Library(sources: [box], pawns: [goblin, custom], in: folder)
        let library = try PawnLibrary(folder: folder)
        let keyed = try #require(library.pawns.first { $0.name == "Goblin Warrior" })
        let input = ArtKeyInput(sourceID: box.id, name: "Goblin Warrior", size: .medium,
                                fingerprint: goblin.fingerprint, face: goblin.art.front)
        #expect(keyed.id == ArtKey.keys(for: [input]).first)
        #expect(library.pawn(id: goblin.id)?.id == keyed.id)
        let moved = try #require(library.pawn(id: custom.id))
        #expect(moved.name == "Hero" && moved.art == custom.art && moved.isCustomCreature)
    }

    @Test func mergesPawnsWithOneKey() throws {
        var beetle = printedPawn("Planetoid, Beetle", digest: "bb", source: box.id, size: .huge)
        beetle.traits = ["beast"]
        var card = printedPawn("Planetoid Beetle", digest: "bb", source: cards.id, size: .huge)
        card.traits = ["beast", "huge"]
        try saveVersion1Library(sources: [box, cards], pawns: [beetle, card], in: folder)
        let library = try PawnLibrary(folder: folder)
        let merged = try #require(library.pawns.first)
        #expect(library.pawns.count == 1 && merged.name == "Planetoid, Beetle")
        #expect(merged.traits == ["beast", "huge"])
        #expect(library.pawn(id: beetle.id)?.id == merged.id && library.pawn(id: card.id)?.id == merged.id)
        // Only the first product's print is recorded by place: both are read again from their files (R2.16).
        #expect(Set(library.own.readAgain.keys) == [box.id, cards.id])
    }

    @Test func keysANamelessProductsPawnWithoutTheNameItWasGiven() throws {
        let named = printedPawn("Warrior", digest: "cc", source: heroes.id)
        var waiting = printedPawn("Unknown Pathfinder Pawns: Heroes & Villains", digest: "dd", source: heroes.id)
        waiting.needsName = true
        try saveVersion1Library(sources: [heroes], pawns: [named, waiting], in: folder)
        let library = try PawnLibrary(folder: folder)
        let unnamedKeys = [named, waiting].map { pawn in
            ArtKey.keys(for: [ArtKeyInput(sourceID: heroes.id, name: "", size: .medium,
                                          fingerprint: pawn.fingerprint, face: pawn.art.front)])[0]
        }
        #expect(Set(library.pawns.map(\.id)) == Set(unnamedKeys))
        #expect(library.pawns.map(\.name).sorted() == ["Unknown Pathfinder Pawns: Heroes & Villains", "Warrior"])
    }

    @Test func movesTheUpgradeOnceAndKeepsTheOldFile() throws {
        try saveVersion1Library(sources: [box], pawns: [printedPawn("Ogre", digest: "ee", source: box.id)],
                                in: folder)
        let old = try Data(contentsOf: folder.appendingPathComponent(PawnLibrary.indexFile))
        let upgraded = try PawnLibrary(folder: folder)
        #expect(try Data(contentsOf: folder.appendingPathComponent(PawnLibrary.version1File)) == old)
        let moved = folder.appendingPathComponent(PawnLibrary.indexFile + PawnLibrary.movedSuffix)
        #expect(try Data(contentsOf: moved) == old)
        let reopened = try PawnLibrary(folder: folder)
        #expect(reopened.pawns == upgraded.pawns)
    }

    @Test func reportsAnOldFileItCannotKeep() throws {
        _ = try PawnLibrary(folder: folder)
        try saveVersion1Library(sources: [box], pawns: [], in: folder)
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: folder.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: folder.path) }
        #expect(throws: PawnLibraryError.self) { try PawnLibrary(folder: folder) }
    }
}
