import ArtExtraction
import Foundation

/// Reading PDFs again at launch once the reader is newer than the one that read them (R1.7), so its improvements
/// reach a library without the user importing everything again.
extension PawnLibrary {
    /// True while PDFs wait to be read again (`filesToReadAgain`), readable here or not.
    public var hasFilesToReadAgain: Bool { !originalsToReadAgain.isEmpty }

    /// The original files of the PDFs an older reader read, where they can be read, pawn PDFs before Battle Cards:
    /// those imported here, and those moved in (R2.16). Never the library's own copy of a PDF: of a deck in two PDFs
    /// that is the art alone, and read without its stat blocks the deck would lose its creatures.
    public var filesToReadAgain: [URL] {
        originalsToReadAgain.values
            .compactMap { paths in paths.sorted().first { FileManager.default.isReadableFile(atPath: $0) } }
            .map { URL(fileURLWithPath: $0) }
            .sorted { ($0.isBattleCards ? 1 : 0, $0.path) < ($1.isBattleCards ? 1 : 0, $1.path) }
    }

    /// Adds a PDF read again at launch (`commit`). A reading that finds nothing where the last one found art is
    /// refused and the PDF left as it was: something the reading needs is missing, such as a deck's other PDF.
    @discardableResult
    public func commitReadAgain(_ prepared: PreparedImport) throws -> ImportReport {
        let foundBefore = sharedSources[prepared.digest]?.artFound ?? 0
        guard foundBefore == 0 || !prepared.extraction.pawns.isEmpty else {
            throw PawnLibraryError.nothingFoundAgain(prepared.file.lastPathComponent)
        }
        return try commit(prepared)
    }

    /// The paths each PDF an older reader read was imported from, by source ID. A PDF moved in counts until it is
    /// read; one imported here only while the library still has it, so a PDF the user removed stays removed.
    private var originalsToReadAgain: [String: [String]] {
        var paths: [String: [String]] = [:]
        for (sourceID, path) in own.readAgain where readerVersion(of: sourceID) ?? 0 < PawnExtractor.version {
            paths[sourceID, default: []].append(path)
        }
        for (path, file) in own.importedFiles where readerVersion(of: file.digest) ?? .max < PawnExtractor.version {
            paths[file.digest, default: []].append(path)
        }
        return paths
    }

    private func readerVersion(of sourceID: String) -> Int? { sharedSources[sourceID]?.readerVersion }
}

private extension URL {
    var isBattleCards: Bool { lastPathComponent.localizedCaseInsensitiveContains("Battle Cards") }
}
