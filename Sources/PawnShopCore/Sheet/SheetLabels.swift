import ArtExtraction
import Foundation

extension PawnLibrary {
    /// The sheet with each pawn it finds pointed at by the pawn's own ID, not an alias, and labeled with its name
    /// and product (`SheetEntry.label`). Pawns it doesn't find keep their IDs and labels.
    public func labeled(_ sheet: PawnSheet) -> PawnSheet {
        var labeled = sheet
        for index in labeled.entries.indices {
            guard let pawnID = labeled.entries[index].pawnID, let pawn = pawn(id: pawnID) else { continue }
            labeled.entries[index].content = .pawn(pawn.id)
            labeled.entries[index].label = reference(to: pawn)
        }
        return labeled
    }

    /// The pawn's ID and name, and the title of the product its art comes from; no title for a custom pawn.
    func reference(to pawn: Pawn) -> ArtReference {
        let sourceID = pawn.art.sourceID ?? pawn.appearances.first?.sourceID
        return ArtReference(id: pawn.id, name: pawn.name, product: sourceID.flatMap(source(id:))?.title ?? "")
    }
}
