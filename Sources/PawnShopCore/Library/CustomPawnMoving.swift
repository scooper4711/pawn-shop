import Foundation
import SharedLibraries

/// Moving the custom pawns into the creature library, once (R3.7, tabletop-kit shared libraries R6.6). It is a
/// step of its own: the move of `library.json` (`LibraryMoving.swift`) left them in `pawn-shop.json`, and a
/// library that moved in before this has that move recorded as finished.
extension PawnLibrary {
    /// Moves the custom pawns `pawn-shop.json` still lists: each one's image, then its creature under the pawn's
    /// ID, then what stays Pawn Shop's own. Every step is skipped when done, so a move cut short finishes at the
    /// next launch.
    func moveCustomPawnsIfNeeded() throws {
        guard !own.customPawns.isEmpty else { return }
        let known = Set(try shared.customCreatures().map(\.id))
        for pawn in own.customPawns {
            guard case .custom(let art) = pawn.art else { continue }
            // The image first, so a creature another app or device sees always has its image.
            try moveImage(named: art.imageFile)
            if !known.contains(pawn.id) {
                try addCreature(NewCreature(pawn: pawn, size: CreatureSize(pawn.size)), imageFile: art.imageFile)
            }
            keepMovedSettings(of: pawn)
        }
        own.customPawns = []
        try own.save(to: folder)
        removeEmptiedCustomFolder()
    }

    // MARK: Helpers

    /// Moves an image from Pawn Shop's custom folder into the shared library's. One already there, as one
    /// another device moved and synced, stays, and Pawn Shop's copy is deleted; one that is gone is passed over.
    private func moveImage(named file: String) throws {
        let files = FileManager.default
        let old = folders.ownCustom.appendingPathComponent(file)
        let moved = shared.customFile(file)
        guard files.fileExists(atPath: old.path) else { return }
        do {
            if files.fileExists(atPath: moved.path) {
                try files.removeItem(at: old)
            } else {
                try files.moveItem(at: old, to: moved)
            }
        } catch {
            throw PawnLibraryError.saveFailed("moving \(file) into the shared library: \(error.localizedDescription)")
        }
    }

    /// Keeps a moved pawn's placement and tags, unless settings for it are here already. The time of its last
    /// change stays as it was, so the move itself isn't a change to send over another device's.
    private func keepMovedSettings(of pawn: Pawn) {
        let key = pawn.id.uuidString
        let settings = CustomPawnSettings().taking(pawn)
        guard own.pawnSettings[key] == nil, settings != CustomPawnSettings() else { return }
        own.pawnSettings[key] = settings
    }

    private func removeEmptiedCustomFolder() {
        let files = FileManager.default
        guard (try? files.contentsOfDirectory(atPath: folders.ownCustom.path))?.isEmpty == true else { return }
        try? files.removeItem(at: folders.ownCustom)
    }
}
