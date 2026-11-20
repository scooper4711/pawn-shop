import CloudKit
import Foundation
import SharedLibraries
import TablesideSync

/// Syncs what is Pawn Shop's own about custom pawns, their placement and tags, through the zone `PawnShop` of the
/// suite's container (R10.2): one of the owners of zones on the toolkit's engine, beside the shared library's
/// own, which syncs their creatures and images. The library decides what to send and how a record from
/// another device is merged in (`CustomPawnSyncing.swift`); this hands records between it and the engine. It
/// lives on the main actor, as the library does.
@MainActor
public final class CustomPawnSync: SyncZoneHandler {
    private let library: PawnLibrary
    /// The records handed to the engine, until the server takes them.
    private var outgoing: [UUID: OutgoingCustomPawn] = [:]
    /// True from a save iCloud had no room for until a fetch or a change here gives a reason to try again.
    private var isStorageFull = false
    /// True while the app is in the background on the iPad: the shared library is then closed after each call,
    /// as a suspended app holding its file open is ended (shared libraries R5.4).
    public var closesLibraryAfterUse = false
    /// Called when records from another device changed the custom pawns.
    public var onChange: (@MainActor () -> Void)?
    /// Why records from another device couldn't all be merged in, the last time; nil when they could.
    public private(set) var problem: String?

    public init(library: PawnLibrary) {
        self.library = library
    }

    /// Tells syncing the user changed a custom pawn: a full iCloud is tried again.
    public func customPawnsChanged() {
        isStorageFull = false
    }

    public func zones() -> [CKRecordZone.ID] {
        [CustomPawnRecordCoder.zone]
    }

    /// The records to save and to delete; none while syncing is paused or iCloud is full.
    public func pendingChanges() -> [SyncChange] {
        defer { finish() }
        guard !isStorageFull, !isPaused else { return [] }
        let candidates = library.customPawnCandidates()
        return candidates.saves.map { .save(CustomPawnRecordCoder.recordID(of: $0)) }
            + candidates.deletions.map { .delete(CustomPawnRecordCoder.recordID(of: $0)) }
    }

    /// The record to save, remembered until the server takes it; nil when its pawn is gone, when the server holds
    /// this content already, or while syncing is paused.
    public func record(for recordID: CKRecord.ID) -> CKRecord? {
        defer { finish() }
        guard !isPaused, let id = CustomPawnRecordCoder.pawnID(of: recordID),
              let record = library.outgoingCustomPawn(id) else { return nil }
        outgoing[id] = record
        return CustomPawnRecordCoder.record(for: record)
    }

    public func received(_ changes: FetchedChanges) {
        defer { finish() }
        isStorageFull = false
        let deleted = changes.deletions.compactMap { CustomPawnRecordCoder.pawnID(of: $0.recordID) }
        apply(deleted.map(CustomPawnChange.deleted)
            + changes.modifications.compactMap(CustomPawnRecordCoder.change(from:)))
    }

    public func sent(saved: [CKRecord], deleted: [CKRecord.ID]) {
        for record in saved {
            guard let id = CustomPawnRecordCoder.pawnID(of: record.recordID),
                  let sent = outgoing.removeValue(forKey: id) else { continue }
            try? library.markSent(sent, systemFields: CustomPawnRecordCoder.systemFields(of: record))
        }
        for id in deleted.compactMap(CustomPawnRecordCoder.pawnID(of:)) {
            try? library.markDeleted(id)
        }
    }

    /// Settles refused saves. A record the server holds in another version is merged in as a fetched one is.
    /// A zone the server lacks holds none of the records, so
    /// the server is forgotten and everything goes up with the zone. Anything not named here the engine retries.
    public func settle(_ failures: [FailedSave]) -> Bool {
        defer { finish() }
        var savesZone = false
        var conflicts: [CustomPawnChange] = []
        for failure in failures {
            switch failure.error.code {
            case .serverRecordChanged:
                if let server = failure.error.serverRecord.flatMap(CustomPawnRecordCoder.change(from:)) {
                    conflicts.append(server)
                }
            case .unknownItem:
                let id = CustomPawnRecordCoder.pawnID(of: failure.record.recordID)
                id.map { try? library.forgetSystemFields(of: $0) }
            case .zoneNotFound:
                savesZone = true
            case .userDeletedZone:
                pause()
            case .quotaExceeded:
                isStorageFull = true
            default:
                break
            }
        }
        if savesZone { forgetServer() }
        if !conflicts.isEmpty { apply(conflicts) }
        return savesZone
    }

    /// Forgets the server when the account isn't the one the ledger describes: everything then goes up to the new
    /// one (library sync R5.1). The engine tells the account at every start, so a known one changes nothing.
    public func accountChanged(to user: String?) {
        guard let user, library.customPawnAccount != user else { return }
        forgetServer()
        try? library.setCustomPawnAccount(user)
    }

    /// iCloud data the user deleted pauses syncing (R10.7); a zone deleted any other way is uploaded again.
    public func zoneDeleted(_ zoneID: CKRecordZone.ID, reason: CKDatabase.DatabaseChange.Deletion.Reason) -> Bool {
        defer { finish() }
        guard zoneID == CustomPawnRecordCoder.zone else { return false }
        if reason == .purged {
            pause()
            return false
        }
        forgetServer()
        return true
    }

    // MARK: Helpers

    /// The shared library's pause covers this zone too: deleting the app's iCloud data purges every zone of the
    /// container, and `LibrarySync.resume()` turns both back on. A pause that can't be read counts as one.
    private var isPaused: Bool {
        (try? library.shared.isSyncPaused) != false
    }

    private func pause() {
        try? library.shared.setSyncPaused(true)
        forgetServer()
    }

    private func forgetServer() {
        try? library.forgetCustomPawnServer()
        outgoing = [:]
        isStorageFull = false
    }

    private func apply(_ changes: [CustomPawnChange]) {
        do {
            let changed = try library.applyRemote(changes)
            problem = nil
            if changed { onChange?() }
        } catch {
            problem = "\(error)"
            onChange?()
        }
    }

    private func finish() {
        if closesLibraryAfterUse { library.close() }
    }
}
