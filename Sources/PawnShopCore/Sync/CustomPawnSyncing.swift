import Foundation

/// The custom pawns' side of syncing, without CloudKit (R10.2): which pawns' settings to send, and how a record
/// from another device is merged in. `CustomPawnSync` hands records between this and the toolkit's engine.
/// Settings are kept whether or not their creature is here yet: the two arrive apart.
extension PawnLibrary {
    /// The iCloud account the ledger describes.
    var customPawnAccount: String? { ledger.account }

    func setCustomPawnAccount(_ account: String?) throws {
        ledger.account = account
        try saveLedger()
    }

    /// The pawns whose settings the server lacks or holds differently, and the records whose settings are gone.
    /// Settings whose record this version can't read aren't sent over it.
    func customPawnCandidates() -> CustomPawnCandidates {
        var candidates = CustomPawnCandidates()
        for key in own.pawnSettings.keys.sorted() {
            let noted = ledger.records[key]
            guard let id = UUID(uuidString: key), noted?.isUnreadable != true else { continue }
            if noted?.systemFields == nil || noted?.digest != digest(ofSettings: id) { candidates.saves.append(id) }
        }
        candidates.deletions = ledger.records
            .filter { $0.value.systemFields != nil && own.pawnSettings[$0.key] == nil }
            .keys.sorted().compactMap { UUID(uuidString: $0) }
        return candidates
    }

    /// The record to save for a custom pawn's settings; nil when they are gone, when the server holds this
    /// content already, or while its record there is one this version can't read.
    func outgoingCustomPawn(_ id: UUID) -> OutgoingCustomPawn? {
        guard let payload = try? payload(ofSettings: id)?.encoded() else { return nil }
        let noted = ledger.records[id.uuidString]
        let digest = CustomPawnPayload.digest(of: payload)
        guard noted?.isUnreadable != true, noted?.systemFields == nil || noted?.digest != digest else { return nil }
        return OutgoingCustomPawn(id: id, payload: payload, digest: digest, title: creatures[id]?.name ?? "",
                                  systemFields: noted?.systemFields)
    }

    /// Notes that the server took a record, with the fields it answered with.
    func markSent(_ sent: OutgoingCustomPawn, systemFields: Data) throws {
        ledger.records[sent.id.uuidString] = .init(systemFields: systemFields, digest: sent.digest)
        try saveLedger()
    }

    /// Notes that the server no longer holds a pawn's record.
    func markDeleted(_ id: UUID) throws {
        ledger.records[id.uuidString] = nil
        try saveLedger()
    }

    /// Forgets the server's copy of a record it turned out not to hold, so the record is sent as new.
    func forgetSystemFields(of id: UUID) throws {
        ledger.records[id.uuidString]?.systemFields = nil
        try saveLedger()
    }

    /// Forgets what the server held: every custom pawn is then sent again, and merged with what is there.
    func forgetCustomPawnServer() throws {
        ledger.records = [:]
        try saveLedger()
    }

    /// Merges in what other devices did, deletions first. True when the custom pawns' settings changed.
    @discardableResult
    func applyRemote(_ changes: [CustomPawnChange]) throws -> Bool {
        var changed = false
        for change in changes {
            guard case .deleted(let id) = change else { continue }
            changed = removeRemotely(id) || changed
        }
        for change in changes {
            guard case .saved(let remote) = change else { continue }
            changed = merge(remote) || changed
        }
        if changed { try saveOwn() }
        try saveLedger()
        return changed
    }

    // MARK: Helpers

    /// Merges a saved record in. The settings here stay when they have changes still to send that are later
    /// than the record's; they are then sent over the record. True when the settings changed.
    private func merge(_ remote: RemoteCustomPawn) -> Bool {
        let key = remote.id.uuidString
        let noted = ledger.records[key]
        guard let incoming = CustomPawnPayload(data: remote.payload), incoming.id == remote.id,
              let digest = try? CustomPawnPayload.digest(of: incoming.encoded()) else {
            ledger.records[key] = .init(systemFields: remote.systemFields, digest: noted?.digest ?? "",
                                        isUnreadable: true)
            return false
        }
        let known = CustomPawnLedger.Entry(systemFields: remote.systemFields, digest: digest)
        let localDigest = self.digest(ofSettings: remote.id)
        // Known content. With the settings gone the pawn was removed here since, and its deletion is still to send.
        if noted?.digest == digest || localDigest == digest {
            ledger.records[key] = known
            return false
        }
        if localDigest != nil, localDigest != noted?.digest, modified(remote.id) > incoming.modified {
            ledger.records[key] = known
            return false
        }
        own.pawnSettings[key] = incoming.settings
        own.customPawnsModified[key] = incoming.modified
        ledger.records[key] = known
        return true
    }

    /// Removes the settings of a pawn another device removed, unless they have changes still to send: they then
    /// stay, and are sent as new. The creature itself goes with the creature library's own sync. True when the
    /// settings were removed.
    private func removeRemotely(_ id: UUID) -> Bool {
        let key = id.uuidString
        let noted = ledger.records.removeValue(forKey: key)
        guard let local = digest(ofSettings: id), local == noted?.digest else { return false }
        own.pawnSettings[key] = nil
        own.customPawnsModified[key] = nil
        return true
    }

    /// The payload of the settings kept for a custom pawn; nil without any.
    private func payload(ofSettings id: UUID) -> CustomPawnPayload? {
        own.pawnSettings[id.uuidString].map { CustomPawnPayload(id: id, settings: $0, modified: modified(id)) }
    }

    private func digest(ofSettings id: UUID) -> String? {
        (try? payload(ofSettings: id)?.encoded()).map(CustomPawnPayload.digest(of:))
    }

    private func modified(_ id: UUID) -> Double {
        own.customPawnsModified[id.uuidString] ?? 0
    }

    private func saveLedger() throws {
        try ledger.save(to: folder)
    }
}
