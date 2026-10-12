import ArtExtraction
import Foundation

/// Keeping the item art an item deck prints (`ItemArtwork`), apart from the pawns.
extension PawnLibrary {
    /// Adds an item's art from `source` unless the library has it already, as when a deck is read again.
    func mergeItem(_ found: ExtractedPawn, from source: PawnSource, into report: inout ImportReport) throws {
        guard !found.name.isEmpty, !hasItemArt(found, from: source), let picture = try itemPicture(of: found)
        else { return }
        itemArt.append(ItemArtwork(name: found.name, sourceID: source.id, picture: picture,
                                   fingerprint: found.fingerprint))
        report.itemArtAdded += 1
    }

    /// True when the library has `found` from `source` already: the same name and images.
    private func hasItemArt(_ found: ExtractedPawn, from source: PawnSource) -> Bool {
        itemArt.contains {
            $0.sourceID == source.id && $0.name == found.name
                && $0.fingerprint.imageDigests == found.fingerprint.imageDigests
        }
    }

    /// Where the picture is: on its page, or written to the `Items` folder. Nil for a pawn, token or creature.
    private func itemPicture(of found: ExtractedPawn) throws -> ItemPicture? {
        switch found.shape {
        case .item(let imageIndex): return .figure(face: found.front, imageIndex: imageIndex)
        case .drawnItem(let png): return .drawn(file: try writeItemPicture(png))
        case .pawn, .token, .card: return nil
        }
    }

    private func writeItemPicture(_ png: Data) throws -> String {
        let file = "\(UUID().uuidString).png"
        do {
            try png.write(to: folders.items.appendingPathComponent(file))
        } catch {
            throw PawnLibraryError.saveFailed("writing item picture \(file): \(error.localizedDescription)")
        }
        return file
    }
}

extension PrintedShape {
    /// True for an item deck's art.
    var isItem: Bool {
        switch self {
        case .item, .drawnItem: true
        case .pawn, .token, .card: false
        }
    }
}
