import ArtExtraction
import Foundation

/// Reading a PDF again when the reader improves (`PawnExtractor.version`): a PDF that gave no pawns is imported
/// afresh, and one that gave some keeps them, with their names, tags and corrections, and gains those found anew.
extension PawnLibrary {
    /// True when an older reader (`PawnExtractor.version`) read the source, so the current one may find more.
    func isWorthRereading(_ source: PawnSource) -> Bool {
        (source.readerVersion ?? 0) < PawnExtractor.version
    }

    /// True when pawns in the library come from the source.
    func hasPawns(from source: PawnSource) -> Bool {
        pawns.contains { $0.appearances.contains { $0.sourceID == source.id } }
    }

    /// Reads a source again with a newer reader, adding the pawns it finds anew and keeping those it had, with
    /// their names, tags and corrections.
    func reread(_ known: PawnSource, as prepared: PreparedImport,
                into report: ImportReport) throws -> ImportReport {
        var report = report
        report.reread = true
        guard let index = sources.firstIndex(where: { $0.id == known.id }) else { return report }
        sources[index].readerVersion = PawnExtractor.version
        sources[index].pawnsFound = prepared.extraction.pawns.count
        let source = sources[index]
        defer {
            figures.forgetPages()
            paintingIndex = nil
        }
        for found in prepared.extraction.pawns where !hasPawn(found, from: source) {
            try merge(found, from: source, into: &report)
        }
        try save()
        return report
    }

    /// True when the library has `found` from `source` already: the same size and art, from that product.
    private func hasPawn(_ found: ExtractedPawn, from source: PawnSource) -> Bool {
        pawns.contains { pawn in
            pawn.appearances.contains { $0.sourceID == source.id } && pawn.size == found.size
                && pawn.fingerprint.matches(found.fingerprint)
        }
    }
}
