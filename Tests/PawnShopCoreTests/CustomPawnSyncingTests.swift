import CoreGraphics
import Foundation
import Testing
import ArtExtractionTestSupport
@testable import PawnShopCore

/// A device's worth of Pawn Shop for the sync tests: a library in a folder of its own.
struct SyncDevice {
    let library: PawnLibrary

    init() throws {
        library = try PawnLibrary(folder: temporaryFolder())
    }

    @discardableResult
    func addHero(named name: String = "Hero") throws -> Pawn {
        try library.addCustomPawn(NewCustomPawn(image: headRedImage(), name: name))
    }

    /// Sets when the user last changed a pawn, as though the change were made then.
    func setModified(_ seconds: Double, of pawn: Pawn) {
        library.own.customPawnsModified[pawn.id.uuidString] = seconds
    }

    /// Sends a pawn's record, as though the server took it, and gives it as another device then fetches it.
    func send(_ pawn: Pawn, fields: String = "fields 1") throws -> RemoteCustomPawn {
        let outgoing = try #require(library.outgoingCustomPawn(pawn.id))
        try library.markSent(outgoing, systemFields: Data(fields.utf8))
        return RemoteCustomPawn(id: outgoing.id, payload: outgoing.payload, image: outgoing.image,
                                systemFields: Data(fields.utf8))
    }

    func imageExists(of pawn: Pawn) -> Bool {
        guard case .custom(let art) = pawn.art else { return false }
        return FileManager.default.fileExists(atPath: library.customFolder.appendingPathComponent(art.imageFile).path)
    }
}

/// What custom pawns have to send, and how another device's records are merged in (R10.2).
@Suite struct CustomPawnSyncingTests {
    let mac: SyncDevice
    let pad: SyncDevice

    init() throws {
        mac = try SyncDevice()
        pad = try SyncDevice()
    }

    @Test func sendsANewPawnOnceAndAgainWhenItChanges() throws {
        let hero = try mac.addHero()
        #expect(mac.library.customPawnCandidates() == CustomPawnCandidates(saves: [hero.id]))
        let outgoing = try #require(mac.library.outgoingCustomPawn(hero.id))
        #expect(outgoing.title == "Hero" && outgoing.systemFields == nil)
        #expect(FileManager.default.fileExists(atPath: outgoing.image.path))

        try mac.library.markSent(outgoing, systemFields: Data("fields 1".utf8))
        #expect(mac.library.customPawnCandidates().isEmpty && mac.library.outgoingCustomPawn(hero.id) == nil)

        try mac.library.rename(hero.id, to: "Heroine")
        #expect(mac.library.customPawnCandidates().saves == [hero.id])
        #expect(mac.library.outgoingCustomPawn(hero.id)?.systemFields == Data("fields 1".utf8))
        #expect(mac.library.outgoingCustomPawn(UUID()) == nil)
    }

    @Test func keepsWhatTheServerHoldsBetweenLaunches() throws {
        let hero = try mac.addHero()
        _ = try mac.send(hero)
        try mac.library.setCustomPawnAccount("user 1")
        let reopened = try PawnLibrary(folder: mac.library.folder)
        #expect(reopened.customPawnCandidates().isEmpty && reopened.customPawnAccount == "user 1")
    }

    @Test func aChangeMadeWhileARecordIsOnItsWayIsStillSent() throws {
        let hero = try mac.addHero()
        let outgoing = try #require(mac.library.outgoingCustomPawn(hero.id))
        try mac.library.correctTags(["sword"], of: hero.id)
        try mac.library.markSent(outgoing, systemFields: Data("fields 1".utf8))
        #expect(mac.library.customPawnCandidates().saves == [hero.id])
    }

    @Test func sendsTheDeletionOfAPawnTheServerHolds() throws {
        let hero = try mac.addHero(), unsent = try mac.addHero(named: "Unsent")
        _ = try mac.send(hero)
        try mac.library.remove([hero.id, unsent.id])
        #expect(mac.library.customPawnCandidates() == CustomPawnCandidates(deletions: [hero.id]))
        try mac.library.markDeleted(hero.id)
        #expect(mac.library.customPawnCandidates().isEmpty)
    }

