import Foundation
import SharedLibraries

/// Changing pawns: an extracted pawn's name, tags and suggestion are a note on its art in the shared library
/// (R2.1.1); a custom pawn's name is its creature's, and its placement and tags are Pawn Shop's own (R3.6).
extension PawnLibrary {
    /// Saves a pawn's changes: a custom pawn's name as its creature's and the rest as Pawn Shop's settings, an
    /// extracted one's name, tags and suggestion as its art's note.
    public func update(_ pawn: Pawn) throws {
        if let creature = creatures[pawn.id] {
            if creature.name != pawn.name { try shared.renameCustomCreature(id: pawn.id, to: pawn.name) }
            keepSettings(of: pawn)
            try saveOwnAndRefresh()
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

    /// Removes pawns and saves (R2.5): a custom pawn's creature and art from every app, unless the creature has
    /// a stat block; that one, and a pawn read from a PDF, from Pawn Shop only. The app asks first
    /// (`removalWarning(for:)`).
    public func remove(_ ids: Set<UUID>) throws {
        let found = Set(ids.compactMap { pawn(id: $0)?.id })
        let deleted = found.filter(isDeletedWhenRemoved)
        for id in deleted.sorted(by: { $0.uuidString < $1.uuidString }) { try shared.removeCustomCreature(id: id) }
        forgetCustomPawns(deleted)
        own.hidden.formUnion(found.subtracting(deleted))
        try saveOwnAndRefresh()
    }

    /// True for a custom pawn whose creature only Pawn Shop knows anything about: it has no stat block.
    func isDeletedWhenRemoved(_ id: UUID) -> Bool {
        creatures[id]?.hasStatBlock == false
    }

    /// Saves the notes `setTags` and `setSuggestedName` recorded, and the custom pawns' settings.
    public func save() throws {
        for id in unsavedNotes.sorted(by: { $0.uuidString < $1.uuidString }) {
            guard let pawn = pawn(id: id), let entry = entries[id] else { continue }
            try shared.setNote(pawn.note(printedName: entry.name), forArt: id)
        }
        unsavedNotes = []
        try saveOwn()
        try refresh()
    }

    /// Keeps what is Pawn Shop's own about a custom pawn, without saving, and notes the change for syncing
    /// (R10.2) when there is one. A pawn with nothing but the defaults keeps no settings.
    func keepSettings(of pawn: Pawn) {
        let current = settings(ofCustomPawn: pawn.id)
        let settings = current.taking(pawn)
        guard settings != current else { return }
        own.pawnSettings[pawn.id.uuidString] = settings
        own.customPawnsModified[pawn.id.uuidString] = Date().timeIntervalSinceReferenceDate
        customPawnChanges += 1
    }

    // MARK: Helpers

    /// Changes a pawn in memory, to be saved by `save()`.
    private func change(_ id: UUID, _ edit: (inout Pawn) -> Void) {
        guard let current = pawn(id: id), let index = pawnIndexes[current.id] else { return }
        edit(&pawns[index])
        if creatures[current.id] != nil {
            keepSettings(of: pawns[index])
        } else {
            notes[current.id] = pawns[index].note(printedName: entries[current.id]?.name ?? pawns[index].name)
            unsavedNotes.insert(current.id)
        }
    }

    func saveOwn() throws {
        try own.save(to: folder)
        rebuild()
    }

    /// Saves Pawn Shop's own library and reads what a change just made to the shared one did.
    func saveOwnAndRefresh() throws {
        try own.save(to: folder)
        if try !refresh() { rebuild() }
    }
}
