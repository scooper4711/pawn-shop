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

@Suite(.enabled(if: RealLibrary.isAvailable)) struct RealLibraryUpgradeTests {
    let old: StoredLibrary
    let library: PawnLibrary

    init() throws {
        old = try JSONDecoder().decode(StoredLibrary.self, from: Data(contentsOf: RealLibrary.file))
        let folder = temporaryFolder()
        try FileManager.default.copyItem(at: RealLibrary.file, to: folder.appendingPathComponent(PawnLibrary.indexFile))
        library = try PawnLibrary(folder: folder)
    }

    @Test func keepsEveryPawnFindableByItsOldID() throws {
        #expect(old.version == 1)
        let byID = Dictionary(uniqueKeysWithValues: library.pawns.map { ($0.id, $0) })
        let found = old.pawns.filter { pawn in
            (byID[pawn.id] ?? library.aliases[pawn.id].flatMap { byID[$0] }) != nil
        }
        #expect(found.count == old.pawns.count)
        #expect(Set(library.pawns.map(\.id)).count == library.pawns.count)
        let customs = old.pawns.filter(\.isCustom).map(\.id)
        #expect(Set(customs).isSubset(of: Set(library.pawns.map(\.id))))
        #expect(library.aliases.count == old.pawns.count - customs.count)
    }

    @Test func mergesOnlyPawnsThatShareAKey() {
        let merged = old.pawns.count - library.pawns.count
        #expect(merged <= 5, "merged \(merged) pawns")
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
}
