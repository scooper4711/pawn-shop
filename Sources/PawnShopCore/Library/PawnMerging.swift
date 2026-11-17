import ArtExtraction
import Foundation

/// Products that print no names on their pawns. Their pawns borrow the name of the same art printed in
/// another product; the rest wait, under a stand-in name, for the user to name them.
enum NamelessProducts {
    static let titleFragments = ["Heroes & Villains"]

    static func contains(_ source: PawnSource) -> Bool {
        titleFragments.contains { source.title.localizedCaseInsensitiveContains($0) }
    }

    /// The stand-in name for a pawn with no name printed.
    static func standInName(for source: PawnSource) -> String { "Unknown \(source.title)" }
}

extension ArtFingerprint {
    /// Thumbnails at most this far apart are taken for the same art when giving a pawn another product's name.
    /// Stricter than `matchingDistance`, which also requires equal names: across the whole library, pawns
    /// up to about 15 apart showed the same figure and those from about 16 on did not.
    static let namingDistance = 15.0

    /// True when both show the same images, or look the same by the stricter naming distance.
    func isSameArt(as other: ArtFingerprint) -> Bool {
        guard !imageDigests.isEmpty, !other.imageDigests.isEmpty else { return false }
        return imageDigests == other.imageDigests || thumbnailDistance(from: other) <= Self.namingDistance
    }
}

extension PawnLibrary {
    /// Adds an extracted pawn: as a print of art the library has by its key, as another product printing art the
    /// library has, by giving its name to nameless art, as a Battle Card or pawn showing the same painting as one in
    /// the library, or as a new pawn. A print merged into a pawn under another key leaves that key as an alias.
    func merge(_ print: FoundPrint, into report: inout ImportReport) throws {
        let found = print.pawn
        if found.shape.isItem {
            try mergeItem(found, from: print.source, into: &report)
        } else if let index = pawnIndex(answeringTo: print.key) {
            addPrint(print, to: index)
            report.alreadyKnown += 1
        } else if found.name.isEmpty {
            try mergeNameless(print, into: &report)
        } else if let index = pawns.firstIndex(where: {
            $0.name == found.name && $0.size == found.size && $0.printsSameArt(as: found)
        }) {
            addPrint(print, to: index)
            report.alreadyKnown += 1
        } else if let index = waitingForName(sameArtAs: found) {
            pawns[index].name = found.name
            pawns[index].needsName = false
            addPrint(print, to: index)
            paintingIndex = nil
            report.alreadyKnown += 1
        } else if let match = samePainting(as: print) {
            try merge(match, into: &report)
        } else {
            try add(print, into: &report)
        }
    }

    /// Adds another product printing a library pawn's art, its traits, and its key as an alias.
    private func addPrint(_ print: FoundPrint, to index: Int) {
        pawns[index].add(print.appearance)
        pawns[index].traits = Self.combined(pawns[index].traits, print.pawn.traits)
        recordKey(print.key, of: index)
    }

    private func mergeNameless(_ print: FoundPrint, into report: inout ImportReport) throws {
        let found = print.pawn
        if NamelessProducts.contains(print.source), let index = pawns.firstIndex(where: {
            !$0.needsName && !$0.isCustom && $0.size == found.size && $0.fingerprint.isSameArt(as: found.fingerprint)
        }) {
            addPrint(print, to: index)
            report.namedFromOtherProducts += 1
        } else if let index = pawns.firstIndex(where: {
            $0.needsName && $0.size == found.size && $0.fingerprint.matches(found.fingerprint)
        }) {
            addPrint(print, to: index)
            report.alreadyKnown += 1
        } else {
            var nameless = print
            nameless.pawn.name = NamelessProducts.standInName(for: print.source)
            try add(nameless, into: &report)
        }
    }

    /// A pawn from a nameless product still waiting for its name whose art matches `found`.
    private func waitingForName(sameArtAs found: ExtractedPawn) -> Int? {
        pawns.firstIndex { pawn in
            guard pawn.needsName, pawn.size == found.size, pawn.fingerprint.isSameArt(as: found.fingerprint),
                  let sourceID = pawn.appearances.first?.sourceID, let source = source(id: sourceID)
            else { return false }
            return NamelessProducts.contains(source)
        }
    }

    /// Adds a new pawn, with its print's key as its ID; one carrying a stand-in name is marked as needing a name.
    private func add(_ print: FoundPrint, into report: inout ImportReport) throws {
        let found = print.pawn
        let needsName = found.name == NamelessProducts.standInName(for: print.source)
        var pawn = Pawn(id: print.key, name: found.name, size: found.size, art: try art(of: found, from: print.source),
                        fingerprint: found.fingerprint, appearances: [print.appearance], needsName: needsName)
        pawn.traits = found.traits
        pawns.append(pawn)
        indexPainting(at: pawns.count - 1)
        report.added += 1
        if needsName { report.needingNames += 1 }
    }

    /// The art of a new pawn; a token's pictures are written to the token folder.
    func art(of found: ExtractedPawn, from source: PawnSource) throws -> PawnArt {
        switch found.shape {
        case .pawn:
            return .pdf(sourceID: source.id, front: found.front, back: found.back)
        case .token(let pictures):
            return .token(TokenArt(sourceID: source.id, frontPicture: try writeTokenPicture(pictures.front),
                                   backPicture: try pictures.back.map(writeTokenPicture)))
        case .card(let imageIndex):
            return .card(CardArt(sourceID: source.id, face: found.front, imageIndex: imageIndex))
        case .item, .drawnItem:
            // `merge` keeps item art apart (`mergeItem`), so it never becomes a pawn.
            throw PawnLibraryError.saveFailed("adding item art \(found.name) as a pawn")
        }
    }

    private func writeTokenPicture(_ png: Data) throws -> String {
        let file = "\(UUID().uuidString).png"
        do {
            try png.write(to: folders.tokens.appendingPathComponent(file))
        } catch {
            throw PawnLibraryError.saveFailed("writing token picture \(file): \(error.localizedDescription)")
        }
        return file
    }
}
