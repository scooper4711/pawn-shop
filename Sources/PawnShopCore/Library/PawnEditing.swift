import Foundation
import SharedLibraries

/// Changing pawns: an extracted pawn's name, tags and suggestion are a note on its art in the shared library
/// (R2.1.1); custom pawns are Pawn Shop's own (`OwnLibrary`).
extension PawnLibrary {
    /// Adds a pawn made from the user's own art and saves.
    public func add(_ pawn: Pawn) throws {
        own.customPawns.append(pawn)
        try saveOwn()
    }

    /// Replaces the pawn with the same id and saves: a custom pawn in Pawn Shop's library, an extracted one's
    /// name, tags and suggestion as its art's note.
    public func update(_ pawn: Pawn) throws {
        if let index = own.customPawns.firstIndex(where: { $0.id == pawn.id }) {
            own.customPawns[index] = pawn
            try saveOwn()
        } else if let entry = entries[pawn.id] {
            try shared.setNote(pawn.note(printedName: entry.name), forArt: entry.id)
            unsavedNotes.remove(pawn.id)
            try refresh()
        }
    }

    /// Renames a pawn and saves; a blank name is ignored.
    public func rename(_ id: UUID, to name: String) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, var pawn = pawn(id: id) else { return }
        pawn.name = trimmed
        pawn.needsName = false
        pawn.suggestedName = ""
        try update(pawn)
    }

    /// Records the tags `model` chose for a pawn, without saving, since tagging a whole library would otherwise
    /// write it out once per pawn; call `save()` after a batch. Tags the user corrected are kept.
    public func setTags(_ tags: [String], by model: String, of id: UUID) {
        change(id) { pawn in
            guard !pawn.tagsCorrected else { return }
            pawn.tags = tags
            pawn.tagModel = model
        }
    }

    /// Replaces a pawn's tags with the user's own, which tagging then keeps, and saves.
    public func correctTags(_ tags: [String], of id: UUID) throws {
        guard var pawn = pawn(id: id) else { return }
        pawn.tags = PawnTags.cleaned(tags)
        pawn.tagsCorrected = true
        try update(pawn)
    }

    /// Records the name the model suggests for a pawn needing one, without saving, like `setTags`.
    public func setSuggestedName(_ name: String, of id: UUID) {
        change(id) { $0.suggestedName = name }
    }

    /// Removes pawns and saves: custom pawns with their art, extracted ones from Pawn Shop only (R2.5).
    public func remove(_ ids: Set<UUID>) throws {
        for pawn in own.customPawns where ids.contains(pawn.id) {
            if case .custom(let art) = pawn.art {
                try? FileManager.default.removeItem(at: customFolder.appendingPathComponent(art.imageFile))
            }
        }
        own.customPawns.removeAll { ids.contains($0.id) }
        own.hidden.formUnion(ids.compactMap { pawn(id: $0)?.id }.filter { entries[$0] != nil })
        try saveOwn()
    }

    /// Saves the notes `setTags` and `setSuggestedName` recorded, and the custom pawns.
    public func save() throws {
        for id in unsavedNotes.sorted(by: { $0.uuidString < $1.uuidString }) {
            guard let pawn = pawn(id: id), let entry = entries[id] else { continue }
            try shared.setNote(pawn.note(printedName: entry.name), forArt: id)
        }
        unsavedNotes = []
        try saveOwn()
        try refresh()
    }

    // MARK: Helpers

    /// Changes a pawn in memory, to be saved by `save()`.
    private func change(_ id: UUID, _ edit: (inout Pawn) -> Void) {
        guard let current = pawn(id: id), let index = pawnIndexes[current.id] else { return }
        edit(&pawns[index])
        if let custom = own.customPawns.firstIndex(where: { $0.id == current.id }) {
            own.customPawns[custom] = pawns[index]
        } else {
            notes[current.id] = pawns[index].note(printedName: entries[current.id]?.name ?? pawns[index].name)
            unsavedNotes.insert(current.id)
        }
    }

    func saveOwn() throws {
        try own.save(to: folder)
        rebuild()
    }
}
