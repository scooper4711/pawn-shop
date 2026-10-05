import CoreGraphics
import Foundation
import Testing
@testable import PawnShopCore

/// A fresh folder under the system's temporary directory.
func temporaryFolder() -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("PawnShopTests-\(UUID())")
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

/// Writes a pawn PDF with a front page and its mirrored back.
func writePawnPDF(_ pawns: [DrawnPawn], named name: String, in folder: URL) throws -> URL {
    let url = folder.appendingPathComponent(name)
    try pawnPDF(pages: [pawns, pawns.map { $0.mirrored(pageWidth: letterPage.width) }]).write(to: url)
    return url
}

@Suite struct PawnLibraryTests {
    let folder = temporaryFolder()
    let goblin = DrawnPawn(rect: CGRect(x: 20, y: 600, width: 81, height: 138), art: artImage(variant: 0),
                           name: "GOBLIN WARRIOR")
    let ogre = DrawnPawn(rect: CGRect(x: 20, y: 300, width: 180, height: 138), head: .right,
                         art: artImage(variant: 1), name: "OGRE")

    func library() throws -> PawnLibrary { try PawnLibrary(folder: folder.appendingPathComponent("Library")) }

    @Test func importsAndKeepsPawnsBetweenLaunches() throws {
        let pdf = try writePawnPDF([goblin, ogre], named: "Pathfinder Pawns- Test Box PDF.pdf", in: folder)
        let report = try library().importPDF(at: pdf)
        #expect(report == ImportReport(sourceTitle: "Pathfinder Pawns: Test Box", added: 2))
        let reopened = try library()
        #expect(reopened.pawns.map(\.name).sorted() == ["Goblin Warrior", "Ogre"])
        #expect(reopened.sources.map(\.title) == ["Pathfinder Pawns: Test Box"])
        let id = try #require(reopened.sources.first?.id)
        #expect(FileManager.default.fileExists(atPath: reopened.fileURL(forSource: id).path))
    }

    @Test func importsEachPDFOnce() throws {
        let pdf = try writePawnPDF([goblin], named: "Box.pdf", in: folder)
        let library = try library()
        try library.importPDF(at: pdf)
        let moved = folder.appendingPathComponent("Moved.pdf")
        try FileManager.default.copyItem(at: pdf, to: moved)
        #expect(library.hasImported(pdf) && library.hasImported(moved))
        #expect(try library.importPDF(at: moved).wasImported)
        #expect(library.pawns.count == 1 && library.sources.count == 1)
        #expect(!library.hasImported(folder.appendingPathComponent("Missing.pdf")))
    }

    @Test func mergesArtAlreadyInTheLibrary() throws {
        let library = try library()
        try library.importPDF(at: writePawnPDF([goblin], named: "First.pdf", in: folder))
        var reprint = goblin
        reprint.rect.origin.x = 300
        let report = try library.importPDF(at: writePawnPDF([reprint, ogre], named: "Second.pdf", in: folder))
        #expect(report.added == 1 && report.alreadyKnown == 1)
        let merged = try #require(library.pawns.first { $0.name == "Goblin Warrior" })
        #expect(merged.appearances.count == 2)
        #expect(library.sourceTitles(of: merged) == ["First", "Second"])
    }

    @Test func addsUpdatesAndRemovesPawns() throws {
        let library = try library()
        let artFile = "art.png"
        try Data("png".utf8).write(to: library.customFolder.appendingPathComponent(artFile))
        var pawn = Pawn(name: "Hero", size: .medium, art: .custom(CustomArt(imageFile: artFile)))
        try library.add(pawn)
        pawn.name = "Heroine"
        try library.update(pawn)
        #expect(try self.library().pawn(id: pawn.id)?.name == "Heroine")
        try library.rename(pawn.id, to: "  Champion ")
        try library.rename(pawn.id, to: " ")
        try library.rename(UUID(), to: "Nobody")
        #expect(library.pawn(id: pawn.id)?.name == "Champion")
        #expect(library.folders.sourceFile(id: "abc").lastPathComponent == "abc.pdf")
        try library.remove([pawn.id])
        #expect(library.pawns.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: library.customFolder.appendingPathComponent(artFile).path))
    }

