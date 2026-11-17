import ArtExtraction
import Foundation

/// An extracted pawn with the key its print gets (`ArtKey`), and the product printing it, while importing.
struct FoundPrint {
    var pawn: ExtractedPawn
    let key: UUID
    let source: PawnSource

    var appearance: Appearance { Appearance(sourceID: source.id, copies: pawn.copies) }

    /// Each pawn of an extraction with its key, computed together so a picture printed in two sizes gets two.
    static func prints(of extraction: ExtractionResult, from source: PawnSource) -> [FoundPrint] {
        let inputs = extraction.pawns.map { found in
            ArtKeyInput(sourceID: source.id, name: found.name, size: found.size, fingerprint: found.fingerprint,
                        face: found.front)
        }
        return zip(extraction.pawns, ArtKey.keys(for: inputs)).map { FoundPrint(pawn: $0, key: $1, source: source) }
    }
}

/// Stable pawn IDs (shared libraries R2): an extracted pawn's ID is its art's key, so every device that imports a
/// PDF gives its pawns the same IDs. Old IDs, and the keys of other prints merged into a pawn, stay as aliases.
extension PawnLibrary {
    /// The pawn answering to `id`: by its own ID, or by an alias.
    public func pawn(id: UUID) -> Pawn? {
        pawnIndex(answeringTo: id).map { pawns[$0] }
    }

    func pawnIndex(answeringTo id: UUID) -> Int? {
        if let index = pawns.firstIndex(where: { $0.id == id }) { return index }
        guard let current = aliases[id] else { return nil }
        return pawns.firstIndex { $0.id == current }
    }

    /// Records that the pawn at `index` also answers to `key`, the key of another print merged into it.
    func recordKey(_ key: UUID, of index: Int) {
        guard key != pawns[index].id else { return }
        aliases[key] = pawns[index].id
    }

    /// Gives each extracted pawn of a version 1 library its key, merging pawns that share one, and keeps each old
    /// ID as an alias. Custom pawns keep their IDs.
    func rekeyPawns() {
        let extracted = pawns.indices.filter { !pawns[$0].isCustom }
        let keys = ArtKey.keys(for: extracted.map { keyInput(for: pawns[$0]) })
        let keyOf = Dictionary(uniqueKeysWithValues: zip(extracted, keys))
        var rekeyed: [Pawn] = []
        var indexOfKey: [UUID: Int] = [:]
        for (index, pawn) in pawns.enumerated() {
            guard let key = keyOf[index] else {
                rekeyed.append(pawn)
                continue
            }
            aliases[pawn.id] = key
            if let kept = indexOfKey[key] {
                rekeyed[kept].absorb(pawn)
            } else {
                var keyed = pawn
                keyed.id = key
                indexOfKey[key] = rekeyed.count
                rekeyed.append(keyed)
            }
        }
        pawns = rekeyed
    }

    /// What a library pawn's key is made from: its first print, with the name printed there. A product printing no
    /// names (`NamelessProducts`) printed none, whatever the pawn is called now.
    func keyInput(for pawn: Pawn) -> ArtKeyInput {
        let sourceID = pawn.art.sourceID ?? pawn.appearances.first?.sourceID ?? ""
        let isNameless = pawn.needsName || source(id: sourceID).map(NamelessProducts.contains) == true
        return ArtKeyInput(sourceID: sourceID, name: isNameless ? "" : pawn.name, size: pawn.size,
                           fingerprint: pawn.fingerprint, face: pawn.art.front)
    }

    /// Drops aliases of pawns no longer in the library.
    func forgetAliases(of ids: Set<UUID>) {
        aliases = aliases.filter { !ids.contains($0.value) }
    }
}

extension Pawn {
    /// Takes in another pawn with the same key: its products and traits.
    mutating func absorb(_ other: Pawn) {
        other.appearances.forEach { add($0) }
        traits = PawnLibrary.combined(traits, other.traits)
    }
}

extension PawnArt {
    /// The front face on the page; a token's art is kept as pictures, so it has none.
    var front: PawnFace {
        switch self {
        case .pdf(_, let front, _): front
        case .card(let art): art.face
        case .token, .custom: PawnFace(pageIndex: 0, rect: .zero, rotation: 0)
        }
    }
}
