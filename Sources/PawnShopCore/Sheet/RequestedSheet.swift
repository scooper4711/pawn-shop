import ArtExtraction
import Foundation
import TablesideShared

extension PawnSheet {
    /// The sheet another app asked for (R13): each line's pawn with its count, found with `pawn`, which answers
    /// to a pawn's own ID, a print's key or an old ID (`PawnLibrary.pawn(id:)`). A line whose pawn isn't found
    /// becomes a placeholder that says the creature's name.
    public init(request: PawnSheetRequest, pawn: (UUID) -> Pawn?) {
        self.init()
        for line in request.lines where line.count >= 1 {
            if let found = line.pawnID.flatMap(pawn) {
                add(found.id, copies: line.count)
            } else {
                entries.append(.placeholder(for: line))
            }
        }
    }
}

private extension SheetEntry {
    /// An entry for a pawn the library lacks, under the ID the line names so that it shows the pawn once the
    /// library has it, or under a new ID when the line names none.
    static func placeholder(for line: PawnSheetRequest.Line) -> SheetEntry {
        let pawnID = line.pawnID ?? UUID()
        var entry = SheetEntry(pawnID: pawnID, count: line.count)
        entry.label = ArtReference(id: pawnID, name: line.name, product: "")
        return entry
    }
}
