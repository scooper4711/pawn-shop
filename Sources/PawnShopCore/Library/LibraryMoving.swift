import ArtExtraction
import Foundation
import SharedLibraries

/// Moving Pawn Shop's own library (`library.json`) into the shared art library, once (R2.16, shared libraries R6).
extension PawnLibrary {
    /// The suffix `library.json` takes once moved in, kept for one version.
    static let movedSuffix = ".moved"

    /// Moves `library.json` in while it is there and the shared library hasn't recorded the move as finished,
    /// keying a version 1 library first (R2.15). Custom pawns stay Pawn Shop's own.
    func moveInIfNeeded() throws {
        let index = folder.appendingPathComponent(Self.indexFile)
        guard FileManager.default.fileExists(atPath: index.path), try !shared.hasMovedIn(.pawnShop) else { return }
        var stored = try StoredLibrary.read(from: index)
        if stored.version < StoredLibrary.currentVersion {
            try keepVersion1(of: index)
            stored.rekeyPawns()
        }
        let plan = PawnShopMove(stored: stored, oldFolder: folder)
        let known = Set(own.customPawns.map(\.id))
        own.customPawns += stored.pawns.filter { $0.isCustom && !known.contains($0.id) }
        own.importedFiles.merge(plan.importedFiles) { current, _ in current }
        own.readAgain.merge(plan.readAgain) { current, _ in current }
        try own.save(to: folder)
        try shared.moveIn(plan.move)
        try retire(index)
    }

    /// True while PDFs moved in wait to be read again (`filesToReadAgain`).
    public var hasFilesToReadAgain: Bool { !own.readAgain.isEmpty }

    /// The original files of PDFs to read again since the move, pawn PDFs before Battle Cards (R2.16): readable
    /// here and not yet read by the current reader.
    public var filesToReadAgain: [URL] {
        own.readAgain.filter { sourceID, _ in (sharedSources[sourceID]?.readerVersion ?? 0) < PawnExtractor.version }
            .map { URL(fileURLWithPath: $0.value) }
            .filter { FileManager.default.isReadableFile(atPath: $0.path) }
            .sorted { ($0.isBattleCards ? 1 : 0, $0.path) < ($1.isBattleCards ? 1 : 0, $1.path) }
    }

    // MARK: Helpers

    private func keepVersion1(of index: URL) throws {
        let kept = folder.appendingPathComponent(Self.version1File)
        guard !FileManager.default.fileExists(atPath: kept.path) else { return }
        do {
            try FileManager.default.copyItem(at: index, to: kept)
        } catch {
            throw PawnLibraryError.saveFailed("keeping \(Self.version1File): \(error.localizedDescription)")
        }
    }

    /// Renames the moved library file, replacing one moved before.
    private func retire(_ index: URL) throws {
        let moved = folder.appendingPathComponent(Self.indexFile + Self.movedSuffix)
        do {
            try? FileManager.default.removeItem(at: moved)
            try FileManager.default.moveItem(at: index, to: moved)
        } catch {
            throw PawnLibraryError.saveFailed("renaming \(Self.indexFile): \(error.localizedDescription)")
        }
    }
}

private extension URL {
    var isBattleCards: Bool { lastPathComponent.localizedCaseInsensitiveContains("Battle Cards") }
}
