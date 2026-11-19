import Foundation

/// The custom pawns' side of syncing, without CloudKit (R10.2): what to send, and how a record from another device
/// is merged in. `CustomPawnSync` hands records between this and the toolkit's engine.
extension PawnLibrary {
    /// The iCloud account the ledger describes.
    var customPawnAccount: String? { ledger.account }

    func setCustomPawnAccount(_ account: String?) throws {
        ledger.account = account
        try saveLedger()
    }

    /// The pawns whose records the server lacks or holds differently, and the records whose pawns are gone. A
    /// pawn whose record this version can't read isn't sent over it.
    func customPawnCandidates() -> CustomPawnCandidates {
        var candidates = CustomPawnCandidates()
        for pawn in own.customPawns {
            let noted = ledger.records[pawn.id.uuidString]
            guard noted?.isUnreadable != true else { continue }
            if noted?.systemFields == nil || noted?.digest != digest(of: pawn) { candidates.saves.append(pawn.id) }
        }
        let here = Set(own.customPawns.map(\.id.uuidString))
        candidates.deletions = ledger.records.filter { $0.value.systemFields != nil && !here.contains($0.key) }
            .keys.sorted().compactMap { UUID(uuidString: $0) }
        return candidates
    }

    /// The record to save for a custom pawn; nil when the pawn is gone, when the server holds this content
    /// already, or while its record there is one this version can't read.
    func outgoingCustomPawn(_ id: UUID) -> OutgoingCustomPawn? {
        guard let pawn = own.customPawns.first(where: { $0.id == id }), case .custom(let art) = pawn.art,
              let payload = try? payload(of: pawn)?.encoded() else { return nil }
        let noted = ledger.records[id.uuidString]
        let digest = CustomPawnPayload.digest(of: payload)
        guard noted?.isUnreadable != true, noted?.systemFields == nil || noted?.digest != digest else { return nil }
        return OutgoingCustomPawn(id: id, payload: payload, digest: digest, title: pawn.name,
                                  image: customFolder.appendingPathComponent(art.imageFile),
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

    /// Merges in what other devices did, deletions first. True when the custom pawns changed. A record that
    /// can't be merged in (its image can't be saved) doesn't cost the others: its failure is thrown at the end.
    @discardableResult
    func applyRemote(_ changes: [CustomPawnChange]) throws -> Bool {
        var changed = false
        var failure: Error?
        for change in changes {
            guard case .deleted(let id) = change else { continue }
            changed = removeRemotely(id) || changed
        }
        for change in changes {
            guard case .saved(let remote) = change else { continue }
            do {
                changed = try merge(remote) || changed
            } catch let error {
                failure = failure ?? error
            }
        }
        if changed { try saveOwn() }
        try saveLedger()
        if let failure { throw failure }
        return changed
    }

    // MARK: Helpers

    /// Merges a saved record in. The pawn here stays when it has changes still to send that are later than the
    /// record's; it is then sent over the record. True when the pawn changed.
    private func merge(_ remote: RemoteCustomPawn) throws -> Bool {
        let key = remote.id.uuidString
        let noted = ledger.records[key]
        guard let incoming = CustomPawnPayload(data: remote.payload), incoming.id == remote.id,
              let digest = try? CustomPawnPayload.digest(of: incoming.encoded()) else {
            ledger.records[key] = .init(systemFields: remote.systemFields, digest: noted?.digest ?? "",
                                        isUnreadable: true)
            return false
        }
        let known = CustomPawnLedger.Entry(systemFields: remote.systemFields, digest: digest)
        let local = own.customPawns.first { $0.id == remote.id }
        let localDigest = local.flatMap(digest(of:))
        // Known content. With the pawn gone it was removed here since, and its deletion is still to send.
        if noted?.digest == digest || localDigest == digest {
            ledger.records[key] = known
            return false
        }
        if local != nil, localDigest != noted?.digest, modified(remote.id) > incoming.modified {
            ledger.records[key] = known
            return false
        }
        guard try take(incoming, image: remote.image, inPlaceOf: local) else { return false }
        ledger.records[key] = known
        return true
    }

    /// Makes the pawn here what the record says. False when the device has no image to draw it with: the record
    /// came without one, as the server's copy of a refused save does, for a pawn that isn't here.
    private func take(_ incoming: CustomPawnPayload, image: URL?, inPlaceOf local: Pawn?) throws -> Bool {
        var file = "\(incoming.id.uuidString).png"
        if case .custom(let art)? = local?.art { file = art.imageFile }
        let destination = customFolder.appendingPathComponent(file)
        if let image {
            try copyImage(at: image, to: destination)
        } else if local == nil || !FileManager.default.fileExists(atPath: destination.path) {
            return false
        }
        let pawn = incoming.pawn(imageFile: file)
        if let index = own.customPawns.firstIndex(where: { $0.id == pawn.id }) {
            own.customPawns[index] = pawn
        } else {
            own.customPawns.append(pawn)
        }
        own.customPawnsModified[pawn.id.uuidString] = incoming.modified
        return true
    }

    /// Removes a pawn another device removed, unless it has changes still to send: it then stays, and is sent as
    /// new. True when the pawn was removed.
    private func removeRemotely(_ id: UUID) -> Bool {
        let key = id.uuidString
        let noted = ledger.records.removeValue(forKey: key)
        guard let pawn = own.customPawns.first(where: { $0.id == id }), digest(of: pawn) == noted?.digest
        else { return false }
        removeCustomPawns([id])
        return true
    }

    private func copyImage(at source: URL, to destination: URL) throws {
        do {
            let data = try Data(contentsOf: source)
            try data.write(to: destination, options: .atomic)
        } catch {
            throw PawnLibraryError.saveFailed("\(destination.lastPathComponent): \(error.localizedDescription)")
        }
    }

    private func payload(of pawn: Pawn) -> CustomPawnPayload? {
        CustomPawnPayload(pawn, modified: modified(pawn.id))
    }

    private func digest(of pawn: Pawn) -> String? {
        (try? payload(of: pawn)?.encoded()).map(CustomPawnPayload.digest(of:))
    }

    private func modified(_ id: UUID) -> Double {
        own.customPawnsModified[id.uuidString] ?? 0
    }

    private func saveLedger() throws {
        try ledger.save(to: folder)
    }
}
