import ArtExtraction
import ArtExtractionTestSupport
import CoreGraphics
import Foundation
import SharedLibraries
import Testing
@testable import PawnShopCore

/// Moving a version 2 library in and reading its PDFs again (R2.16).
@Suite struct LibraryMoveTests {
    let folder = temporaryFolder()
    let goblin = DrawnPawn(rect: CGRect(x: 20, y: 600, width: 81, height: 138), art: artImage(variant: 0),
                           name: "GOBLIN WARRIOR")

    /// A version 2 library moved in, and what it held.
    struct Moved {
        let library: PawnLibrary
        let pawn: Pawn
        let files: [URL]
    }

    /// A version 2 library whose goblin two products print, with the faces of the first only, as Pawn Shop saved it.
    func movedLibrary() throws -> Moved {
        var reprint = goblin
        reprint.rect.origin.x = 300
        let first = try writePawnPDF([goblin], named: "First Pawn Box.pdf", in: folder)
        let second = try writePawnPDF([reprint], named: "Second Pawn Box.pdf", in: folder)
        let library = folder.appendingPathComponent("Library")
        let sources = try [first, second].map { url in
            PawnSource(id: try ArtLibrary.digest(of: url), title: url.deletingPathExtension().lastPathComponent,
                       importedAt: Date(), originalPath: url.path, byteCount: PawnLibrary.byteCount(of: url) ?? 0,
                       pawnsFound: 1, readerVersion: PawnExtractor.version)
        }
        let found = try #require(try PawnExtractor.extract(from: first).pawns.first)
        let key = ArtKey.keys(for: [ArtKeyInput(sourceID: sources[0].id, name: found.name, size: found.size,
                                                fingerprint: found.fingerprint, face: found.front)])[0]
        var pawn = Pawn(id: key, name: found.name, size: found.size,
                        art: .pdf(sourceID: sources[0].id, front: found.front, back: found.back),
                        fingerprint: found.fingerprint,
                        appearances: sources.map { Appearance(sourceID: $0.id, copies: 1) })
        pawn.tags = ["club"]
        pawn.tagsCorrected = true
        try FileManager.default.createDirectory(at: library.appendingPathComponent("Sources"),
                                                withIntermediateDirectories: true)
        for (source, url) in zip(sources, [first, second]) {
            try FileManager.default.copyItem(at: url, to: library.appendingPathComponent("Sources/\(source.id).pdf"))
        }
        try saveLibrary(sources: sources, pawns: [pawn], in: library)
        return Moved(library: try PawnLibrary(folder: library), pawn: pawn, files: [first, second])
    }

    @Test func readsAgainThePDFsOfPawnsSeveralProductsPrint() throws {
        let moved = try movedLibrary()
        let library = moved.library, pawn = moved.pawn, files = moved.files
        #expect(library.pawn(id: pawn.id)?.appearances.count == 1)
        #expect(library.hasFilesToReadAgain && library.filesToReadAgain == files)

        for file in library.filesToReadAgain { try library.importPDF(at: file) }
        let read = try #require(library.pawn(id: pawn.id))
        #expect(read.id == pawn.id, "\(read.id) \(pawn.id)")
        #expect(read.appearances.count == 2, "\(read.appearances)")
        #expect(read.tags == ["club"] && read.tagsCorrected, "\(read.tags)")
        #expect(!library.hasFilesToReadAgain && library.filesToReadAgain.isEmpty)
        #expect(library.pawns.count == 1)
    }

    @Test func movesTheKeptPDFsIntoTheSharedLibrary() throws {
        let library = try movedLibrary().library
        for source in library.sources {
            #expect(FileManager.default.fileExists(atPath: library.fileURL(forSource: source.id).path))
        }
        let old = library.folder.appendingPathComponent("Sources")
        #expect(((try? FileManager.default.contentsOfDirectory(atPath: old.path)) ?? []).isEmpty)
    }
}

/// Two apps, or two devices' worth of Pawn Shop, on one shared library (R2.1).
@Suite struct SharedChangesTests {
    let folder = temporaryFolder()
    let goblin = DrawnPawn(rect: CGRect(x: 20, y: 600, width: 81, height: 138), art: artImage(variant: 0),
                           name: "GOBLIN WARRIOR")

    func library(_ name: String) throws -> PawnLibrary {
        let shared = try SharedLibrary(folder: folder.appendingPathComponent("Shared"), app: .pawnShop)
        return try PawnLibrary(folder: folder.appendingPathComponent(name), shared: shared)
    }

    @Test func showsWhatAnotherAppChanged() throws {
        let mine = try library("Mine"), other = try library("Other")
        #expect(try !mine.refresh())
        let pdf = try writePawnPDF([goblin], named: "Box.pdf", in: folder)
        try other.importPDF(at: pdf)
        #expect(try mine.refresh() && mine.pawns.map(\.name) == ["Goblin Warrior"])
        let id = try #require(mine.pawns.first?.id)

        try other.rename(id, to: "Goblin Brute")
        try other.correctTags(["Club"], of: id)
        try mine.refresh()
        #expect(mine.pawn(id: id)?.name == "Goblin Brute" && mine.pawn(id: id)?.tags == ["club"])

        try other.shared.setNote(nil, forArt: id)
        try mine.refresh()
        #expect(mine.pawn(id: id)?.name == "Goblin Warrior" && mine.pawn(id: id)?.tags == [])

        try other.shared.remove(sourceID: try #require(mine.sources.first).id)
        try mine.refresh()
        #expect(mine.pawns.isEmpty && mine.sources.isEmpty)
    }

    @Test func savesTagsChosenInABatch() throws {
        let mine = try library("Mine")
        try mine.importPDF(at: try writePawnPDF([goblin], named: "Box.pdf", in: folder))
        let id = try #require(mine.pawns.first?.id)
        mine.setTags(["club", "shield"], by: "model 1", of: id)
        mine.setSuggestedName("Goblin Guard", of: id)
        #expect(mine.pawn(id: id)?.tags == ["club", "shield"])
        try mine.save()
        let other = try library("Other")
        #expect(other.pawn(id: id)?.tags == ["club", "shield"] && other.pawn(id: id)?.tagModel == "model 1")
        #expect(other.pawn(id: id)?.suggestedName == "Goblin Guard")
    }
}