    @Test func sendsEverythingAgainOnceTheServerIsForgotten() throws {
        let hero = try mac.addHero()
        _ = try mac.send(hero)
        try mac.library.forgetSystemFields(of: hero.id)
        #expect(mac.library.customPawnCandidates().saves == [hero.id])
        #expect(mac.library.outgoingCustomPawn(hero.id)?.systemFields == nil)

        _ = try mac.send(hero)
        try mac.library.forgetCustomPawnServer()
        #expect(mac.library.customPawnCandidates().saves == [hero.id])
    }

    @Test func addsAPawnAnotherDeviceMadeWithItsImage() throws {
        var hero = try mac.addHero()
        try mac.library.correctTags(["Sword"], of: hero.id)
        hero = try #require(mac.library.pawn(id: hero.id))
        #expect(try pad.library.applyRemote([.saved(try mac.send(hero))]))

        let arrived = try #require(pad.library.pawn(id: hero.id))
        #expect(arrived.name == "Hero" && arrived.tags == ["sword"] && arrived.tagsCorrected && arrived.isCustom)
        #expect(pad.imageExists(of: arrived))
        #expect(pad.library.customPawnCandidates().isEmpty, "what arrived isn't sent back")
        #expect(try PawnLibrary(folder: pad.library.folder).pawn(id: hero.id) == arrived)
    }

    @Test func aRecordItKnowsChangesNothing() throws {
        let hero = try mac.addHero()
        let record = try mac.send(hero)
        try pad.library.applyRemote([.saved(record)])
        #expect(try !pad.library.applyRemote([.saved(record)]))
        #expect(try !mac.library.applyRemote([.saved(record)]), "its own record, fetched back")
        #expect(mac.library.customPawnCandidates().isEmpty && pad.library.customPawnCandidates().isEmpty)
    }

    @Test func aRecordForAPawnRemovedHereDoesNotBringItBack() throws {
        let hero = try mac.addHero()
        let record = try mac.send(hero)
        try mac.library.remove([hero.id])
        #expect(try !mac.library.applyRemote([.saved(record)]))
        #expect(mac.library.pawn(id: hero.id) == nil)
        #expect(mac.library.customPawnCandidates().deletions == [hero.id])
    }

