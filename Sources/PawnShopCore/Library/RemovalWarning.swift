import Foundation
import SharedLibraries

/// What Remove from Library asks before it deletes custom pawns (R2.5).
public struct RemovalWarning: Equatable, Sendable {
    public var title: String
    public var message: String
}

extension PawnLibrary {
    /// The question to ask before removing `ids`; nil when removing them deletes nothing, only hides pawns the
    /// other apps keep. Pawn Shop can't see Turnkeeper's encounters, so it names them whenever Turnkeeper shares
    /// the library on this device (shared libraries R4.9).
    public func removalWarning(for ids: Set<UUID>) -> RemovalWarning? {
        let names = Set(ids.compactMap { pawn(id: $0) }.filter { isDeletedWhenRemoved($0.id) }).map(\.name)
        guard let name = names.first else { return nil }
        let isOne = names.count == 1
        var message = "This deletes " + (isOne ? "the custom pawn and its art." : "the custom pawns and their art.")
        if (try? shared.hasMovedIn(.turnkeeper)) == true {
            message += isOne ? " Its creature will be deleted from Turnkeeper and removed from all its encounters."
                             : " Their creatures will be deleted from Turnkeeper and removed from all its encounters."
        }
        return RemovalWarning(title: isOne ? "Delete “\(name)”?" : "Delete \(names.count) custom pawns?",
                              message: message + " This can't be undone.")
    }
}