    @Test func reportsUnreadableFiles() {
        #expect(throws: PawnLibraryError.unreadableFile("Missing.pdf")) {
            try PawnLibrary.prepareImport(of: folder.appendingPathComponent("Missing.pdf"))
        }
        #expect(PawnLibraryError.unreadableFile("a.pdf").description.contains("a.pdf"))
        #expect(PawnLibraryError.saveFailed("disk full").description.contains("disk full"))
    }

    @Test(arguments: [("Pathfinder Pawns: Bestiary 2 Box", "Bestiary 2"),
                      ("Starfinder Alien Archive Pawn Box", "Alien Archive"),
                      ("Pathfinder Pawns: Pathfinder Society Pawn Collection", "Society"),
                      ("Pathfinder Monster Core 2 Pawn Box", "Monster Core 2"),
                      ("Box", "Box")])
    func shortensProductTitles(title: String, short: String) {
        let source = PawnSource(id: "x", title: title, importedAt: Date(), originalPath: "", byteCount: 0)
        #expect(source.shortTitle == short)
    }

    @Test func titlesProductsFromFileNames() {
        #expect(PawnSource.title(fromFileName: "PZO10013E Pathfinder Monster Core 2 Pawn Box PDF.pdf")
                == "Pathfinder Monster Core 2 Pawn Box")
        #expect(PawnSource.title(fromFileName: "Starfinder Pawns- Alien Archive 2 Pawn Box PDF.pdf")
                == "Starfinder Pawns: Alien Archive 2 Pawn Box")
    }
}

@Suite struct PawnSearchTests {
    let library: PawnLibrary

    init() throws {
        let folder = temporaryFolder()
        library = try PawnLibrary(folder: folder.appendingPathComponent("Library"))
        let skeleton = DrawnPawn(rect: CGRect(x: 20, y: 600, width: 81, height: 138), art: artImage(variant: 0),
                                 name: "SKELETON GUARD")
        var otherSkeleton = skeleton
        otherSkeleton.rect.origin.x = 120
        otherSkeleton.art = artImage(variant: 2)
        let drone = DrawnPawn(rect: CGRect(x: 20, y: 300, width: 180, height: 138), head: .right,
                              art: artImage(variant: 1), name: "SECURITY DRONE")
        try library.importPDF(at: writePawnPDF([skeleton, otherSkeleton], named: "Pathfinder Bestiary.pdf",
                                               in: folder))
        try library.importPDF(at: writePawnPDF([drone], named: "Starfinder Pawns- Pact Worlds.pdf", in: folder))
        try library.add(Pawn(name: "Señor Cáscara", size: .small, art: .custom(CustomArt(imageFile: "x.png"))))
    }

    @Test func findsWordsInNamesAndProductTitles() {
        #expect(library.search(PawnQuery(text: "skeleton")).map(\.name) == ["Skeleton Guard", "Skeleton Guard"])
        #expect(library.search(PawnQuery(text: "pact drone")).map(\.name) == ["Security Drone"])
        #expect(library.search(PawnQuery(text: "senor cascara")).map(\.name) == ["Señor Cáscara"])
        #expect(library.search(PawnQuery()).count == 4)
    }

    @Test func filtersBySizeGameProductAndOrigin() throws {
        #expect(library.search(PawnQuery(sizes: [.large])).map(\.name) == ["Security Drone"])
        #expect(library.search(PawnQuery(games: [.starfinder])).map(\.name) == ["Security Drone", "Señor Cáscara"])
        let bestiary = try #require(library.sources.first { $0.game == .pathfinder })
        #expect(library.search(PawnQuery(sourceIDs: [bestiary.id])).count == 2)
        #expect(library.search(PawnQuery(custom: true)).map(\.name) == ["Señor Cáscara"])
        #expect(library.search(PawnQuery(custom: false)).count == 3)
    }

    @Test func namesTheProductOfEachPawn() throws {
        let custom = try #require(library.pawns.first { $0.isCustom })
        #expect(library.sourceTitle(of: custom) == "Custom" && library.sourceTitles(of: custom) == ["Custom"])
        let drone = try #require(library.pawns.first { $0.name == "Security Drone" })
        #expect(library.sourceTitle(of: drone) == "Starfinder Pawns: Pact Worlds")
        #expect(library.shortSourceTitle(of: drone) == "Pact Worlds")
        #expect(library.shortSourceTitle(of: custom) == "Custom")
    }
}

@Suite struct ScrollkeeperScannerTests {
    @Test func findsPawnPDFsInSubfolders() throws {
        let folder = temporaryFolder()
        let product = folder.appendingPathComponent("Bestiary Pawn Box", isDirectory: true)
        try FileManager.default.createDirectory(at: product, withIntermediateDirectories: true)
        for name in ["Bestiary Pawn Box PDF.pdf", "Bestiary PDF.pdf", "pawns.txt"] {
            try Data().write(to: product.appendingPathComponent(name))
        }
        try Data().write(to: folder.appendingPathComponent("Another Pawn Collection.PDF"))
        let names = ScrollkeeperScanner.pawnPDFs(in: folder).map(\.lastPathComponent)
        #expect(names == ["Another Pawn Collection.PDF", "Bestiary Pawn Box PDF.pdf"])
        #expect(ScrollkeeperScanner.pawnPDFs(in: folder.appendingPathComponent("Missing")).isEmpty)
        #expect(ScrollkeeperScanner.defaultFolder.path.hasSuffix("Scrollkeeper/Files"))
    }
}
