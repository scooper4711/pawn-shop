import ArtExtraction
import Foundation

/// Stable pawn IDs (shared libraries R2) for a version 1 library: each extracted pawn's ID becomes its art's key, so
/// every device that imports a PDF gives its pawns the same IDs. Old IDs stay as aliases.
extension StoredLibrary {
    /// Gives each extracted pawn its key, merging pawns that share one, and keeps each old ID as an alias. Custom
    /// pawns keep their IDs.
    mutating func rekeyPawns() {
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
        version = Self.currentVersion
    }

    /// What a library pawn's key is made from: its first print, with the name printed there. A product printing no
    /// names (`NamelessProducts`) printed none, whatever the pawn is called now.
    func keyInput(for pawn: Pawn) -> ArtKeyInput {
        let sourceID = pawn.art.sourceID ?? pawn.appearances.first?.sourceID ?? ""
        return ArtKeyInput(sourceID: sourceID, name: isNameless(pawn) ? "" : pawn.name, size: pawn.size,
                           fingerprint: pawn.fingerprint, face: pawn.art.front)
    }

    /// True when the pawn's art came with no name: it still needs one, or its product prints none.
    func isNameless(_ pawn: Pawn) -> Bool {
        let sourceID = pawn.art.sourceID ?? pawn.appearances.first?.sourceID ?? ""
        let title = sources.first { $0.id == sourceID }?.title ?? ""
        return pawn.needsName || NamelessProducts.contains(title: title)
    }
}

extension Pawn {
    /// Takes in another pawn with the same key: its products and traits.
    mutating func absorb(_ other: Pawn) {
        other.appearances.forEach { add($0) }
        traits += other.traits.filter { !traits.contains($0) }
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
