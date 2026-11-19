import ArtExtractionTestSupport
import Foundation
import Testing
@testable import PawnShopCore

/// A copy of a real version 1 library (`TestData/library-v1.json`) and sheets saved with it (`TestData/Sheets`),
/// both gitignored; skipped without them.
enum RealLibrary {
    static let file = RealPDFs.folder.appendingPathComponent("library-v1.json")
    static let sheets = RealPDFs.folder.appendingPathComponent("Sheets")

    static var isAvailable: Bool { FileManager.default.fileExists(atPath: file.path) }

    static var savedSheets: [PawnSheet] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: sheets.path)) ?? []
        return names.filter { $0.hasSuffix(".pawnsheet") }.compactMap { name in
            try? JSONDecoder().decode(PawnSheet.self, from: Data(contentsOf: sheets.appendingPathComponent(name)))
        }
    }
}

/// The real library keyed (R2.15) and moved into the shared library (R2.16).
@Suite(.enabled(if: RealLibrary.isAvailable)) struct RealLibraryUpgradeTests {
    let old: StoredLibrary
    let folder = temporaryFolder()
    let library: PawnLibrary

    init() throws {
        old = try StoredLibrary.read(from: RealLibrary.file)
        try FileManager.default.copyItem(at: RealLibrary.file, to: folder.appendingPathComponent(PawnLibrary.indexFile))
        library = try PawnLibrary(folder: folder)
    }

    @Test func keepsEveryPawnFindableByItsOldID() throws {
        #expect(old.version == 1)
        let missing = old.pawns.filter { library.pawn(id: $0.id) == nil }
        #expect(missing.isEmpty, "\(missing.count) missing, such as \(missing.prefix(3).map(\.name))")
        #expect(Set(library.pawns.map(\.id)).count == library.pawns.count)
        let customs = old.pawns.filter(\.isCustom).map(\.id)
        #expect(Set(customs).isSubset(of: Set(library.pawns.map(\.id))))
    }

    @Test func mergesOnlyPawnsThatShareAKey() {
        let merged = old.pawns.count - library.pawns.count
        #expect(merged <= 5, "merged \(merged) pawns")
    }

    @Test func keepsNamesTagsAndCorrections() throws {
        #expect(library.pawnsNeedingNames.count == old.pawns.filter(\.needsName).count)
        for pawn in old.pawns where pawn.tagsCorrected || !pawn.tags.isEmpty {
            let moved = try #require(library.pawn(id: pawn.id))
            #expect(moved.tagsCorrected == pawn.tagsCorrected && moved.tagModel == pawn.tagModel, "\(pawn.name)")
        }
        let renamed = old.pawns.filter { !$0.needsName && !$0.isCustom && old.isNameless($0) }
        for pawn in renamed {
            #expect(library.pawn(id: pawn.id)?.name == pawn.name)
        }
    }

    @Test func opensTheSheetsSavedBefore() {
        let sheets = RealLibrary.savedSheets
        #expect(!sheets.isEmpty)
        for sheet in sheets {
            let labeled = library.labeled(sheet)
            for entry in labeled.entries {
                guard let id = entry.pawnID else { continue }
                #expect(library.pawn(id: id) != nil && entry.label?.id == id)
            }
        }
    }

    @Test func movesOnce() throws {
        #expect(try library.shared.hasMovedIn(.pawnShop))
        #expect(FileManager.default.fileExists(atPath: folder.appendingPathComponent("library.json.moved").path))
        let reopened = try PawnLibrary(folder: folder)
        #expect(reopened.pawns.count == library.pawns.count)
    }
}
