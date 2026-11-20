import ArtExtraction
import Foundation
import SharedLibraries

/// A custom creature as Pawn Shop reads it (R3.4): what every app shows of it, never its stat block.
struct CustomCreature: Equatable {
    var name: String
    /// Nil when its size isn't one of Paizo's six: it then prints as Medium.
    var size: CreatureSize?
    /// A creature Turnkeeper gave a stat block is hidden, not deleted, when its pawn is removed (R2.5).
    var hasStatBlock: Bool

    init(_ record: CustomCreatureRecord) {
        name = record.name
        size = record.size
        hasStatBlock = record.hasStatBlock
    }
}

extension CreatureSize {
    /// The creature size printing a pawn of `size`: the one of the same name.
    init(_ size: PawnSize) {
        self = CreatureSize(rawValue: size.rawValue) ?? .medium
    }
}

/// Custom pawns as the creature library holds them (R3.5, tabletop-kit shared libraries R4.4): every custom
/// creature with art is a pawn, whichever app made it.
extension PawnLibrary {
    private static let creatureTables: Set<LibraryTable> = [.customCreatures, .customArt, .creatureArt]
    private static let customSubjectPrefix = "custom."

    /// Reads every custom creature, the images the user added and the art chosen for each creature.
    func readCreatures() throws {
        creatures = [:]
        customArtFiles = [:]
        try readCreatures(changedSince: 0)
    }

    /// Reads the custom creatures and images changed since the library was last read, when `changes` says any
    /// were. A creature deleted, by another app or another device, takes what Pawn Shop kept about it.
    func readCreatures(changed changes: LibraryChanges) throws {
        let tables = Self.creatureTables
        let hasDeletions = tables.contains { changes.deletions[$0] != nil }
        guard hasDeletions || !changes.changedTables.isDisjoint(with: tables) else { return }
        try readCreatures(changedSince: counter)
        for id in Self.ids(changes.deletions[.customArt]) { customArtFiles[id] = nil }
        let deleted = Self.ids(changes.deletions[.customCreatures])
        deleted.forEach { creatures[$0] = nil }
        if forgetCustomPawns(Set(deleted)) { try own.save(to: folder) }
    }

    /// The custom creatures' pawns, by name, then ID: each creature with art that isn't hidden here.
    func creaturePawns(reachable: Set<String>) -> [Pawn] {
        creatureArt.compactMap { id, choice -> Pawn? in
            guard let creature = creatures[id], !own.hidden.contains(id),
                  var pawn = drawnPawn(choice, reachable: reachable) else { return nil }
            pawn.id = id
            pawn.name = creature.name
            pawn.size = creature.size?.pawnSize ?? .medium
            pawn.needsName = false
            pawn.isCustomCreature = true
            let settings = settings(ofCustomPawn: id)
            pawn.tags = settings.tags
            pawn.tagModel = settings.tagModel
            pawn.tagsCorrected = settings.tagsCorrected
            if case .custom(let art) = pawn.art { pawn.art = .custom(settings.art(imageFile: art.imageFile)) }
            return pawn
        }
        .sorted(by: Self.isOrdered)
    }

    /// What Pawn Shop keeps about a custom pawn, or the defaults.
    func settings(ofCustomPawn id: UUID) -> CustomPawnSettings {
        own.pawnSettings[id.uuidString] ?? CustomPawnSettings()
    }

    /// Forgets what Pawn Shop kept about custom pawns whose creatures are gone, without saving. Their settings'
    /// records are then deleted from iCloud. True when there was anything to forget.
    @discardableResult
    func forgetCustomPawns(_ ids: Set<UUID>) -> Bool {
        var isChanged = false
        for id in ids {
            let hadSettings = own.pawnSettings.removeValue(forKey: id.uuidString) != nil
            if hadSettings { customPawnChanges += 1 }
            own.customPawnsModified[id.uuidString] = nil
            isChanged = own.hidden.remove(id) != nil || hadSettings || isChanged
        }
        return isChanged
    }

    // MARK: Helpers

    private func readCreatures(changedSince counter: Int64) throws {
        for creature in try shared.customCreatures(changedSince: counter) {
            creatures[creature.id] = CustomCreature(creature)
        }
        for art in try shared.customArt(changedSince: counter) { customArtFiles[art.id] = art.fileName }
        creatureArt = [:]
        for (subject, choice) in try shared.creatureArt() where subject.hasPrefix(Self.customSubjectPrefix) {
            guard let id = UUID(uuidString: String(subject.dropFirst(Self.customSubjectPrefix.count))) else { continue }
            creatureArt[id] = choice
        }
    }

    /// The pawn the art chosen for a creature draws: the user's image, or the pawn of art chosen from the
    /// library, which prints as its PDF prints it. Nil while the image's record or the art isn't here.
    private func drawnPawn(_ choice: CreatureArtChoice, reachable: Set<String>) -> Pawn? {
        switch choice {
        case .custom(let artID):
            guard let file = customArtFiles[artID] else { return nil }
            return Pawn(name: "", size: .medium, art: .custom(CustomArt(imageFile: file)))
        case .library(let artID):
            guard let entry = entries[artID] ?? printKeys[artID].flatMap({ entries[$0] }) else { return nil }
            return Pawn(entry: entry, note: nil, reachable: reachable)
        }
    }

    private static func ids(_ keys: [String]?) -> [UUID] {
        (keys ?? []).compactMap { UUID(uuidString: $0) }
    }
}
