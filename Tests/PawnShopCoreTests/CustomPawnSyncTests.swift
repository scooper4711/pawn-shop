import CloudKit
import Foundation
import SharedLibraries
import TablesideSync
import Testing
@testable import PawnShopCore

/// A device whose custom pawns sync: its library and the handler of its zone.
@MainActor
struct SyncingDevice {
    let device: SyncDevice
    let sync: CustomPawnSync

    init() throws {
        device = try SyncDevice()
        sync = CustomPawnSync(library: device.library)
    }

    var library: PawnLibrary { device.library }

    /// Hands over every record the handler has to save, as though the server took them all, and gives them as
    /// the server then holds them.
    @discardableResult
    func sendEverything() -> [CKRecord] {
        let records = sync.pendingChanges().compactMap { change -> CKRecord? in
            guard case .save(let recordID) = change else { return nil }
            return sync.record(for: recordID)
        }
        sync.sent(saved: records, deleted: [])
        return records
    }

    func fetch(_ records: [CKRecord]) {
        sync.received(FetchedChanges(modifications: records))
    }
}

extension SyncChange {
    /// The record a change saves or deletes.
    var changedRecord: CKRecord.ID {
        switch self {
        case .save(let recordID), .delete(let recordID): recordID
        }
    }
}

/// A `serverRecordChanged` refusal, with the record the server holds.
private func conflict(with server: CKRecord) -> CKError {
    CKError(.serverRecordChanged, userInfo: [CKRecordChangedErrorServerRecordKey: server])
}

/// The custom pawns' zone on the toolkit's engine (R10.2).
@MainActor
@Suite struct CustomPawnSyncTests {
    let mac: SyncingDevice
    let pad: SyncingDevice

    init() throws {
        mac = try SyncingDevice()
        pad = try SyncingDevice()
    }

    @Test func savesEachPawnAsARecordOfItsZoneWithItsImage() throws {
        let hero = try mac.device.addHero()
        #expect(mac.sync.zones().map(\.zoneName) == ["PawnShop"])
        let recordID = CKRecord.ID(recordName: "pawn-\(hero.id.uuidString)", zoneID: CustomPawnRecordCoder.zone)
        #expect(mac.sync.pendingChanges() == [.save(recordID)])

        let record = try #require(mac.sync.record(for: recordID))
        #expect(record.recordType == "CustomPawn" && record["format"] == Int64(1) && record["title"] == "Hero")
        #expect((record["image"] as? CKAsset)?.fileURL != nil && record["payload"] is Data)

        mac.sync.sent(saved: [record], deleted: [])
        #expect(mac.sync.pendingChanges().isEmpty && mac.sync.record(for: recordID) == nil)
        #expect(mac.sync.record(for: CKRecord.ID(recordName: "pawn-1", zoneID: CustomPawnRecordCoder.zone)) == nil)
        #expect(mac.sync.record(for: CKRecord.ID(recordName: recordID.recordName, zoneID: .default)) == nil)
    }

    @Test func savesAChangedPawnOverTheServersCopy() throws {
        let hero = try mac.device.addHero()
        let first = try #require(mac.sendEverything().first)
        try mac.library.rename(hero.id, to: "Heroine")
        let fields = CustomPawnRecordCoder.systemFields(of: first)
        #expect(mac.library.outgoingCustomPawn(hero.id)?.systemFields == fields)
        let second = try #require(mac.sync.record(for: first.recordID))
        #expect(second["title"] == "Heroine" && second.recordID == first.recordID)
        #expect(CustomPawnRecordCoder.record(withSystemFields: Data("not an archive".utf8)) == nil)
    }

    @Test func mergesWhatAnotherDeviceSentAndTellsTheApp() throws {
        let hero = try mac.device.addHero()
        var told = 0
        pad.sync.onChange = { told += 1 }
        pad.fetch(mac.sendEverything())
        #expect(pad.library.pawn(id: hero.id)?.name == "Hero" && told == 1)
        #expect(pad.sync.pendingChanges().isEmpty && pad.sync.problem == nil)

        try mac.library.remove([hero.id])
        let deletion = try #require(mac.sync.pendingChanges().first)
        #expect(deletion == .delete(CustomPawnRecordCoder.recordID(of: hero.id)))
        mac.sync.sent(saved: [], deleted: [deletion.changedRecord])
        #expect(mac.sync.pendingChanges().isEmpty)

        let other = CKRecord.ID(recordName: "note-1", zoneID: CustomPawnRecordCoder.zone)
        pad.sync.received(FetchedChanges(deletions: [
            .init(recordID: deletion.changedRecord, recordType: "CustomPawn"),
            .init(recordID: other, recordType: "Note")
        ]))
        #expect(pad.library.pawns.isEmpty && told == 2)
    }

    @Test func ignoresRecordsThatAreNotCustomPawns() throws {
        let record = CKRecord(recordType: "Note", recordID: CustomPawnRecordCoder.recordID(of: UUID()))
        pad.fetch([record])
        #expect(pad.library.pawns.isEmpty)
    }

    @Test func passesOverARecordInALaterLayout() throws {
        let hero = try mac.device.addHero()
        pad.fetch(mac.sendEverything())
        try mac.library.rename(hero.id, to: "Later")
        let later = try #require(mac.sendEverything().first)
        later["format"] = Int64(2)
        pad.fetch([later])
        #expect(pad.library.pawn(id: hero.id)?.name == "Hero")
        try pad.library.rename(hero.id, to: "Changed Here")
        #expect(pad.sync.pendingChanges().isEmpty, "the pawn isn't sent over a record this version can't read")
    }

