import ArtExtraction
import Foundation

/// A painting printed both on a Battle Card and as a pawn (or in two decks) is one pawn. Its pictures differ,
/// the card's being several times sharper and cut differently, so it is recognized by its name and colors
/// rather than by its images, and drawn from whichever picture is sharper.
extension PawnLibrary {
    /// An imported pawn showing the same painting as a pawn in the library.
    struct PaintingMatch {
        let found: ExtractedPawn
        let source: PawnSource
        let foundFigure: Figure
        /// The library pawn, and its figure.
        let index: Int
        let figure: Figure
    }

    /// The library pawn with the same name showing the same painting as `found`, when either is from a Battle
    /// Card. Printed pawns of the same name are told apart by their images alone (see `ArtFingerprint`).
    func samePainting(as found: ExtractedPawn, from source: PawnSource) -> PaintingMatch? {
        let foundIsCard = found.shape.isCard
        let candidates = pawnsNamed(like: found.name).filter { index in
            let pawn = pawns[index]
            return !pawn.needsName && (foundIsCard || pawn.art.isCard) && pawn.art.showsFigure
                && Self.namesMatch(pawn.name, found.name)
        }
        guard !candidates.isEmpty, let foundFigure = figures.figure(of: found, source: source.id) else { return nil }
        let palette = foundFigure.palette()
        for index in candidates {
            guard let figure = figures.figure(of: pawns[index]),
                  Figure.paletteDistance(palette, figure.palette()) <= Figure.samePaintingDistance
            else { continue }
            return PaintingMatch(found: found, source: source, foundFigure: foundFigure, index: index, figure: figure)
        }
        return nil
    }

    /// Adds the imported pawn's product to the library pawn, and its traits; the pawn is drawn from the
    /// imported picture when it is sharper. A printed pawn's outline gives the size.
    func merge(_ match: PaintingMatch, into report: inout ImportReport) throws {
        let found = match.found
        let appearance = Appearance(sourceID: match.source.id, copies: found.copies)
        var pawn = pawns[match.index]
        report.alreadyKnown += 1
        // Read again by a newer reader, a product the pawn already lists adds nothing.
        guard !pawn.appearances.contains(where: { $0.sourceID == match.source.id }) else { return }
        if match.foundFigure.pixelArea > match.figure.pixelArea {
            pawn.art = try art(of: found, from: match.source)
            pawn.appearances.insert(appearance, at: 0)
            report.sharpened += 1
        } else {
            pawn.appearances.append(appearance)
        }
        if case .pawn = found.shape { pawn.size = found.size }
        pawn.traits = Self.combined(pawn.traits, found.traits)
        pawns[match.index] = pawn
    }

    /// The first traits, then those of the second not among them.
    static func combined(_ first: [String], _ second: [String]) -> [String] {
        first + second.filter { !first.contains($0) }
    }

    /// True when two names can be the same creature's. Products differ in how much of its family they print, so
    /// "Elemental, Air, Invisible Stalker", "Elemental, Invisible Stalker" and "Invisible Stalker" match; but
    /// when both print a family it must be the same, so "Giant, Wood" is not "Golem, Wood".
    static func namesMatch(_ first: String, _ second: String) -> Bool {
        let parts = [first, second].map { name in
            name.split(separator: ",").map {
                $0.trimmingCharacters(in: .whitespaces).folding(options: [.caseInsensitive, .diacriticInsensitive],
                                                               locale: nil)
            }
        }
        guard parts[0].last == parts[1].last else { return false }
        return parts[0].count == 1 || parts[1].count == 1 || parts[0].first == parts[1].first
    }

    /// The indexes of pawns whose name could be `name`'s, as `nameKey` compares them.
    private func pawnsNamed(like name: String) -> [Int] {
        if paintingIndex == nil {
            paintingIndex = Dictionary(grouping: pawns.indices) { Self.nameKey(pawns[$0].name) }
        }
        return paintingIndex?[Self.nameKey(name)] ?? []
    }

    /// Notes a pawn just added at `index` for `pawnsNamed(like:)`.
    func indexPainting(at index: Int) {
        paintingIndex?[Self.nameKey(pawns[index].name), default: []].append(index)
    }

    /// The part of a name after its last comma, ignoring case and accents, which names that match (see
    /// `namesMatch`) share.
    static func nameKey(_ name: String) -> String {
        let last = name.split(separator: ",").last.map(String.init) ?? name
        return last.trimmingCharacters(in: .whitespaces)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}

extension Pawn {
    /// True when `found` prints this pawn's art: its images match. When either is from a Battle Card, only the
    /// same images count, since a card's picture and a pawn's are compared as paintings (`samePainting`).
    func printsSameArt(as found: ExtractedPawn) -> Bool {
        guard art.isCard || found.shape.isCard else { return fingerprint.matches(found.fingerprint) }
        return !found.fingerprint.imageDigests.isEmpty && fingerprint.imageDigests == found.fingerprint.imageDigests
    }
}

extension PrintedShape {
    var isCard: Bool {
        if case .card = self { return true }
        return false
    }
}

extension PawnArt {
    var isCard: Bool {
        if case .card = self { return true }
        return false
    }

    /// True for art showing a creature's picture as printed: a pawn's or a card's, not a token's or the user's.
    var showsFigure: Bool {
        switch self {
        case .pdf, .card: true
        case .token, .custom: false
        }
    }
}
