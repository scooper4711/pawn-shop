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
    /// Adds an extracted pawn: as another product printing art the library has, by giving its name to
    /// nameless art, as a Battle Card or pawn showing the same painting as one in the library, or as a new pawn.
    func merge(_ found: ExtractedPawn, from source: PawnSource, into report: inout ImportReport) throws {
        let appearance = Appearance(sourceID: source.id, copies: found.copies)
        if found.name.isEmpty {
            try mergeNameless(found, from: source, into: &report)
        } else if let index = pawns.firstIndex(where: {
            $0.name == found.name && $0.size == found.size && $0.printsSameArt(as: found)
        }) {
            pawns[index].appearances.append(appearance)
            pawns[index].traits = Self.combined(pawns[index].traits, found.traits)
            report.alreadyKnown += 1
        } else if let index = waitingForName(sameArtAs: found) {
            pawns[index].name = found.name
            pawns[index].needsName = false
            pawns[index].appearances.append(appearance)
            paintingIndex = nil
            report.alreadyKnown += 1
        } else if let match = samePainting(as: found, from: source) {
            try merge(match, into: &report)
        } else {
            try add(found, from: source, into: &report)
        }
    }

    private func mergeNameless(_ found: ExtractedPawn, from source: PawnSource,
                               into report: inout ImportReport) throws {
        let appearance = Appearance(sourceID: source.id, copies: found.copies)
        if NamelessProducts.contains(source), let index = pawns.firstIndex(where: {
            !$0.needsName && !$0.isCustom && $0.size == found.size && $0.fingerprint.isSameArt(as: found.fingerprint)
        }) {
            pawns[index].appearances.append(appearance)
            report.namedFromOtherProducts += 1
        } else if let index = pawns.firstIndex(where: {
            $0.needsName && $0.size == found.size && $0.fingerprint.matches(found.fingerprint)
        }) {
            pawns[index].appearances.append(appearance)
            report.alreadyKnown += 1
        } else {
            var nameless = found
            nameless.name = NamelessProducts.standInName(for: source)
            try add(nameless, from: source, into: &report)
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

    /// Adds a new pawn; one carrying a stand-in name is marked as needing a name.
    private func add(_ found: ExtractedPawn, from source: PawnSource, into report: inout ImportReport) throws {
        let needsName = found.name == NamelessProducts.standInName(for: source)
        let appearance = Appearance(sourceID: source.id, copies: found.copies)
        var pawn = Pawn(name: found.name, size: found.size, art: try art(of: found, from: source),
                        fingerprint: found.fingerprint, appearances: [appearance], needsName: needsName)
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