    @Test func reportsRecordsItCouldNotMergeIn() throws {
        try mac.device.addHero()
        let record = try #require(mac.sendEverything().first)
        try FileManager.default.removeItem(at: pad.library.customFolder)
        var told = 0
        pad.sync.onChange = { told += 1 }
        pad.fetch([record])
        #expect(pad.sync.problem?.contains("Saving the pawn library failed") == true && told == 1)
    }

    @Test func settlesARefusedSaveByMergingTheServersRecord() throws {
        let hero = try mac.device.addHero()
        pad.fetch(mac.sendEverything())
        try mac.library.rename(hero.id, to: "Mac Hero")
        let server = try #require(mac.sendEverything().first)
        server["image"] = nil
        mac.device.setModified(200, of: hero)

        try pad.library.rename(hero.id, to: "Pad Hero")
        pad.device.setModified(100, of: hero)
        let refused = try #require(pad.sync.record(for: server.recordID))
        #expect(!pad.sync.settle([(record: refused, error: conflict(with: server))]))
        #expect(pad.library.pawn(id: hero.id)?.name == "Mac Hero" && pad.sync.pendingChanges().isEmpty)

        try pad.library.rename(hero.id, to: "Pad Hero Again")
        pad.device.setModified(300, of: hero)
        try pad.library.forgetSystemFields(of: hero.id)
        let again = try #require(pad.sync.record(for: server.recordID))
        #expect(!pad.sync.settle([(record: again, error: conflict(with: server))]))
        #expect(pad.library.pawn(id: hero.id)?.name == "Pad Hero Again")
        #expect(pad.library.outgoingCustomPawn(hero.id)?.systemFields == CustomPawnRecordCoder.systemFields(of: server),
                "the pawn here is sent over the server's record")
    }

    @Test func sendsARecordTheServerDoesNotKnowAsNew() throws {
        let hero = try mac.device.addHero()
        let record = try #require(mac.sendEverything().first)
        try mac.library.rename(hero.id, to: "Heroine")
        #expect(!mac.sync.settle([(record: record, error: CKError(.unknownItem))]))
        #expect(mac.library.outgoingCustomPawn(hero.id)?.systemFields == nil)
        #expect(!mac.sync.settle([(record: record, error: CKError(.networkFailure))]))
    }

    @Test func savesTheZoneAgainWhenTheServerLacksIt() throws {
        try mac.device.addHero()
        let record = try #require(mac.sendEverything().first)
        #expect(mac.sync.settle([(record: record, error: CKError(.zoneNotFound))]))
        #expect(mac.sync.pendingChanges() == [.save(record.recordID)])
    }

    @Test func holdsBackWhileICloudIsFull() throws {
        try mac.device.addHero()
        let recordID = try #require(mac.sync.pendingChanges().first).changedRecord
        let record = try #require(mac.sync.record(for: recordID))
        #expect(!mac.sync.settle([(record: record, error: CKError(.quotaExceeded))]))
        #expect(mac.sync.pendingChanges().isEmpty)
        mac.sync.customPawnsChanged()
        #expect(mac.sync.pendingChanges() == [.save(recordID)])

        _ = mac.sync.settle([(record: record, error: CKError(.quotaExceeded))])
        mac.sync.received(FetchedChanges())
        #expect(mac.sync.pendingChanges() == [.save(recordID)])
    }

    @Test func pausesWhenTheUserDeletedTheICloudData() throws {
        let hero = try mac.device.addHero()
        let record = try #require(mac.sendEverything().first)
        #expect(!mac.sync.zoneDeleted(CKRecordZone.ID(zoneName: "Library"), reason: .purged))
        #expect(try !mac.library.shared.isSyncPaused)

        #expect(!mac.sync.zoneDeleted(CustomPawnRecordCoder.zone, reason: .purged))
        #expect(try mac.library.shared.isSyncPaused)
        #expect(mac.sync.pendingChanges().isEmpty && mac.sync.record(for: record.recordID) == nil)

        try mac.library.shared.setSyncPaused(false)
        #expect(mac.sync.pendingChanges() == [.save(record.recordID)], "everything goes up again")
        #expect(!mac.sync.settle([(record: record, error: CKError(.userDeletedZone))]))
        #expect(try mac.library.shared.isSyncPaused && mac.library.pawn(id: hero.id) != nil)
    }

    @Test func uploadsAgainAfterItsZoneWasDeletedAnyOtherWay() throws {
        try mac.device.addHero()
        let record = try #require(mac.sendEverything().first)
        #expect(mac.sync.zoneDeleted(CustomPawnRecordCoder.zone, reason: .deleted))
        #expect(mac.sync.pendingChanges() == [.save(record.recordID)])
        #expect(try !mac.library.shared.isSyncPaused)
    }

    @Test func forgetsTheServerWhenAnotherAccountSignsIn() throws {
        try mac.device.addHero()
        mac.sync.accountChanged(to: "user 1")
        let record = try #require(mac.sendEverything().first)
        mac.sync.accountChanged(to: "user 1")
        mac.sync.accountChanged(to: nil)
        #expect(mac.sync.pendingChanges().isEmpty && mac.library.customPawnAccount == "user 1")

        mac.sync.accountChanged(to: "user 2")
        #expect(mac.sync.pendingChanges() == [.save(record.recordID)] && mac.library.customPawnAccount == "user 2")
    }

    @Test func closesTheSharedLibraryAfterEachCallInTheBackground() throws {
        try mac.device.addHero()
        mac.sync.closesLibraryAfterUse = true
        #expect(mac.sync.pendingChanges().count == 1)
        mac.sendEverything()
        mac.sync.received(FetchedChanges())
        #expect(mac.sync.pendingChanges().isEmpty && mac.library.pawns.count == 1)
    }
}
