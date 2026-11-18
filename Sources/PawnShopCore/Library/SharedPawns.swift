import ArtExtraction
import Foundation
import SharedLibraries

/// Pawns, item art and sources as the shared art library holds them (tabletop-kit shared libraries R3).
extension Pawn {
    /// The pawn showing a piece of creature art, with what is noted about it, drawn from the sharpest print in a
    /// PDF Pawn Shop can reach (`reachable`), or else from the art's picture (R2.1.2).
    init(entry: SharedArtEntry, note: ArtNote?, reachable: Set<String>) {
        let drawn = Self.drawnPrint(of: entry, reachable: reachable)
        self.init(id: entry.id, name: note?.userName ?? entry.name, size: entry.size,
                  art: Self.art(of: entry, drawnFrom: drawn), fingerprint: entry.fingerprint,
                  appearances: Self.appearances(of: entry, drawnFrom: drawn),
                  needsName: entry.needsName && note?.userName == nil)
        traits = entry.traits
        if let note {
            tags = note.tags
            tagModel = note.tagModel
            suggestedName = note.suggestedName
            tagsCorrected = note.isCorrected
        }
    }

    /// The note to save for an extracted pawn: its name when it isn't the one printed, its tags and suggestion.
    func note(printedName: String) -> ArtNote {
        ArtNote(userName: name == printedName ? nil : name, tags: tags, tagModel: tagModel,
                suggestedName: suggestedName, isCorrected: tagsCorrected)
    }

    /// The print a pawn is drawn from: a Battle Card's figure, else a pawn, else a token; nil when Pawn Shop can
    /// reach none of their PDFs and has no token picture.
    static func drawnPrint(of entry: SharedArtEntry, reachable: Set<String>) -> SharedPrint? {
        for kind in [ArtKind.figure, .pawn] {
            let print = entry.prints.first { $0.print.kind == kind && reachable.contains($0.print.sourceID) }
            if let print { return print }
        }
        return entry.prints.first { $0.print.kind == .token && $0.print.tokenFile != nil }
    }

    private static func art(of entry: SharedArtEntry, drawnFrom print: SharedPrint?) -> PawnArt {
        guard let print else {
            let sourceID = entry.prints.first?.print.sourceID ?? ""
            return .token(TokenArt(sourceID: sourceID, frontPicture: entry.picture ?? ""))
        }
        let face = print.print.face
        switch print.print.kind {
        case .figure:
            return .card(CardArt(sourceID: print.print.sourceID, face: face, imageIndex: print.print.imageIndex ?? 0))
        case .token:
            return .token(TokenArt(sourceID: print.print.sourceID, frontPicture: print.print.tokenFile ?? "",
                                   backPicture: print.backPicture))
        case .pawn, .item:
            return .pdf(sourceID: print.print.sourceID, front: face, back: print.back ?? face.mirroredCopy())
        }
    }

    /// Each product printing the art once, with its copies, the one it is drawn from first.
    private static func appearances(of entry: SharedArtEntry, drawnFrom print: SharedPrint?) -> [Appearance] {
        let first = print?.print.sourceID ?? entry.prints.first?.print.sourceID
        var appearances: [Appearance] = []
        let drawnFirst = entry.prints.filter { $0.print.sourceID == first }
        let ordered = drawnFirst + entry.prints.filter { $0.print.sourceID != first }
        for print in ordered {
            if let index = appearances.firstIndex(where: { $0.sourceID == print.print.sourceID }) {
                appearances[index].copies += print.print.copies
            } else {
                appearances.append(Appearance(sourceID: print.print.sourceID, copies: print.print.copies))
            }
        }
        return appearances
    }
}

extension ItemArtwork {
    /// The art of an item from an item deck: its first print, a picture in a kept PDF or one drawn at import.
    init?(entry: SharedArtEntry) {
        guard let print = entry.prints.first(where: { $0.print.kind == .item }) else { return nil }
        let picture: ItemPicture
        if let imageIndex = print.print.imageIndex {
            picture = .figure(face: print.print.face, imageIndex: imageIndex)
        } else if let file = print.print.tokenFile {
            picture = .drawn(file: file)
        } else {
            return nil
        }
        self.init(id: entry.id, name: entry.name, sourceID: print.print.sourceID, picture: picture,
                  fingerprint: entry.fingerprint)
    }
}

extension PawnSource {
    /// A PDF in the shared library, as the library lists it; its import date and path aren't kept there.
    init(_ source: SharedSource) {
        self.init(id: source.id, title: source.title, importedAt: .distantPast, originalPath: "",
                  byteCount: source.byteCount, pawnsFound: source.artFound, readerVersion: source.readerVersion)
    }
}