    @Test func theLaterOfTwoChangesWins() throws {
        let hero = try mac.addHero()
        try pad.library.applyRemote([.saved(try mac.send(hero))])
        try mac.library.rename(hero.id, to: "Mac Hero")
        try pad.library.rename(hero.id, to: "Pad Hero")
        mac.setModified(200, of: hero)
        pad.setModified(100, of: hero)

        let fromMac = try mac.send(hero, fields: "fields 2")
        #expect(try pad.library.applyRemote([.saved(fromMac)]))
        #expect(pad.library.pawn(id: hero.id)?.name == "Mac Hero" && pad.library.customPawnCandidates().isEmpty)

        try pad.library.rename(hero.id, to: "Pad Hero Again")
        pad.setModified(300, of: hero)
        #expect(try !pad.library.applyRemote([.saved(fromMac)]), "known content")
        try mac.library.rename(hero.id, to: "Mac Hero Again")
        mac.setModified(250, of: hero)
        #expect(try !pad.library.applyRemote([.saved(try mac.send(hero, fields: "fields 3"))]))
        #expect(pad.library.pawn(id: hero.id)?.name == "Pad Hero Again")
        #expect(pad.library.outgoingCustomPawn(hero.id)?.systemFields == Data("fields 3".utf8),
                "the pawn here is sent over the record it beat")
    }

    @Test func removesAPawnAnotherDeviceRemovedUnlessItChangedHere() throws {
        let hero = try mac.addHero(), villain = try mac.addHero(named: "Villain")
        try pad.library.applyRemote([.saved(try mac.send(hero)), .saved(try mac.send(villain))])
        let arrived = try #require(pad.library.pawn(id: hero.id))
        try pad.library.rename(villain.id, to: "Changed Villain")

        #expect(try pad.library.applyRemote([.deleted(hero.id), .deleted(villain.id), .deleted(UUID())]))
        #expect(pad.library.pawn(id: hero.id) == nil && !pad.imageExists(of: arrived))
        #expect(pad.library.pawn(id: villain.id)?.name == "Changed Villain")
        #expect(pad.library.customPawnCandidates() == CustomPawnCandidates(saves: [villain.id]))
        #expect(pad.library.outgoingCustomPawn(villain.id)?.systemFields == nil, "sent as new")
    }

    @Test func leavesOutARecordWithoutAnImageForAPawnThatIsNotHere() throws {
        let hero = try mac.addHero()
        var record = try mac.send(hero)
        record.image = nil
        #expect(try !pad.library.applyRemote([.saved(record)]))
        #expect(pad.library.pawn(id: hero.id) == nil && pad.library.customPawnCandidates().isEmpty)
    }

    @Test func takesARecordWithoutItsImageForAPawnThatIsHere() throws {
        let hero = try mac.addHero()
        try pad.library.applyRemote([.saved(try mac.send(hero))])
        try mac.library.rename(hero.id, to: "Renamed")
        var record = try mac.send(hero, fields: "fields 2")
        record.image = nil
        #expect(try pad.library.applyRemote([.saved(record)]))
        let renamed = try #require(pad.library.pawn(id: hero.id))
        #expect(renamed.name == "Renamed" && pad.imageExists(of: renamed))
    }

    @Test func doesNotSendOverARecordItCannotRead() throws {
        let hero = try mac.addHero()
        try pad.library.applyRemote([.saved(try mac.send(hero))])
        let later = RemoteCustomPawn(id: hero.id, payload: Data(#"{"size":"colossal"}"#.utf8), image: nil,
                                     systemFields: Data("fields 2".utf8))
        #expect(try !pad.library.applyRemote([.saved(later)]))
        try pad.library.rename(hero.id, to: "Renamed Here")
        #expect(pad.library.customPawnCandidates().isEmpty && pad.library.outgoingCustomPawn(hero.id) == nil)

        try mac.library.rename(hero.id, to: "Readable Again")
        mac.setModified(.greatestFiniteMagnitude, of: hero)
        #expect(try pad.library.applyRemote([.saved(try mac.send(hero, fields: "fields 3"))]))
        #expect(pad.library.pawn(id: hero.id)?.name == "Readable Again")
    }

    @Test func mergesTheRestWhenAnImageCannotBeSaved() throws {
        let hero = try mac.addHero(), villain = try mac.addHero(named: "Villain")
        var broken = try mac.send(hero)
        broken.image = temporaryFolder().appendingPathComponent("missing.png")
        #expect(throws: PawnLibraryError.self) {
            try pad.library.applyRemote([.saved(broken), .saved(try mac.send(villain))])
        }
        #expect(pad.library.pawn(id: hero.id) == nil && pad.library.pawn(id: villain.id)?.name == "Villain")
        #expect(try PawnLibrary(folder: pad.library.folder).pawn(id: villain.id) != nil)
    }

    @Test func readsALibraryFileSavedBeforeChangesWereTimed() throws {
        let json = #"{"version":1,"customPawns":[],"hidden":[],"importedFiles":{},"readAgain":{"a":"b"}}"#
        let own = try JSONDecoder().decode(OwnLibrary.self, from: Data(json.utf8))
        #expect(own.customPawnsModified.isEmpty && own.readAgain == ["a": "b"])
        #expect(try JSONDecoder().decode(OwnLibrary.self, from: Data("{}".utf8)) == OwnLibrary())
    }

    @Test func aLedgerThatCannotBeReadCountsAsEmpty() throws {
        let hero = try mac.addHero()
        _ = try mac.send(hero)
        try Data("not json".utf8).write(to: mac.library.folder.appendingPathComponent(CustomPawnLedger.fileName))
        #expect(try PawnLibrary(folder: mac.library.folder).customPawnCandidates().saves == [hero.id])
    }

    @Test func timesTheChangesTaggingMakes() throws {
        let hero = try mac.addHero()
        _ = try mac.send(hero)
        let before = mac.library.customPawnChanges
        mac.library.setTags(["staff"], by: "model 1", of: hero.id)
        try mac.library.save()
        #expect(mac.library.customPawnChanges > before)
        #expect(mac.library.customPawnCandidates().saves == [hero.id])
        try mac.library.remove([hero.id])
        #expect(mac.library.own.customPawnsModified.isEmpty)
    }
}
